SELECT
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN cbd_congestion_fee > 0
                THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS porcentaje_cbd
FROM fact_trips
WHERE es_mes_solicitado = TRUE;

-- @interpretacion: El 74% de los viajes del mes analizado estuvieron sujetos al CBD Congestion Fee, reflejando una elevada concentración de la demanda en el distrito central de negocios de Manhattan.