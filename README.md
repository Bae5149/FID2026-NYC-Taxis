# Pipeline de Ingeniería de Datos — NYC Yellow Taxi (TLC)

Proyecto académico de ingeniería de datos orientado a la comparación interanual de dos meses del dataset oficial de **NYC Yellow Taxi Trip Records (TLC)**, ejecutado sobre una máquina virtual **Debian (4 vCPU, 8 GB RAM)** con un stack eficiente en memoria (**dlt, dbt, DuckDB, Dagster, Python y observabilidad liviana**).

---

## Tabla de Contenidos

1. [Arquitectura y Stack Tecnológico](#arquitectura-y-stack-tecnológico)
2. [Estructura del Repositorio](#estructura-del-repositorio)
3. [Instalación y Ejecución](#instalación-y-ejecución)
4. [Etapas del Pipeline](#etapas-del-pipeline)
5. [Decisiones Técnicas y de Negocio](#decisiones-técnicas-y-de-negocio)
6. [Calidad de Datos y Cuarentena](#calidad-de-datos-y-cuarentena)
7. [Modelado Dimensional (Esquema Estrella)](#modelado-dimensional-esquema-estrella)
8. [Rendimiento y Recursos](#rendimiento-y-recursos)
9. [Limitaciones Conocidas](#limitaciones-conocidas)
10. [Declaración de Uso de IA](#declaración-de-uso-de-ia)

---

## Arquitectura y Stack Tecnológico

El pipeline garantiza la invariante de reconciliación de datos: **todo registro leído finaliza en la capa curada o en cuarentena** ($\text{Filas Leídas} = \text{Filas Aceptadas} + \text{Filas en Cuarentena}$).

```text
[TLC CloudFront (Parquet + CSV)]
        │
        ▼  (1. Ingesta idempotente + Hash SHA-256 + Logs)
  [dlt (data load tool)] ──► data/raw/yellow/year=AAAA/month=MM/
        │
        ▼  (2. Auditoría de contrato YAML + Normalización snake_case)
  [Python / PyArrow / DuckDB]
        │
        ▼  (3. Reglas de calidad, Cuarentena y Reconciliación)
  [dbt + DuckDB] ──────────► quarantine_trips (rechazadas + motivo)
        │
        ▼  (4. Capa Curada particionada Hive + Modelo Estrella)
  [data/curated/ & Marts] ─► fact_trips, dim_zone, dim_date, agg_zone_hour
        │
        ▲
[Orquestación y Observabilidad: Dagster UI + Evidence.dev / Dozzle]
```

### Herramientas Seleccionadas
* **Ingesta (`dlt` - data load tool):** Manejo declarativo de fuentes, reintentos automáticos con *backoff*, estado de cargas e idempotencia, conservando los archivos crudos intactos y registrando metadatos (`load_info` e `ingestion_log`).
* **Motor Analítico y Almacenamiento (`DuckDB` + `Parquet`):** Procesamiento columnar *in-process* de alto rendimiento con límites explícitos de memoria (`memory_limit`) para evitar desbordamientos en entornos de 8 GB RAM.
* **Transformación, Calidad y Modelado (`dbt-duckdb`):** Modelos SQL modulares, pruebas automatizadas de calidad, separación de registros en cuarentena y construcción del esquema estrella.
* **Orquestación (`Dagster` + `dagster-dbt`):** Definición de *Software-Defined Assets*, control de dependencias, reintentos, logs centralizados por corrida y seguimiento de metadatos (`MaterializeResult`).
* **Observabilidad Liviana (`Dagster UI` + `Evidence.dev` / `Dozzle`):** Monitoreo de corridas, dashboards históricos en SQL sobre archivos estáticos y visualización de logs de contenedores con bajo consumo de memoria en reposo.
* **Entorno Reproducible (`Docker` + `code-server`):** Contenerización de servicios para despliegue portable y acceso remoto al entorno de desarrollo.

---

## Estructura del Repositorio

```text
.
├── contracts/
│   └── yellow_schema.yaml          # Contrato de esquema versionado (nombres y tipos)
├── dbt_project/                    # Proyecto dbt (staging, quarantine, curated, marts)
│   ├── models/
│   ├── tests/
│   └── dbt_project.yml
├── src/
│   ├── ingestion/                  # Pipelines y recursos de dlt (descarga, hash, logs)
│   ├── schema/                     # Validador de esquema contra contrato YAML
│   └── dagster_defs/               # Assets, jobs y recursos de Dagster
├── sql/                            # Consultas SQL individuales para las preguntas de negocio
├── tests/                          # Tests automatizados (pytest: calidad, idempotencia, reconciliación)
├── data/                           # Ignorado en Git (.gitignore): raw/, curated/, duckdb/
├── docker-compose.yml              # Servicios contenerizados (Dagster, code-server, Dozzle)
├── Makefile                        # Punto de entrada único para ejecución y pruebas
├── requirements.txt                # Dependencias de Python (Python 3.11+)
├── RESULTADOS.md                   # Respuestas SQL e interpretaciones de negocio
└── README.md                       # Documentación técnica del proyecto
```

---

## Instalación y Ejecución

### Requisitos Previos
* **Python:** `3.11` o superior.
* **Make** y **Docker / Docker Compose**.
* **Hardware recomendado:** 4 núcleos CPU y 8 GB de RAM.

### 1. Configuración Local
```bash
git clone <URL_DEL_REPOSITORIO>
cd FID2026-NYC-Taxis

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt
```

### 2. Ejecución Completa (Comando Único)
```bash
make all MES=2025-03
```
Este comando ejecuta secuencialmente:
1. Levantamiento de servicios de apoyo y ejecución del pipeline para el mes indicado y su comparación con 2024.
2. Ingesta idempotente mediante `dlt` y auditoría de esquema contra `contracts/yellow_schema.yaml`.
3. Transformación, reglas de calidad, cuarentena y reconciliación con `dbt` + `DuckDB`.
4. Generación de la capa curada particionada y tablas del modelo estrella.

### 3. Ejecución de Tests Automatizados
```bash
make test MES=2025-03
```

---

## Etapas del Pipeline

1. **Ingesta (`dlt`):** Descarga los archivos fuente a `data/raw/yellow/year=AAAA/month=MM/` sin alterarlos. Calcula el hash `SHA-256`, verifica existencia previa para garantizar idempotencia y registra cada operación en `ingestion_log` (`archivo`, `url`, `filas`, `bytes`, `hash`, `timestamp`, `estado`), con reintentos ante fallos de red.
2. **Validación de Esquema:** Audita el esquema físico de cada archivo Parquet contra `contracts/yellow_schema.yaml` antes de transformarlo, reportando columnas faltantes, columnas nuevas y diferencias de tipos, y normaliza los nombres a `snake_case`.
3. **Calidad y Cuarentena (`dbt`):** Evalúa las reglas de negocio definidas. Los registros que violan reglas de severidad `rechazo` pasan a `quarantine_trips` junto con el archivo origen y el listado de reglas incumplidas; los de severidad `advertencia` mantienen su flujo con marcas en `quality_flags`.
4. **Transformación y Almacenamiento Curado:** Escribe los datos limpios en formato Parquet particionado estilo Hive (`data/curated/yellow/year=AAAA/month=MM/`), enriquecidos con zonas/barrios y métricas derivadas (`duracion_min`, `velocidad_mph`, `fecha_subida`, `hora_subida`, `dia_semana`, `propina_pct_tarifa`).
5. **Modelado y Analítica:** Construye el esquema estrella (`fact_trips`, `dim_zone`, `dim_date`) y la tabla agregada `agg_zone_hour` para responder las consultas analíticas documentadas en `RESULTADOS.md`.

---

## Decisiones Técnicas y de Negocio

### Manejo de Evolución de Esquema (`cbd_congestion_fee` y columnas nuevas)
* **Tratamiento de `cbd_congestion_fee` en 2024:** Este cargo entró en vigor en enero de 2025, por lo que no existe en los archivos de 2024. En los datos de 2024 se inyecta explícitamente casteado a `DOUBLE` con valor `NULL` (no `0.0`), evitando distorsionar métricas históricas o confundir ausencia de impuesto con viajes exentos.
* **Columnas nuevas no contempladas en el contrato:** Se registra una advertencia (`WARNING`) en los logs indicando nombre y tipo de la columna desconocida, y se excluye de la proyección hacia *staging* hasta que el contrato YAML sea actualizado de forma explícita.

### Tipado de Datos en el Contrato (`contracts/yellow_schema.yaml`)
* **Identificadores y códigos categóricos (`BIGINT`):** `vendor_id`, `ratecode_id`, `passenger_count`, `pu_location_id`, `do_location_id` y `payment_type` representan códigos enteros discretos según el diccionario oficial de la TLC y se castean explícitamente a `BIGINT`.
* **Métricas financieras y de distancia (`DOUBLE`):** `trip_distance`, `fare_amount`, `tip_amount`, `total_amount` y recargos se definen como `DOUBLE`.
* **Banderas (`VARCHAR`) y Fechas (`TIMESTAMP`):** `store_and_fwd_flag` se define como `VARCHAR` por compatibilidad nativa con Parquet (que no posee `CHAR(1)` fijo), y las marcas de tiempo se mantienen como `TIMESTAMP`.

### Reprocesamiento Idempotente por Partición
Al reprocesar un mes (`MES=AAAA-MM`), únicamente se actualiza la partición física correspondiente (`year=AAAA/month=MM/`), manteniendo intactos los demás meses almacenados.

| Partición | Conteo Antes del Reproceso | Conteo Después del Reproceso | Estado |
| :--- | :---: | :---: | :---: |
| `year=2024/month=MM` | *(Completar con corrida real)* | *(Idéntico)* | Intacta |
| `year=2025/month=MM` | *(Completar con corrida real)* | *(Idéntico)* | Reprocesada sin duplicados |

---

## Calidad de Datos y Cuarentena

Se implementaron **8 reglas de calidad**. La reconciliación final aborta el pipeline si `filas_leidas != filas_aceptadas + filas_cuarentena`.

| ID Regla | Descripción | Severidad | Umbral / Condición Justificada |
| :--- | :--- | :--- | :--- |
| `DQ_01` | Fecha de subida fuera del mes del archivo | `Rechazo` | `DATE_TRUNC('month', tpep_pickup_datetime)` distinto al mes procesado. Evita contaminación entre períodos. |
| `DQ_02` | Bajada anterior o igual a la subida | `Rechazo` | `tpep_dropoff_datetime <= tpep_pickup_datetime`. Físicamente imposible; invalida la duración. |
| `DQ_03` | Distancia inválida o extrema | `Rechazo` | `trip_distance <= 0` o `trip_distance > 200` millas. Descarta viajes sin desplazamiento o errores de taxímetro fuera del área metropolitana de NYC. |
| `DQ_04` | Importe total negativo | `Rechazo` | `total_amount < 0`. Excluye contracargos o ajustes contables negativos. |
| `DQ_05` | Cantidad de pasajeros nula o cero | `Advertencia` | `passenger_count IS NULL OR passenger_count <= 0`. Se marca en `flags` sin descartar el viaje ni alterar métricas financieras. |
| `DQ_06` | Zona de origen o destino inexistente | `Rechazo` | `pu_location_id` o `do_location_id` ausente en `taxi_zone_lookup.csv`. Asegura integridad referencial con `dim_zone`. |
| `DQ_07` | Filas duplicadas exactas | `Rechazo` | Registros idénticos en todas las columnas de negocio; se conserva la primera ocurrencia. |
| `DQ_08` | Velocidad promedio irreal | `Rechazo` | Velocidad calculada `> 100 mph`. Detecta inconsistencias entre distancia y duración del viaje. |

---

## Modelado Dimensional (Esquema Estrella)

* **`fact_trips`:** Un viaje individual válido (aceptado) de taxi amarillo registrado por la TLC, con clave subrogada derivada de sus atributos naturales.
* **`dim_zone`:** Una zona geográfica oficial de taxi de Nueva York (`location_id`), con `borough`, `zone` y `service_zone`.
* **`dim_date`:** Una fecha calendario única (`date_key`), con atributos de año, mes, día, día de la semana e indicador de fin de semana.
* **`agg_zone_hour`:** Una combinación única de zona de origen (`pu_location_id`), fecha y hora del día (`0-23`), con cantidad de viajes, ingreso total y duración promedio en minutos.

---

## Rendimiento y Recursos

* **Entorno:** VM Debian — 4 núcleos CPU / 8 GB RAM.
* **Control de memoria:** Límites explícitos de memoria en contenedores (`mem_limit`), `dlt` con un worker y buffers acotados, `dbt` con `--threads 1` y `DuckDB` con `memory_limit` controlado.
* **Concurrencia DuckDB:** Separación de datos/métricas y ejecución secuencial para evitar conflictos de escritura concurrente.
* **Tiempo total de ejecución (`make all`):** *(Completar tras ejecutar la corrida de los dos meses en tu VM)*.
* **Pico máximo de consumo de RAM:** *(Completar midiendo con `/usr/bin/time -v` o `docker stats`)*.

---

## Limitaciones Conocidas

1. **Propinas en efectivo no registradas:** Según el diccionario oficial de la TLC, `tip_amount` refleja únicamente propinas abonadas con tarjeta de crédito (las propinas en efectivo figuran como `0.0`).
2. **Concurrencia de escritura en DuckDB:** Al ser un motor embebido de un solo escritor, se evitan escrituras concurrentes sobre el mismo archivo `.duckdb`.
3. **Procesamiento batch mensual:** Diseñado para cargas mensuales históricas y no para *streaming* en tiempo real.

---

## Declaración de Uso de IA

Se declara el uso de inteligencia artificial (**Gemini**) como herramienta de apoyo durante el desarrollo para:
* Diseño y revisión de arquitectura optimizada para bajo consumo de memoria (`dlt`, `dbt`, `DuckDB`, `Dagster`).
* Redacción inicial de plantillas, estructuras de validación y documentación técnica.

Todo el código, reglas de calidad, pruebas y consultas SQL fueron revisados, adaptados y validados por el autor del proyecto.