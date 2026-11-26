# Pipeline de Ingeniería de Datos — NYC Yellow Taxi (TLC)

Proyecto académico de ingeniería de datos orientado a la comparación interanual de dos meses del dataset oficial de **NYC Yellow Taxi Trip Records (TLC)**, ejecutado sobre una máquina virtual **Debian (4 vCPU, 8 GB RAM)** con un stack eficiente en memoria (**dlt, dbt, DuckDB, Dagster, Python y observabilidad liviana**).

### Integrantes

Nombre | Legajo

**Jeremias Benjamin Pomares Paz** | Legajo: `58008`

**Ana Carolina Samana Baena** | Legajo: `57944`

## Tabla de Contenidos

[Arquitectura y Stack Tecnológico](https://www.google.com/search?q=%23arquitectura-y-stack-tecnol%C3%B3gico) •
[Estructura del Repositorio](https://www.google.com/search?q=%23estructura-del-repositorio) •
[Instalación y Ejecución](https://www.google.com/search?q=%23instalaci%C3%B3n-y-ejecuci%C3%B3n) •
[Etapas del Pipeline](https://www.google.com/search?q=%23etapas-del-pipeline) •
[Decisiones Técnicas y de Negocio](https://www.google.com/search?q=%23decisiones-t%C3%A9cnicas-y-de-negocio) •
[Calidad de Datos y Cuarentena](https://www.google.com/search?q=%23calidad-de-datos-y-cuarentena) •
[Modelado Dimensional (Esquema Estrella)](https://www.google.com/search?q=%23modelado-dimensional-esquema-estrella) •
[Rendimiento y Recursos](https://www.google.com/search?q=%23rendimiento-y-recursos) •
[Limitaciones Conocidas](https://www.google.com/search?q=%23limitaciones-conocidas) •
[Declaración de Uso de IA](https://www.google.com/search?q=%23declaraci%C3%B3n-de-uso-de-ia)

## Arquitectura y Stack Tecnológico

El pipeline garantiza la invariante de reconciliación de datos: **todo registro leído finaliza en la capa curada o en cuarentena** (Filas Leıˊdas=Filas Aceptadas+Filas en Cuarentena\text{Filas Leídas} = \text{Filas Aceptadas} + \text{Filas en Cuarentena}Filas Leıˊdas=Filas Aceptadas+Filas en Cuarentena).

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
  [dbt + DuckDB] ──────────► quarantine_trips + dq_reconciliation
        │
        ▼  (4. Capa Curada particionada Hive + Modelos Intermediate dbt)
  [src/curate_partitioned.py] ─► data/curated_hive/year=AAAA/month=M/
        │
        ▼  (5. Modelado Analítico dbt)
  [dbt marts] ────────► fact_trips, dim_zone, dim_date, agg_zone_hour
        │
        ▼
  [Shaper] ────────────► Dashboard analítico

[Dagster] orquesta las etapas hasta la generación del dashboard
[Dagster UI + Dozzle] permiten monitorear corridas y logs
```

### Herramientas Seleccionadas

**Ingesta (`dlt` - data load tool):** Manejo declarativo de fuentes, reintentos automáticos con *backoff*, estado de cargas e idempotencia, conservando los archivos crudos intactos y registrando metadatos (`ingestion_log`).

**Motor Analítico y Almacenamiento (`DuckDB` + `Parquet`):** Procesamiento columnar *in-process* de alto rendimiento con límites explícitos de memoria (`memory_limit` y `threads`) para evitar desbordamientos en entornos de 8 GB RAM.

**Transformación, Calidad y Modelado (`dbt-duckdb`):** Modelos SQL modulares, pruebas automatizadas de calidad, separación de registros en cuarentena y construcción de los modelos dimensionales y agregados en la capa `marts`.

**Orquestación (`Dagster`):** Definición de *Software-Defined Assets* propios, control de dependencias y reintentos. Dagster ejecuta los pasos del pipeline en orden, incluyendo la creación del dashboard con Shaper una vez materializados los modelos analíticos.

**Dashboards y Observabilidad (`Shaper` + `Dagster UI` / `Dozzle`):** Shaper genera el dashboard a partir de los datos y modelos analíticos del proyecto. Dagster orquesta su creación como parte del flujo, y su interfaz permite monitorear las corridas; Dozzle permite visualizar los logs de contenedores.

**Entorno y Despliegue (`Docker` + `Conda`):** El entorno base de Python se gestiona con Conda (conda activate nyc-dagster), para evitar conflictos de version con dependencias de python/dagster. Los servicios de infraestructura y ejecución se contenerizan con Docker para un despliegue portable, mientras se mantiene su visibilidad en Dozzle.

## Estructura del Repositorio

```text
.
├── contracts/
│   └── yellow_schema.yaml          # Contrato de esquema versionado (nombres y tipos)
├── dbt/                    # Proyecto dbt (staging, quarantine, intermediate, etc.)
│   ├── models/
│       └── marts/                  
│       └── staging/
│       └── data_quality/
│       └── intermediate/
│   ├── tests/
│   ├── dbt_project.yml
│   └── profiles.yml
├── dashboards/                         # Proyecto y dashboards generados con Shaper
├── dagster_project/
│   ├── assets.py                   # Assets propios (subprocess.run)
│   └── definitions.py
│   └── dbt_project.yml
├── src/
│   ├── ingest_dlt.py               # Ingesta con dlt + validaciones de red
│   ├── curate_partitioned.py       # Capa Hive, zonas y métricas derivadas
│   ├── esquema.py                  # Validador de contrato YAML
│   └── db.py                       # Conexión DuckDB
├── sql/                            # Consultas SQL individuales para las preguntas de negocio
├── tests/                          # Tests automatizados 
├── data/                           # Ignorado en Git (.gitignore): raw/, curated/, curated_hive/
├── .dagster_home/                  # Idem
├── dagster_project/  
├── docker-compose.yml              # Servicios contenerizados (Dagster, code-server, Dozzle)
├── Makefile                        # Punto de entrada único para ejecución y pruebas
├── requirements.txt                # Dependencias de Python (Python 3.11+)
├── RESULTADOS.md                   # Respuestas SQL e interpretaciones de negocio
└── README.md                       # Documentación técnica del proyecto
```

## Instalación y Ejecución

### Requisitos Previos

**Python:** `3.11` o inferior a `3.14`. • **Make** y **Docker / Docker Compose**. • **Conda**. • **Hardware recomendado:** 4 núcleos CPU y 8 GB de RAM.

### 1. Configuración Local

```bash
git clone <URL_DEL_REPOSITORIO>
cd FID2026-NYC-Taxis

# Crear y activar entorno Conda
conda create -n nyc-dagster python=3.12 -y
conda activate nyc-dagster
make install
```

### 2. Ejecución Completa (Comando Único)

```bash
make all MES=2025-03
```

Este comando levanta los servicios de Docker y orquesta secuencialmente el pipeline mediante Dagster, incluyendo la generación del dashboard Shaper:

1. Levantamiento de servicios de apoyo y ejecución del pipeline para el mes indicado y su comparación con 2024.
2. ingesta_dlt: Descarga idempotente y validación de hash SHA-256.
3. schema_contract: Auditoría de esquema contra YAML `contracts/yellow_schema.yaml`.
4. dbt_quality: Reglas de calidad, cuarentena y reconciliación. con `dbt` + `DuckDB`.
5. curate_partitioned: Generación de Hive Parquet particionado y enriquecimiento. (`src/curate_partitioned.py` -> `data/curated_hive/`) 
6. dbt_marts: Materialización del esquema estrella y agregados.
7. Dashboard Shaper: Generación del dashboard con los datos analíticos materializados.

### 3. Ejecución de Tests Automatizados

```bash
make test MES=2025-03
dbt test --project-dir dbt_project --profiles-dir dbt_project --select intermediate
```

## Etapas del Pipeline

1. **Ingesta (`dlt`):** Descarga los archivos fuente a `data/raw/yellow/year=AAAA/month=MM/` sin alterarlos. Calcula el hash `SHA-256`, verifica existencia previa para garantizar idempotencia y registra cada operación en `ingestion_log` (`archivo`, `url`, `filas`, `bytes`, `hash`, `timestamp`, `estado`), con reintentos ante fallos de red. La tabla de zonas se descarga una sola vez.
2. **Validación de Esquema:** Audita el Parquet contra `contracts/yellow_schema.yaml` antes de transformarlo, reportando columnas faltantes, columnas nuevas y diferencias de tipos, y normaliza los nombres a `snake_case`. Los dos meses se unifican en la capa de staging.
3. **Calidad y Cuarentena (`dbt`):** Evalúa las reglas de negocio definidas. Los registros que violan reglas de severidad `rechazo` pasan a `quarantine_trips` (guardando la fila original, archivo origen y las reglas violadas); los de severidad `advertencia` se marcan en una columna de flags sin descartar la fila. Se genera el reporte `dq_reconciliation`.
4. **Transformación y Almacenamiento (`src/curate_partitioned.py`):** Lee `data/curated/curated_yellow_trips.parquet` para el mes solicitado (`--mes AAAA-MM`) y su par interanual (`(AAAA-1)-MM`), elimina únicamente esas particiones en `data/curated_hive/` si existen (o crea las carpetas si son meses nuevos), calcula métricas derivadas (`duracion_minutos`, `velocidad_promedio_mph`, `fecha_subida`, `hora_subida`, `dia_semana_num`, `dia_semana_nombre`, `porcentaje_propina_tarifa`), realiza el doble `LEFT JOIN` contra `data/raw/taxi_zone_lookup.csv` (`pu_*` y `do_*`) y escribe Parquet particionado por `(year, month)` en `data/curated_hive/`.
5. **Modelado y preguntas (`dbt`):** Construye los modelos `fact_trips`, `dim_zone`, `dim_date` y `agg_zone_hour`. Deja preparadas estas tablas para ser utilizadas por las consultas planteadas en el parcial. No obstante, los resultados de ejecucion de estas ultimas, correspondientes a la comparacion de del mes 06 del 2025 y del 2024, estan documentadas en `RESULTADOS.md`.
6. **Generación del dashboard (`Shaper`):** Shaper genera el dashboard a partir de los datos y modelos analíticos materializados. Dagster orquesta este paso al final del flujo, después de la construcción de los modelos dbt, y permite monitorear su ejecución desde Dagster UI.

## Decisiones Técnicas y de Negocio

### Manejo de Evolución de Esquema (`cbd_congestion_fee` y columnas nuevas)

**Tratamiento de `cbd_congestion_fee` en 2024:** Este cargo entró en vigor en enero de 2025, por lo que no existe en los archivos de 2024. En los datos de 2024 se inyecta explícitamente casteado a `DOUBLE` con valor `NULL` (no `0.0`), evitando distorsionar métricas históricas o confundir ausencia de impuesto con viajes exentos.

**Columnas nuevas no contempladas en el contrato:**  Si el validador detecta una columna no contemplada en el contrato, registra una advertencia (WARNING) indicando nombre y tipo, y la excluye de la proyección hacia `staging` hasta que el contrato YAML sea actualizado.

### Tipado de Datos en el Contrato (`contracts/yellow_schema.yaml`)

**Identificadores y códigos categóricos (`BIGINT` / `INTEGER`):** `vendor_id`, `ratecode_id`, `passenger_count`, `pu_location_id`, `do_location_id` y `payment_type` representan códigos enteros discretos según el diccionario oficial de la TLC y se castean explícitamente a tipos enteros.

**Métricas financieras y de distancia (`DOUBLE`):** `trip_distance`, `fare_amount`, `tip_amount`, `total_amount` y recargos se definen como `DOUBLE`, aplicando protección frente a divisiones por cero o tarifas no positivas al calcular `velocidad_promedio_mph` y `porcentaje_propina_tarifa`.

**Banderas (`VARCHAR`) y Fechas (`TIMESTAMP` / `DATE`):** `store_and_fwd_flag` se define como `VARCHAR` por compatibilidad nativa con Parquet, las marcas de tiempo se mantienen como `TIMESTAMP` y `fecha_subida` se deriva como `DATE`.

### Reprocesamiento Selectivo e Idempotente por Partición

Al ejecutar `src/curate_partitioned.py --mes AAAA-MM`:

- Solo se eliminan (si ya existen) las carpetas `year=(AAAA-1)/month=M` y `year=AAAA/month=M` dentro de `data/curated_hive/`, dejando intactas las particiones de otros meses.
- Si el mes es nuevo y sus carpetas aún no existen, el script omite el borrado sin error y crea automáticamente las particiones correspondientes mediante `COPY ... PARTITION_BY (year, month), OVERWRITE_OR_IGNORE`.
- Para que el mes nuevo no quede vacío, debe existir previamente en `data/curated/curated_yellow_trips.parquet` junto con su par interanual.

#### Prueba de Conteos Antes y Después (`data/curated_hive`)

Partición | Filas Antes del Reproceso | Filas Después del Reproceso | Estado

`year=2024/month=6` | *3440443* | *3440443* | Reemplazada (par interanual)

`year=2025/month=6` | *4050910* | *4050910* | Reprocesada sin duplicados

`year=2025/month=7` | *3648036* | *3648036* | Intacta

## Calidad de Datos y Cuarentena

Se implementaron **8 reglas de calidad**. La reconciliación final aborta el pipeline si `filas_leidas != filas_aceptadas + filas_cuarentena`.

ID Regla | Descripción | Severidad | Umbral / Condición Justificada

`DQ_01` | Fecha de subida fuera del mes del archivo | `Rechazo` | `DATE_TRUNC('month', tpep_pickup_datetime)` distinto al mes procesado. Evita contaminación entre períodos.

`DQ_02` | Bajada anterior o igual a la subida | `Rechazo` | `tpep_dropoff_datetime <= tpep_pickup_datetime`. Físicamente imposible; invalida la duración.

`DQ_03` | Distancia inválida o extrema | `Rechazo` | `trip_distance <= 0` o `trip_distance > 200` millas. Descarta viajes sin desplazamiento o errores de taxímetro fuera del área metropolitana de NYC.

`DQ_04` | Importe total negativo | `Rechazo` | `total_amount < 0`. Excluye contracargos o ajustes contables negativos.

`DQ_05` | Cantidad de pasajeros nula o cero | `Advertencia` | `passenger_count IS NULL OR passenger_count <= 0`. Se marca en `flags` sin descartar el viaje ni alterar métricas financieras.

`DQ_06` | Zona de origen o destino inexistente | `Rechazo` | `pu_location_id` o `do_location_id` ausente en `taxi_zone_lookup.csv`. Asegura integridad referencial con `dim_zone`.

`DQ_07` | Filas duplicadas exactas | `Rechazo` | Registros idénticos en todas las columnas de negocio; se conserva la primera ocurrencia.

`DQ_08` | Velocidad promedio irreal | `Rechazo` | Velocidad calculada `> 80 mph`. Detecta inconsistencias entre distancia y duración del viaje.

Adicionalmente, sobre los modelos `intermediate` en `dbt` se configuran pruebas en `schema.yml` (`unique`, `not_null`, `relationships` hacia `dim_zone` y `dim_date`) y pruebas singulares en `tests/` para verificar la unicidad del grano de `agg_zone_hour` y su reconciliación con `fact_trips`.

## Modelado Dimensional (Esquema Estrella)

Los modelos del esquema estrella y la tabla agregada se organizan como modelos `marts` en `dbt` a partir de `data/curated_hive/**/*.parquet`. Según las necesidades de memoria y consulta, la carpeta `intermediate` puede configurarse como `view` o `table` en `dbt_project.yml` (y usar `{{ config(materialized='ephemeral') }}` en modelos puntuales que convenga inyectar como CTE).

Una vez materializados, estos modelos alimentan el dashboard generado con Shaper. Dagster orquesta la generación como etapa final del pipeline.

Tabla / Modelo | Granularidad (qué representa una fila) | Clave / Agrupación principal

**`fact_trips`** | **Un viaje individual** limpio y enriquecido de taxi amarillo (con métricas del viaje y claves hacia dimensiones). | `trip_sk` (claves: `pu_location_id`, `do_location_id`, `fecha_subida`)

**`dim_zone`** | **Una zona geográfica** oficial de TLC (`borough`, `zona`, `service_zone`). | `location_id`

**`dim_date`** | **Un día calendario** presente en los viajes (`year`, `month`, `dia_mes`, `dia_semana_num`, `dia_semana_nombre`, `es_fin_de_semana`). | `fecha_subida`

**`agg_zone_hour`** | **Una combinación única de zona de origen, fecha y hora**, con `total_viajes`, `ingreso_total` y `duracion_media_minutos`. | `(pu_location_id, fecha_subida, hora_subida)`

## Rendimiento y Recursos

**Entorno:** VM Debian — 8 GB RAM.

**Control de memoria:** Límites explícitos de memoria en contenedores (`mem_limit`), `dlt` con un worker y buffers acotados, `curate_partitioned.py` con `SET memory_limit = '3GB'` y `SET threads = 1`, y `dbt` con `--threads 1`.

**Concurrencia DuckDB:** Separación de datos/métricas y ejecución secuencial para evitar conflictos de escritura concurrente.

**Tiempo total de ejecución (`make all`):** *(Completar tras ejecutar la corrida de los dos meses en tu VM)*.

**Pico máximo de consumo de RAM:** El pido de RAM detectado durante la corrida es de *3.8 GB* a *4 GB*, dejando un margen para el sistema operativo y posibles subprocesos que se podrian añadir a futuro.

## Limitaciones Conocidas

1. **Propinas en efectivo no registradas:** Según el diccionario oficial de la TLC, `tip_amount` refleja únicamente propinas abonadas con tarjeta de crédito (las propinas en efectivo figuran como `0.0`).
2. **Concurrencia de escritura en DuckDB:** Al ser un motor embebido de un solo escritor, se evitan escrituras concurrentes sobre el mismo archivo `.duckdb`.
3. **Procesamiento batch mensual:** Diseñado para cargas mensuales históricas y no para *streaming* en tiempo real.

## Declaración de Uso de IA

Se declara el uso de inteligencia artificial (**Gemini y Copilot**) como herramienta de apoyo durante el desarrollo para:

- Diseño y revisión de arquitectura optimizada para bajo consumo de memoria (`dlt`, `dbt`, `DuckDB`, `Dagster`).
- Redacción inicial de plantillas, estructuras de validación y documentación técnica.
- Verificacion y resolucion de conflictos entre dependencias.

Todo el código, reglas de calidad, pruebas y consultas SQL fueron revisados, adaptados y validados por los autores del proyecto.
