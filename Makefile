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
	docker compose up -d --force-recreate shaper

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