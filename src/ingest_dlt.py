import argparse
import hashlib
import time
from pathlib import Path
from datetime import datetime

import dlt
import duckdb
import requests
import pyarrow.parquet as pq
import csv

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
DB_PATH = DATA_DIR / "nyc_taxi.duckdb"
TLC_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"

def descargar_con_reintentos(url: str, destino: Path, max_retries=3):
    destino.parent.mkdir(parents=True, exist_ok=True)
    for intento in range(1, max_retries + 1):
        try:
            print(f"Descargando {url}... (intento {intento})")
            with requests.get(url, stream=True, timeout=60) as r:
                r.raise_for_status()
                with destino.open("wb") as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        f.write(chunk)
            return True
        except Exception as e:
            if intento == max_retries:
                raise e
            time.sleep(2 ** (intento - 1))

def calcular_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

@dlt.resource(name="yellow_trips", write_disposition="append")
def procesar_mes(mes: str):
    year, month = mes.split("-")
    url = f"{TLC_URL}/yellow_tripdata_{year}-{month}.parquet"
    destino = RAW_DIR / "yellow" / f"year={year}" / f"month={month}" / f"yellow_tripdata_{year}-{month}.parquet"
    
    # 1. Abrimos conexión SOLO para el control de idempotencia y log
    con = duckdb.connect(str(DB_PATH))
    con.execute("""
        CREATE TABLE IF NOT EXISTS ingestion_log (
            archivo VARCHAR PRIMARY KEY, url VARCHAR, filas BIGINT, "bytes" BIGINT,
            hash_sha256 VARCHAR, fecha_hora TIMESTAMP, estado VARCHAR, mensaje_error VARCHAR
        )
    """)
    
    try:
        res = con.execute("SELECT hash_sha256 FROM ingestion_log WHERE archivo = ?", [str(destino)]).fetchone()
        if destino.exists() and res:
            hash_real = calcular_sha256(destino)
            if hash_real == res[0]:
                print(f"[idempotente] {destino.name} ya existe y su hash coincide. Saltando descarga y carga.")
                return  
                
        try:
            descargar_con_reintentos(url, destino)
        except Exception as e:
            con.execute("""
                INSERT OR REPLACE INTO ingestion_log (archivo, url, filas, "bytes", hash_sha256, fecha_hora, estado, mensaje_error)
                VALUES (?, ?, ?, ?, ?, now(), 'error', ?)
            """, [str(destino), url, None, None, "", str(e)])
            raise e

        hash_real = calcular_sha256(destino)
        filas = con.execute(f"SELECT COUNT(*) FROM read_parquet('{destino}')").fetchone()[0]
        con.execute("""
            INSERT OR REPLACE INTO ingestion_log (archivo, url, filas, "bytes", hash_sha256, fecha_hora, estado, mensaje_error)
            VALUES (?, ?, ?, ?, ?, now(), 'descargado', NULL)
        """, [str(destino), url, filas, destino.stat().st_size, hash_real])
        print(f"[descargado] {destino.name} descargado y registrado en ingestion_log ({filas:,} filas).")

    finally:
        # ⚠️ CRÍTICO: Cerramos la conexión ANTES de que dlt empiece a cargar
        con.close()
    
    # 2. Leemos el Parquet en lotes y se lo pasamos a dlt
    parquet_file = pq.ParquetFile(destino)

    lote = 0

    for batch in parquet_file.iter_batches(batch_size=50000):

        lote += 1
        print(f"[extract] procesando lote {lote}")

        rows = batch.to_pylist()

        for row in rows:
            for k, v in row.items():
                if isinstance(v, datetime):
                    row[k] = v.isoformat()

        yield rows

@dlt.resource(name="taxi_zones", write_disposition="replace")
def procesar_zonas():

    archivo_zonas = RAW_DIR / "taxi_zone_lookup.csv"

    if not archivo_zonas.exists():

        print("[zonas] CSV no encontrado. Descargando...")

        descargar_con_reintentos(
            "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv",
            archivo_zonas
        )

    else:

        print("[zonas] CSV existente. Reutilizando archivo.")

    with archivo_zonas.open("r", encoding="utf-8") as f:
        yield from csv.DictReader(f)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mes", required=True)
    args = parser.parse_args()

    year, month = args.mes.split("-")

    year_int = int(year)

    if year_int <= 2009:
        raise ValueError(
            "Para comparar contra el año anterior el año debe ser 2010 o superior."
        )

    mes_comparacion = f"{year_int - 1}-{month}"

    pipeline = dlt.pipeline(
        pipeline_name="nyc_taxi_ingest",
        destination=dlt.destinations.duckdb(credentials=str(DB_PATH)),
        dataset_name="raw",
    )

    print(f"Iniciando pipeline para el mes {args.mes}...")

    try:
        
        print("Cargando tabla de zonas...")
        pipeline.run(procesar_zonas())

        print(f"Cargando mes comparativo: {mes_comparacion}")
        pipeline.run(procesar_mes(mes_comparacion))

        print(f"Cargando mes solicitado: {args.mes}")
        load_info = pipeline.run(procesar_mes(args.mes))

        con = duckdb.connect(str(DB_PATH))

        con.execute("""
            UPDATE ingestion_log
            SET estado = 'cargado'
            WHERE archivo LIKE ?
            OR archivo LIKE ?
        """, [
            f"%{mes_comparacion}.parquet",
            f"%{args.mes}.parquet"
        ])

        con.close()

        print(load_info)

    except Exception as e:

        con = duckdb.connect(str(DB_PATH))

        con.execute("""
            UPDATE ingestion_log
            SET estado = 'error_carga',
                mensaje_error = ?
            WHERE archivo LIKE ?
            OR archivo LIKE ?
        """, [
            str(e),
            f"%{mes_comparacion}.parquet",
            f"%{args.mes}.parquet"
        ])

        con.close()

        raise

if __name__ == "__main__":
    main()