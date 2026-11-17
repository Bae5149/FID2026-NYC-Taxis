"""Tests Parte 1: hash, idempotencia y reconciliación de conteos."""
import duckdb

from src import ingesta as ing
from src import db as db_mod


def test_sha256_detecta_cambios(tmp_path):
    f = tmp_path / "archivo.bin"
    f.write_bytes(b"contenido original")
    h1 = ing.sha256_file(f)
    assert ing.sha256_file(f) == h1          # mismo contenido → mismo hash
    f.write_bytes(b"contenido original!")
    assert ing.sha256_file(f) != h1          # un byte distinto → hash distinto


def test_ingesta_idempotente_no_redescarga(monkeypatch, tmp_path):
    con = duckdb.connect(":memory:")
    db_mod.init_ingestion_log(con)

    # Simular archivo ya descargado en la ruta que arma ingestar_mes
    destino = (tmp_path / "yellow" / "year=2025" / "month=03"
               / "yellow_tripdata_2025-03.parquet")
    destino.parent.mkdir(parents=True)
    destino.write_bytes(b"datos")

    # OJO: monkeypatch sobre 'ing' (no 'db_mod'), porque ingesta.py
    # importó el nombre directamente con 'from .db import ...'
    monkeypatch.setattr(ing, "RAW_DIR", tmp_path)
    monkeypatch.setattr(ing, "sha256_file", lambda p: "hash_fijo")
    monkeypatch.setattr(ing, "hash_ya_registrado", lambda c, a, u: "hash_fijo")

    llamadas = {"descargas": 0}

    def fake_descargar(url, path):
        llamadas["descargas"] += 1

    monkeypatch.setattr(ing, "descargar_con_reintentos", fake_descargar)

    ing.ingestar_mes("2025-03", con)
    assert llamadas["descargas"] == 0        # no descargó → idempotente


def test_reconciliacion_de_conteos(tmp_path):
    parquet = tmp_path / "mini.parquet"
    con = duckdb.connect(":memory:")
    con.execute(
        f"COPY (SELECT * FROM (VALUES (1),(2),(3)) t(x)) "
        f"TO '{parquet}' (FORMAT parquet)"
    )
    n = con.execute(
        "SELECT COUNT(*) FROM read_parquet(?)", [str(parquet)]
    ).fetchone()[0]
    assert n == 3