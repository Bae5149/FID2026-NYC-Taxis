# Variables
PYTHON := python3
VENV := .venv
VENV_PYTHON := $(VENV)/bin/python
VENV_PIP := $(VENV)/bin/pip
REQUIREMENTS := requirements.txt

# Meses: El asignado y el de comparación (calcula el año anterior automáticamente)
MES ?= 2024-08
MES_COMP ?= $(shell echo $(MES) | awk -F- '{print $$1-1"-"$$2}')

# Aseguramos que dbt se ejecute usando el entorno virtual
export PATH := $(PWD)/$(VENV)/bin:$(PATH)

.PHONY: all install ingesta esquema dbt_run dbt_test test

# El flujo completo
all: install ingesta esquema dbt_run dbt_test test

install:
	@test -f $(VENV_PIP) || (echo "Creando entorno virtual..." && $(PYTHON) -m venv $(VENV))
	@$(VENV_PIP) install --upgrade pip
	@$(VENV_PIP) install -r $(REQUIREMENTS)
	@echo "Dependencias listas en $(VENV)/"

ingesta: install
	@echo "Ejecutando ingesta para $(MES) y $(MES_COMP)..."
	$(VENV_PYTHON) -m src.ingesta $(MES)
	$(VENV_PYTHON) -m src.ingesta $(MES_COMP)

# Nuevo paso: Validar contrato de esquema ANTES de transformar
esquema: ingesta
	@echo "Validando contrato de esquema..."
	$(VENV_PYTHON) -m src.esquema $(MES) $(MES_COMP)

# dbt hace la normalización y unificación (Parte 2) y el modelado (Parte 5)
dbt_run: esquema
	@echo "Ejecutando modelos de dbt..."
	dbt run --project-dir dbt --profiles-dir dbt

dbt_test: dbt_run
	@echo "Ejecutando tests de dbt..."
	dbt test --project-dir dbt --profiles-dir dbt

test: install
	$(VENV_PYTHON) -m pytest tests/