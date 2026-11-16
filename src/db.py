"""Conexión a DuckDB y helpers del log de ingesta."""
import duckdb

from .config import DB_PATH, TMP_DIR, DUCKDB_MEMORY_LIMIT, DUCKDB_THREADS


def get_connection(read_only: bool = False) -> duckdb.DuckDBPyConnection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH), read_only=read_only)
    con.execute(f"SET memory_limit = '{DUCKDB_MEMORY_LIMIT}'")
    con.execute(f"SET threads = {DUCKDB_THREADS}")
    con.execute(f"SET temp_directory = '{TMP_DIR}'")
    return con


def init_ingestion_log(con) -> None:
    con.execute("""
        CREATE TABLE IF NOT EXISTS ingestion_log (
            archivo       VARCHAR NOT NULL,
            url           VARCHAR NOT NULL,
            filas         BIGINT,
            "bytes"       BIGINT,
            hash_sha256   VARCHAR NOT NULL,
            fecha_hora    TIMESTAMP NOT NULL,
            estado        VARCHAR NOT NULL CHECK (estado IN ('ok', 'error')),
            mensaje_error VARCHAR,
            PRIMARY KEY (archivo, url)
        );
    """)


def hash_ya_registrado(con, archivo: str, url: str) -> str | None:
    row = con.execute(
        "SELECT hash_sha256 FROM ingestion_log "
        "WHERE archivo = ? AND url = ? AND estado = 'ok'",
        [archivo, url],
    ).fetchone()
    return row[0] if row else None


def registrar_ingesta(con, archivo, url, filas, bytes_, hash_, estado, mensaje_error=None):
    con.execute("""
        INSERT INTO ingestion_log
            (archivo, url, filas, "bytes", hash_sha256, fecha_hora, estado, mensaje_error)
        VALUES (?, ?, ?, ?, ?, now(), ?, ?)
        ON CONFLICT (archivo, url) DO UPDATE SET
            filas = EXCLUDED.filas,
            "bytes" = EXCLUDED."bytes",
            hash_sha256 = EXCLUDED.hash_sha256,
            fecha_hora = EXCLUDED.fecha_hora,
            estado = EXCLUDED.estado,
            mensaje_error = EXCLUDED.mensaje_error;
    """, [archivo, url, filas, bytes_, hash_, estado, mensaje_error])