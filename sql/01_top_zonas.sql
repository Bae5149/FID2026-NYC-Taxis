WITH viajes AS (
    SELECT
        dz.zona,
        f.es_mes_solicitado,
        COUNT(*) AS total_viajes
    FROM fact_trips f
    JOIN dim_zone dz
        ON f.pu_location_id = dz.location_id
    GROUP BY
        dz.zona,
        f.es_mes_solicitado
),

comparacion AS (
    SELECT
        zona,
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
        ) AS viajes_2024
    FROM viajes
    GROUP BY zona
)

SELECT
    zona,
    viajes_actual,
    viajes_2024,
    ROUND(
        100.0 *
        (viajes_actual - viajes_2024)
        / NULLIF(viajes_2024,0),
        2
    ) AS variacion_pct
FROM comparacion
ORDER BY viajes_actual DESC
LIMIT 10;

-- @interpretacion: Las zonas con mayor volumen de viajes se concentran en áreas de alta actividad comercial, turística y de transporte de Manhattan. Todas las zonas del Top 10 presentan crecimiento respecto al mismo mes de 2024, lo que indica una mayor demanda general del servicio.