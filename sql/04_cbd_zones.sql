SELECT
    dz.zona,
    COUNT(*) AS viajes_totales,
    SUM(
        CASE
            WHEN f.cbd_congestion_fee > 0
            THEN 1
            ELSE 0
        END
    ) AS viajes_cbd,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN f.cbd_congestion_fee > 0
                THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS proporcion_pct
FROM fact_trips f
JOIN dim_zone dz
    ON f.pu_location_id = dz.location_id
WHERE f.es_mes_solicitado = TRUE
GROUP BY dz.zona
HAVING COUNT(*) > 100
ORDER BY proporcion_pct DESC
LIMIT 5;

-- @interpretacion: Las zonas con mayor proporción de viajes sujetos al CBD Fee son SoHo, Greenwich Village South, West Village, Greenwich Village North y Little Italy/NoLiTa. Todas presentan porcentajes cercanos al 100%, coherente con su ubicación en el sur de Manhattan.