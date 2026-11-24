from dagster import asset
import os
import subprocess


def get_mes() -> str:
    return os.getenv("MES", "2025-03")


@asset(
    description="Ingesta de datos TLC mediante DLT."
)
def ingesta_dlt():

    mes = get_mes()

    subprocess.run(
        [
            "docker",
            "compose",
            "run",
            "--rm",
            "-e",
            f"MES={mes}",
            "pipeline",
            "python",
            "-m",
            "src.ingest_dlt",
            "--mes",
            mes,
        ],
        check=True,
    )


@asset(
    deps=[ingesta_dlt],
    description="Validación del contrato de esquema."
)
def schema_contract():

    mes = get_mes()

    subprocess.run(
        [
            "docker",
            "compose",
            "run",
            "--rm",
            "-e",
            f"MES={mes}",
            "pipeline",
            "python",
            "-m",
            "src.esquema",
            mes,
        ],
        check=True,
    )


@asset(
    deps=[schema_contract],
    description="Calidad de datos, curado, cuarentena y reconciliación mediante dbt."
)
def dbt_quality():

    mes = get_mes()

    subprocess.run(
        [
            "docker",
            "compose",
            "run",
            "--rm",
            "-e",
            f"MES={mes}",
            "pipeline",
            "bash",
            "-c",
            f"""
            mkdir -p data/curated &&
            mkdir -p data/quarantine &&
            mkdir -p data/dq &&

            dbt run \
                --project-dir dbt \
                --profiles-dir dbt \
                --threads 1 \
                --vars '{{"mes":"{mes}"}}'
            """
        ],
        check=True,
    )