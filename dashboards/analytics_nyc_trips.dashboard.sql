-- shaperid:ritxxl0ibnl0x2nep4hbxova
-- shapersync:2026-11-25T06:16:38Z

-- ============================================================================
-- A) Top 10 zonas de origen con más viajes y variación respecto al anterior
-- ============================================================================
SELECT 'a) Top 10 Zonas de Origen (Actual vs Anterior)'::SECTION;

-- Gráfico de barras comparativo (Actual vs Anterior)
WITH viajes AS (
    SELECT
        dz.zona,
        f.es_mes_solicitado,
        COUNT(*) AS total_viajes
    FROM dbt_analytics.fact_trips f
    JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
    GROUP BY dz.zona, f.es_mes_solicitado
),
comparacion AS (
    SELECT
        zona,
        MAX(CASE WHEN es_mes_solicitado = TRUE THEN total_viajes END) AS viajes_actual,
        MAX(CASE WHEN es_mes_solicitado = FALSE THEN total_viajes END) AS viajes_anterior
    FROM viajes
    GROUP BY zona
)
SELECT
    zona::XAXIS AS "Zona",
    viajes_actual::BARCHART AS "Viajes Actual",
    viajes_anterior::BARCHART AS "Viajes Anterior"
FROM comparacion
ORDER BY viajes_actual DESC
LIMIT 10;

-- Tabla complementaria con el porcentaje de variación detallado
WITH viajes AS (
    SELECT
        dz.zona,
        f.es_mes_solicitado,
        COUNT(*) AS total_viajes
    FROM dbt_analytics.fact_trips f
    JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
    GROUP BY dz.zona, f.es_mes_solicitado
),
comparacion AS (
    SELECT
        zona,
        MAX(CASE WHEN es_mes_solicitado = TRUE THEN total_viajes END) AS viajes_actual,
        MAX(CASE WHEN es_mes_solicitado = FALSE THEN total_viajes END) AS viajes_anterior
    FROM viajes
    GROUP BY zona
)
SELECT
    zona AS "Zona",
    viajes_actual AS "Viajes Actual",
    viajes_anterior AS "Viajes Anterior",
    ROUND(100.0 * (viajes_actual - viajes_anterior) / NULLIF(viajes_anterior, 0), 2) AS "Variación (%)"
FROM comparacion
ORDER BY viajes_actual DESC
LIMIT 10;


-- ============================================================================
-- B) Hora del día con mayor ingreso promedio por viaje
-- ============================================================================
SELECT 'b) Ingreso Promedio por Hora del Día'::SECTION;

-- KPI destacado
SELECT
    'Hora Pico de Ingreso (5:00 AM)'::LABEL,
    ROUND(AVG(total_amount), 2)::GAUGE
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE
  AND hora_subida = 5;

-- Gráfico de línea para ver la tendencia a lo largo de las horas
SELECT
    hora_subida::XAXIS AS "Hora del Día",
    ROUND(AVG(total_amount), 2)::LINECHART AS "Ingreso Promedio (USD)"
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY hora_subida
ORDER BY hora_subida ASC;

-- Tabla detallada de ingresos por hora
SELECT
    hora_subida AS "Hora del Día",
    ROUND(AVG(total_amount), 2) AS "Ingreso Promedio (USD)"
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY hora_subida
ORDER BY hora_subida ASC;


-- ============================================================================
-- C) Porcentaje de viajes con CBD Congestion Fee y zonas con mayor proporción
-- ============================================================================
SELECT 'c) Impacto del CBD Congestion Fee'::SECTION;

