"""Validacion del contrato de esquema TLC contra los archivos Parquet raw."""
import sys
from pathlib import Path
import yaml
import duckdb

from .config import BASE_DIR, RAW_DIR, DB_PATH

CONTRACT_PATH = BASE_DIR / "contracts" / "yellow_schema.yaml"

def cargar_contrato():
    with CONTRACT_PATH.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def validar_mes(con, mes, contrato):
    year, month = mes.split("-")
    ruta = RAW_DIR / "yellow" / f"year={year}" / f"month={month}" / f"yellow_tripdata_{mes}.parquet"
    
    if not ruta.exists():
        print(f"Error: No existe el archivo para {mes}.")
        return False

    query = f"DESCRIBE SELECT * FROM read_parquet('{ruta}')"
    real = {row[0]: row[1] for row in con.execute(query).fetchall()}
    cols_contrato = {c["origen"]: c for c in contrato["columnas"]}

    faltantes = []
    nuevas = []
    tipos_distintos = []

    for origen, specs in cols_contrato.items():
        if origen not in real:
            if specs.get("obligatorio", False):
                faltantes.append(origen)
        else:
            if specs["tipo"] not in real[origen] and not (specs["tipo"] == "DOUBLE" and "DECIMAL" in real[origen]):
                tipos_distintos.append(f"{origen} (esp: {specs['tipo']}, real: {real[origen]})")
    
    for col_real in real:
        if col_real not in cols_contrato and col_real not in ["month", "year"]:
            nuevas.append(col_real)

    print(f"\nValidando esquema para {mes}...")
    if faltantes:
        print(f"Columnas obligatorias faltantes: {faltantes}")
        return False
    if nuevas:
        print(f"Columnas nuevas (ignoradas): {nuevas}")
    if tipos_distintos:
        print(f"Tipos diferentes: {tipos_distintos}")
        
    print(f"Validación superada.")
    return True

def main():
    if len(sys.argv) < 2:
        return 1
    contrato = cargar_contrato()
    con = duckdb.connect(str(DB_PATH))
    
    exito = validar_mes(con, sys.argv[1], contrato)
    if exito and len(sys.argv) >= 3:
        exito = validar_mes(con, sys.argv[2], contrato)
        
    con.close()
    return 0 if exito else 1

if __name__ == "__main__":
    sys.exit(main())