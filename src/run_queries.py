import duckdb
import pathlib
import re
import pandas as pd

# Calculamos la ruta raíz del proyecto (dos niveles arriba de src/)
BASE_DIR = pathlib.Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "dbt_analytics.duckdb"
SQL_DIR = BASE_DIR / "sql"
OUTPUT_FILE = BASE_DIR / "RESULTADOS.md"

def run_queries():
    if not DB_PATH.exists():
        print(f"❌ No se encontró la base de datos en {DB_PATH}. Corré el pipeline primero.")
        return

    con = duckdb.connect(str(DB_PATH), read_only=True)
    lines = ["# Resultados de las Preguntas de Negocio\n"]
    
    # Ordenar los archivos (01, 02, 03...)
    for sql_file in sorted(SQL_DIR.glob("*.sql")):
        content = sql_file.read_text(encoding="utf-8")
        
        # Extraer la interpretación (busca un comentario con -- @interpretacion: ...)
        match = re.search(r"--\s*@interpretacion:\s*(.*)", content)
        interpretacion = match.group(1).strip() if match else "(Sin interpretación provista)"
        
        clean_query = content.strip()
        
        try:
            df = con.execute(clean_query).df()
            
            title = sql_file.stem.replace('_', ' ').title()
            lines.append(f"## {title}\n")
            lines.append(f"### Consulta SQL\n```sql\n{clean_query}\n```\n")
            lines.append(f"### Respuesta\n{df.to_markdown(index=False)}\n")
            lines.append(f"**Interpretación:** {interpretacion}\n")
            lines.append("---\n")
            
        except Exception as e:
            lines.append(f"## {sql_file.stem}\n**Error al ejecutar:** {e}\n---\n")
    
    con.close()
    OUTPUT_FILE.write_text("\n".join(lines), encoding="utf-8")
    print(f"✅ RESULTADOS.md generado en {OUTPUT_FILE}")

if __name__ == "__main__":
    run_queries()