import argparse
import shutil
from pathlib import Path
import duckdb


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Escribe capa curada en Parquet particionado estilo Hive."
    )
    parser.add_argument("--mes", required=True, help="Mes en formato YYYY-MM, ej: 2025-06")
    parser.add_argument("--base-dir", default="/app", help="Directorio base del proyecto")
    args = parser.parse_args()

    base_dir = Path(args.base_dir)
    anio_actual, mes_str = args.mes.split("-")
    anio_act = int(anio_actual)
    mes_num = int(mes_str)
    anio_ant = anio_act - 1

    curated_base = base_dir / "data" / "curated" / "curated_yellow_trips.parquet"
    zones_csv = base_dir / "data" / "raw" / "taxi_zone_lookup.csv"
    hive_out_dir = base_dir / "data" / "curated_hive"
    db_path = base_dir / "data" / "dbt_analytics.duckdb"

    hive_out_dir.mkdir(parents=True, exist_ok=True)

    # Borra solo las particiones correspondientes al mes reprocesado y su par interanual
    for y in (anio_ant, anio_act):
        part_dir = hive_out_dir / f"year={y}" / f"month={mes_num}"
        if part_dir.exists():
            shutil.rmtree(part_dir)

    mes_anterior_str = f"{anio_ant}-{mes_num:02d}"
    mes_actual_str = f"{anio_act}-{mes_num:02d}"

    con = duckdb.connect(str(db_path))
    con.execute("SET memory_limit = '3GB';")
    con.execute("SET threads = 1;")

    con.execute(
        f"""
        COPY (
            WITH zonas AS (
                SELECT
                    CAST(LocationID AS INTEGER) AS location_id,
                    CAST(Borough AS VARCHAR) AS borough,
                    CAST(Zone AS VARCHAR) AS zone,
                    CAST(service_zone AS VARCHAR) AS service_zone
                FROM read_csv_auto('{zones_csv}', header = true)
            ),
            trips_filtrados AS (
                SELECT *
                FROM read_parquet('{curated_base}')
                WHERE periodo_mes IN ('{mes_anterior_str}', '{mes_actual_str}')
            )
            SELECT
                t.*,
                CAST(date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) / 60.0 AS DOUBLE)
                    AS duracion_minutos,
                CASE
                    WHEN date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) > 0
                        THEN CAST(
                            t.trip_distance / (date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) / 3600.0)
                            AS DOUBLE
                        )
                    ELSE CAST(NULL AS DOUBLE)
                END AS velocidad_promedio_mph,
                CAST(t.tpep_pickup_datetime AS DATE) AS fecha_subida,
                CAST(extract(hour FROM t.tpep_pickup_datetime) AS INTEGER) AS hora_subida,
                CAST(extract(isodow FROM t.tpep_pickup_datetime) AS INTEGER) AS dia_semana_num,
                CASE extract(isodow FROM t.tpep_pickup_datetime)
                    WHEN 1 THEN 'Lunes'
                    WHEN 2 THEN 'Martes'
                    WHEN 3 THEN 'Miercoles'
                    WHEN 4 THEN 'Jueves'
                    WHEN 5 THEN 'Viernes'
                    WHEN 6 THEN 'Sabado'
                    WHEN 7 THEN 'Domingo'
                END AS dia_semana_nombre,
                CASE
                    WHEN t.fare_amount IS NOT NULL AND t.fare_amount > 0
                        THEN CAST((t.tip_amount / t.fare_amount) * 100.0 AS DOUBLE)
                    ELSE CAST(NULL AS DOUBLE)
                END AS porcentaje_propina_tarifa,
                CAST(extract(year FROM t.tpep_pickup_datetime) AS INTEGER) AS year,
                CAST(extract(month FROM t.tpep_pickup_datetime) AS INTEGER) AS month,
                pu.borough AS pu_borough,
                pu.zone AS pu_zona,
                pu.service_zone AS pu_service_zone,
                do_z.borough AS do_borough,
                do_z.zone AS do_zona,
                do_z.service_zone AS do_service_zone
            FROM trips_filtrados t
            LEFT JOIN zonas pu
                ON t.pu_location_id = pu.location_id
            LEFT JOIN zonas do_z
                ON t.do_location_id = do_z.location_id
        )
        TO '{hive_out_dir}'
        (FORMAT PARQUET, PARTITION_BY (year, month), OVERWRITE_OR_IGNORE)
        """
    )
    con.close()


if __name__ == "__main__":
    main()