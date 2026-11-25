WITH resumen AS (
    SELECT
        es_mes_solicitado,
        COUNT(*) AS total_viajes,
        AVG(fare_amount) AS tarifa_media
    FROM fact_trips
    GROUP BY es_mes_solicitado
)

SELECT
    MAX(
        CASE
            WHEN es_mes_solicitado = TRUE
            THEN total_viajes
        END
    ) AS viajes_actual,
    MAX(
        CASE
            WHEN es_mes_solicitado = FALSE
            THEN total_viajes
        END
    ) AS viajes_2024,
    ROUND(
        100.0 *
        (
            MAX(CASE WHEN es_mes_solicitado THEN total_viajes END)
            -
            MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END)
        )
        /
        MAX(CASE WHEN NOT es_mes_solicitado THEN total_viajes END),
        2
    ) AS variacion_viajes_pct,
    ROUND(
        100.0 *
        (
            MAX(CASE WHEN es_mes_solicitado THEN tarifa_media END)
            -
            MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END)
        )
        /
        MAX(CASE WHEN NOT es_mes_solicitado THEN tarifa_media END),
        2
    ) AS variacion_tarifa_pct
FROM resumen;

-- @interpretacion: La cantidad de viajes aumentó un 16,13% respecto al mismo mes de 2024, mientras que la tarifa media disminuyó un 2,06%. Esto sugiere un crecimiento de la demanda impulsado por un mayor número de viajes, aunque con trayectos ligeramente más cortos o de menor importe medio.