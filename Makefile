# Variable para el mes asignado (por defecto 2025-03 si no se especifica)
MES ?= 2025-03

# Exportamos MES para que docker compose y los contenedores la hereden
export MES

.PHONY: all install up down pipeline test dashboards clean

# 1. Comando único exigido por la consigna: levanta servicios, corre el pipeline y genera resultados
all: up pipeline

# 2. Levantar servicios en segundo plano (Evidence Web, Dozzle, etc.)
up:
	@echo "Levantando servicios en segundo plano..."
	docker compose up -d

# 3. Apagar servicios y eliminar contenedores huérfanos
down:
	@echo "Apagando servicios..."
	docker compose down --remove-orphans

# 4. Construir o reconstruir la imagen del pipeline (dlt + dbt + duckdb)
install:
	@echo "Construyendo imagen de Docker del pipeline..."
	docker compose build pipeline

# 5. Ejecutar ingesta (dlt), validación de esquema, calidad/cuarentena y modelos (dbt) para $(MES) y su par 2024
pipeline:
	@echo "Ejecutando pipeline completo para el mes $(MES)..."
	docker compose run --rm -e MES=$(MES) pipeline

# 6. Ejecutar suite de tests automatizados (pytest: calidad sintética, idempotencia y reconciliación)
test:
	@echo "Ejecutando tests automatizados..."
	docker compose run --rm -e MES=$(MES) pipeline pytest tests/

# 7. Compilar el sitio estático de Evidence con los datos actualizados
dashboards:
	@echo "Generando dashboards estáticos de Evidence..."
	docker compose run --rm evidence_build

# 8. Limpieza profunda de contenedores, volúmenes y base DuckDB local
clean:
	@echo "Limpiando entorno y base de datos local..."
	docker compose down -v --remove-orphans
	rm -rf data/nyc_taxi.duckdb data/nyc_taxi.duckdb.wal