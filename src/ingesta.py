"""Ingesta idempotente de NYC TLC Yellow Taxi."""
import argparse
import hashlib
import sys
import time
from pathlib import Path

import requests

from .config import (
    BACKOFF_BASE_SECONDS, CHUNK_SIZE, MAX_RETRIES,
    RAW_DIR, TLC_BASE_URL, ZONES_URL,
)
from .db import (
    get_connection, hash_ya_registrado, init_ingestion_log, registrar_ingesta,
)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(CHUNK_SIZE), b""):
            h.update(chunk)
    return h.hexdigest()


def descargar_con_reintentos(url: str, destino: Path) -> None:
    tmp = destino.with_suffix(destino.suffix + ".tmp")
    last_exc = None
    for intento in range(1, MAX_RETRIES + 1):
        try:
            with requests.get(url, stream=True, timeout=60) as r:
                r.raise_for_status()
                with tmp.open("wb") as f:
                    for chunk in r.iter_content(chunk_size=CHUNK_SIZE):
                        if chunk:
                            f.write(chunk)
            tmp.replace(destino)
            return
        except Exception as exc:
            last_exc = exc
            espera = BACKOFF_BASE_SECONDS * (2 ** (intento - 1))
            print(f"[reintento {intento}/{MAX_RETRIES}] {exc} — esperando {espera}s",
                  file=sys.stderr)
            time.sleep(espera)
    raise RuntimeError(f"Descarga fallida tras {MAX_RETRIES} intentos: {last_exc}")


def ingestar_zonas(con) -> Path:
    destino = RAW_DIR / "taxi_zone_lookup.csv"
    destino.parent.mkdir(parents=True, exist_ok=True)
    h_esp = hash_ya_registrado(con, str(destino), ZONES_URL)
    if destino.exists() and h_esp and sha256_file(destino) == h_esp:
        print(f"[idempotente] {destino.name} ya descargado.")
        return destino
    descargar_con_reintentos(ZONES_URL, destino)
    h = sha256_file(destino)
    filas = sum(1 for _ in destino.open()) - 1
    registrar_ingesta(con, str(destino), ZONES_URL, filas,
                      destino.stat().st_size, h, "ok")
    print(f"[ok] {destino.name}: {filas:,} filas, {destino.stat().st_size:,} bytes")
    return destino


def ingestar_mes(mes: str, con) -> Path:
    year, month = mes.split("-")
    url = f"{TLC_BASE_URL}/yellow_tripdata_{year}-{month}.parquet"
    destino = (RAW_DIR / "yellow" / f"year={year}" / f"month={month}"
               / f"yellow_tripdata_{year}-{month}.parquet")
    destino.parent.mkdir(parents=True, exist_ok=True)

    h_esp = hash_ya_registrado(con, str(destino), url)
    if destino.exists() and h_esp and sha256_file(destino) == h_esp:
        print(f"[idempotente] {destino.name} ya descargado.")
        return destino

    try:
        descargar_con_reintentos(url, destino)
    except Exception as exc:
        registrar_ingesta(con, str(destino), url, None, None, "", "error", str(exc))
        raise

    h = sha256_file(destino)
    filas = con.execute(
        "SELECT COUNT(*) FROM read_parquet(?)", [str(destino)]
    ).fetchone()[0]
    registrar_ingesta(con, str(destino), url, filas,
                      destino.stat().st_size, h, "ok")
    print(f"[ok] {destino.name}: {filas:,} filas, {destino.stat().st_size:,} bytes, "
          f"sha256={h[:12]}…")
    return destino


def _validar_mes(mes: str) -> None:
    try:
        year, month = mes.split("-")
    except ValueError:
        raise ValueError(f"Formato inválido: '{mes}'. Esperado AAAA-MM.")
    if len(year) != 4 or len(month) != 2 or not (year.isdigit() and month.isdigit()):
        raise ValueError(f"Formato inválido: '{mes}'. Esperado AAAA-MM.")
    if not (1 <= int(month) <= 12):
        raise ValueError(f"Mes fuera de rango: {month}.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Ingesta NYC TLC Yellow Taxi.")
    parser.add_argument("mes", nargs="?", default="2025-03",
                        help="Mes a descargar (AAAA-MM). Default: 2025-03")
    args = parser.parse_args()

    try:
        _validar_mes(args.mes)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    con = get_connection()
    try:
        init_ingestion_log(con)
        ingestar_zonas(con)
        ingestar_mes(args.mes, con)
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())