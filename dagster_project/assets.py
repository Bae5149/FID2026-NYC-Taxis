from pathlib import Path
import os
import subprocess
import time
import requests
from dagster import asset, AssetExecutionContext


def get_mes() -> str:
    return os.getenv("MES", "2025-03")


@asset(
    description="Ingesta de datos TLC mediante DLT."
)
def ingesta_dlt():

    subprocess.run(["docker", "compose", "stop", "shaper"], check=False)

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
    description="Validación de contrato y esquema."
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
    description="Calidad de datos, cuarentena, reconciliación y capa curada."
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
            --select +curated_yellow_trips +quarantine_yellow_trips +dq_reconciliation \
            --vars '{{"mes":"{mes}"}}'
            """
        ],
        check=True,
    )


@asset(
    deps=[dbt_quality],
    description="Generación de la capa enriquecida particionada estilo Hive."
)
def curate_partitioned():

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
            "src.curate_partitioned",
            "--mes",
            mes,
        ],
        check=True,
    )


@asset(
    deps=[curate_partitioned],
    description="Construcción del modelo analítico."
)
def dbt_marts():

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
            "dbt",
            "run",
            "--project-dir",
            "dbt",
            "--profiles-dir",
            "dbt",
            "--select",
            "marts",
            "--vars",
            f'{{"mes":"{mes}"}}'
        ],
        check=True,
    )


@asset(
    deps=[dbt_marts],
    description="Levanta Shaper y sincroniza los dashboards SQL vía API."
)
def shaper_dashboard(context: AssetExecutionContext):
    mes = get_mes()
    env = os.environ.copy()
    env["MES"] = mes

    subprocess.run(
        [
            "docker",
            "compose",
            "up",
            "-d",
            "--force-recreate",
            "shaper",
        ],
        env=env,
        check=True,
    )

    shaper_url = os.getenv("SHAPER_URL", "http://127.0.0.1:5454")
    dashboards_dir = Path("dashboards")

    # Esperar hasta que el puerto/servidor HTTP de Shaper responda (no solo 200 en GET /api/dashboards)
    last_error = None
    for _ in range(60):
        try:
            r = requests.get(f"{shaper_url}/", timeout=2)
            if r.status_code < 500:
                break
            last_error = f"HTTP {r.status_code}: {r.text[:200]}"
        except requests.RequestException as exc:
            last_error = str(exc)
        time.sleep(0.5)
    else:
        raise RuntimeError(
            f"Shaper no respondió en {shaper_url} tras reiniciar. Último error: {last_error}"
        )

    sql_files = sorted(dashboards_dir.glob("*.sql"))
    if not sql_files:
        raise FileNotFoundError(f"No hay archivos .sql en {dashboards_dir.resolve()}")

    for sql_file in sql_files:
        title = sql_file.stem.replace("_", " ").title()
        payload = {
            "name": title,
            "content": sql_file.read_text(encoding="utf-8").strip(),
        }

        resp = requests.post(
            f"{shaper_url}/api/dashboards",
            json=payload,
            timeout=10,
        )
        if resp.status_code >= 400:
            raise RuntimeError(
                f"Error al crear/enviar '{title}' ({resp.status_code}): {resp.text}"
            )

        context.log.info(
            f"Dashboard '{title}' enviado a Shaper ({resp.status_code}): {resp.text.strip()}"
        )