# FID2026-NYC-Taxis
Proyecto para ingesta, validacion, limpieza y modelado de los viajes de taxis de Nueva York, de dos meses asignados, buscando responder preguntas de negocio sobre el modelo. 

## PREREQUISITOS DEL SISTEMA
Antes de ejecutar el pipeline, asegurate de tener instaladas las siguientes herramientas: 

- make 
- git
- python
- python3-venv 
- python3-pip
- 

### DECISIONES PARA EL ESQUEMA 
*   **cbd_congestion_fee en 2024:** Decidimos que la columna tome el valor `NULL` en lugar de `0` (en el caso de no existir) porque un `0` distorsionaria los promedios y agregaciones de los marts (indicaria falsamente que el viaje tuvo costo cero). Con `NULL`, DuckDB excluye correctamente esas filas de los calculos de promedio. Además, se aplicó `COALESCE` para unificar variaciones de mayúsculas/minúsculas en `airport_fee`.
*   **Nuevas columnas:** Si TLC agrega una columna nueva no declarada en el contrato, `src/esquema.py` dara una advertencia pero no fallara. El modelo de dbt utiliza `union_by_name`, por lo que la columna nueva sera ignorada de forma segura hasta que el contrato YAML sea actualizado manualmente.
*   **Contrato de Esquema**: La estructura esperada se define en `contracts/yellow_schema.yaml`. Antes de transformar, `src/esquema.py` valida que los Parquet crudos cumplan este contrato, reportando columnas faltantes o tipos distintos.
