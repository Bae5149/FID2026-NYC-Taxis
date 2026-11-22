"""Constantes de configuración del pipeline NYC TLC."""
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
TMP_DIR = DATA_DIR / "duckdb_tmp"
DB_PATH = DATA_DIR / "pipeline.duckdb"

TLC_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
ZONES_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

# Restricciones de hardware (8 GB RAM, 4 núcleos)
DUCKDB_MEMORY_LIMIT = "5GB"
DUCKDB_THREADS = 4

# Reintentos de descarga
MAX_RETRIES = 3
BACKOFF_BASE_SECONDS = 1
CHUNK_SIZE = 8192