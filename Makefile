# Variables
PYTHON := python3
VENV := .venv
VENV_PYTHON := $(VENV)/bin/python
VENV_PIP := $(VENV)/bin/pip
REQUIREMENTS := requirements.txt
MES ?= 2025-03

.PHONY: all install ingesta test

all: install ingesta

install: $(VENV)

$(VENV): $(REQUIREMENTS)
	@echo "Creando entorno virtual..."
	$(PYTHON) -m venv $(VENV)
	$(VENV_PIP) install --upgrade pip
	@echo "Instalando dependencias desde $(REQUIREMENTS)..."
	$(VENV_PIP) install -r $(REQUIREMENTS)

ingesta: install
	@echo "Ejecutando ingesta para el mes $(MES)..."
	$(VENV_PYTHON) -m src.ingesta $(MES)

test: install
	$(VENV_PYTHON) -m pytest tests/