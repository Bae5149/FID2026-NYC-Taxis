# Variable para el mes asignado (por defecto 2025-03 si no se especifica)
MES ?= 2025-03

# Exportamos MES para que Dagster y Docker la hereden
export MES

.PHONY: all install up down pipeline test shaper-up clean dagster-ui

#  Comando único
all: up pipeline

#   Servicios permanentes
up:
	@echo "Levantando servicios en segundo plano..."
	docker compose up -d

#  Apagar servicios y eliminar contenedores huérfanos
down:
	@echo "Apagando servicios..."
	docker compose down --remove-orphans

#  Construir la imagen del pipeline (dlt + dbt + duckdb)
install:
	@echo "Construyendo imagen de Docker del pipeline..."
	docker compose build pipeline
	pip install -r requirements-dagster.txt

#  Pipeline orquestado por Dagster: ingesta (dlt), validación de esquema, calidad/cuarentena y modelos (dbt) para $(MES) y su par 2024
pipeline:
	@echo "Ejecutando pipeline completo para el mes $(MES) mediante Dagster..."

	mkdir -p .dagster_home

	DAGSTER_HOME=$(PWD)/.dagster_home \
	conda run -n nyc-dagster \
	MES=$(MES) dagster asset materialize \
	--select "ingesta_dlt,schema_contract,dbt_quality,curate_partitioned,dbt_marts,shaper_dashboard" \
	-m dagster_project.definitions

#  Ejecutar suite de tests automatizados (pytest: calidad sintética, idempotencia y reconciliación)
test:
	@echo "Ejecutando tests automatizados..."
	docker compose run --rm -e MES=$(MES) pipeline pytest tests/


#  Limpieza profunda de contenedores, volúmenes y base DuckDB local
clean:
	@echo "Limpiando entorno y base de datos local..."
	docker compose down -v --remove-orphans
	rm -rf data/nyc_taxi.duckdb
	rm -rf data/nyc_taxi.duckdb.wal
	rm -rf data/dbt_analytics.duckdb
	rm -rf data/dbt_analytics.duckdb.wal
	docker run --rm \
  -v $(PWD)/data:/data \
  alpine \
  sh -c "rm -rf /data/curated_hive"

shaper-up:
	@echo "Recreando el servicio Shaper con los datos más recientes..."
	MES=$(or $(MES),2025-04) docker compose up -d --force-recreate shaper
	@python -c 'import glob, json, os, time, urllib.request, urllib.error; from pathlib import Path; url = os.getenv("SHAPER_URL", "http://127.0.0.1:5454"); [time.sleep(0.5) for _ in range(60) if (lambda: (_ for _ in ()).throw(Exception()))()] if False else None' 2>/dev/null || true
	@python -c 'import glob, json, os, time, urllib.request, urllib.error; from pathlib import Path; url = os.getenv("SHAPER_URL", "http://127.0.0.1:5454"); ready = False; [ (time.sleep(0.5) if not ready else None) for _ in range(60) if not ready and (urllib.request.urlopen(f"{url}/", timeout=2).status < 500 if (lambda: (ready := True))() else False) ]; files = sorted(Path("dashboards").glob("*.sql")); assert files, "No hay archivos .sql en dashboards/"; [ print(f"OK {p.name}:", urllib.request.urlopen(urllib.request.Request(f"{url}/api/dashboards", data=json.dumps({"name": p.stem.replace("_", " ").title(), "content": p.read_text(encoding="utf-8").strip()}).encode("utf-8"), headers={"Content-Type": "application/json"}, method="POST"), timeout=10).status) for p in files ]'

dagster-ui:
	@echo "Abriendo interfaz de Dagster..."
	@mkdir -p .dagster_home
	@echo "Dagster UI disponible en http://127.0.0.1:3000"

	DAGSTER_HOME=$(PWD)/.dagster_home \
	conda run -n nyc-dagster \
	dagster dev \
	--host 127.0.0.1 \
	--port 3041 \
	-m dagster_project.definitions