-- c.1 KPI Porcentaje global
SELECT
    'Viajes con CBD Congestion Fee (%)'::LABEL,
    ROUND(
        100.0 * SUM(CASE WHEN cbd_congestion_fee > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    )::GAUGE
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE;

-- c.2 Gráfico de barras para el Top 5 zonas con mayor proporción de CBD Fee
SELECT
    dz.zona::XAXIS AS "Zona",
    ROUND(
        100.0 * SUM(CASE WHEN f.cbd_congestion_fee > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    )::BARCHART AS "Proporción CBD (%)"
FROM dbt_analytics.fact_trips f
JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
WHERE f.es_mes_solicitado = TRUE
GROUP BY dz.zona
HAVING COUNT(*) > 100
ORDER BY "Proporción CBD (%)" DESC
LIMIT 5;

-- Tabla detallada del Top 5 zonas CBD
SELECT
    dz.zona AS "Zona",
    COUNT(*) AS "Viajes Totales",
    SUM(CASE WHEN f.cbd_congestion_fee > 0 THEN 1 ELSE 0 END) AS "Viajes con CBD Fee",
    ROUND(
        100.0 * SUM(CASE WHEN f.cbd_congestion_fee > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS "Proporción CBD (%)"
FROM dbt_analytics.fact_trips f
JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
WHERE f.es_mes_solicitado = TRUE
GROUP BY dz.zona
HAVING COUNT(*) > 100
ORDER BY "Proporción CBD (%)" DESC
LIMIT 5;


-- ============================================================================
-- D) Propina promedio como porcentaje de la tarifa por tipo de pago
-- ============================================================================
SELECT 'd) Propina Promedio (%) por Tipo de Pago'::SECTION;

-- Gráfico de barras por tipo de pago
SELECT
    CAST(payment_type AS VARCHAR)::XAXIS AS "Tipo de Pago",
    ROUND(AVG(porcentaje_propina_tarifa), 2)::BARCHART AS "Propina Promedio (%)"
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY payment_type
ORDER BY payment_type;

-- Tabla detallada por tipo de pago
SELECT
    CAST(payment_type AS VARCHAR) AS "Tipo de Pago",
    ROUND(AVG(porcentaje_propina_tarifa), 2) AS "Propina Promedio (%)"
FROM dbt_analytics.fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY payment_type
ORDER BY payment_type;


-- ============================================================================
-- E) Viajes y tarifa media asociados a los aeropuertos JFK y LaGuardia
-- ============================================================================
SELECT 'e) Comparativa Aeropuertos: JFK vs LaGuardia'::SECTION;

-- Gráfico de barras de cantidad de viajes por aeropuerto
SELECT
    dz.zona::XAXIS AS "Aeropuerto",
    COUNT(*)::BARCHART AS "Cantidad de Viajes"
FROM dbt_analytics.fact_trips f
JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
WHERE LOWER(dz.zona) LIKE '%jfk%'
   OR LOWER(dz.zona) LIKE '%laguardia%'
GROUP BY dz.zona
ORDER BY "Cantidad de Viajes" DESC;

-- Tabla detallada de aeropuertos
SELECT
    dz.zona AS "Aeropuerto",
    COUNT(*) AS "Cantidad de Viajes",
    ROUND(AVG(f.fare_amount), 2) AS "Tarifa Media (USD)"
FROM dbt_analytics.fact_trips f
JOIN dbt_analytics.dim_zone dz ON f.pu_location_id = dz.location_id
WHERE LOWER(dz.zona) LIKE '%jfk%'
   OR LOWER(dz.zona) LIKE '%laguardia%'
GROUP BY dz.zona
ORDER BY "Cantidad de Viajes" DESC;


-- ============================================================================
-- F) Variación de viajes totales y tarifa media entre ambos meses
-- ============================================================================
SELECT 'f) Resumen General: Actual vs 2024'::SECTION;

-- KPI 1: Variación porcentual de viajes
WITH resumen AS (
    SELECT
        es_mes_solicitado,
        COUNT(*) AS total_viajes
    FROM dbt_analytics.fact_trips
    GROUP BY es_mes_solicitado
)
SELECT
    'Variación Total de Viajes (%)'::LABEL,
    ROUND(
        100.0 * (MAX(CASE WHEN es_mes_solicitado THEN total_viajes END) - MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END))
        / MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END),
        2
    )::GAUGE
FROM resumen;

-- KPI 2: Variación porcentual de tarifa media
WITH resumen AS (
    SELECT
        es_mes_solicitado,
        AVG(fare_amount) AS tarifa_media
    FROM dbt_analytics.fact_trips
    GROUP BY es_mes_solicitado
)
SELECT
    'Variación Tarifa Media (%)'::LABEL,
    ROUND(
        100.0 * (MAX(CASE WHEN es_mes_solicitado THEN tarifa_media END) - MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END))
        / MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END),
        2
    )::GAUGE
FROM resumen;

-- Tabla resumen general comparativa
WITH resumen AS (
    SELECT
        es_mes_solicitado,
        COUNT(*) AS total_viajes,
        AVG(fare_amount) AS tarifa_media
    FROM dbt_analytics.fact_trips
    GROUP BY es_mes_solicitado
)
SELECT
    MAX(CASE WHEN es_mes_solicitado = TRUE THEN total_viajes END) AS "Viajes Actual",
    MAX(CASE WHEN es_mes_solicitado = FALSE THEN total_viajes END) AS "Viajes Anterior",
    ROUND(
        100.0 * (MAX(CASE WHEN es_mes_solicitado THEN total_viajes END) - MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END))
        / MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END),
        2
    ) AS "Variación Viajes (%)",
    ROUND(
        100.0 * (MAX(CASE WHEN es_mes_solicitado THEN tarifa_media END) - MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END))
        / MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END),
        2
    ) AS "Variación Tarifa (%)"
FROM resumen;