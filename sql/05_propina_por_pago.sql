SELECT
    payment_type,
    ROUND(
        AVG(porcentaje_propina_tarifa),
        2
    ) AS propina_pct_promedio
FROM fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY payment_type
ORDER BY payment_type;

-- @interpretacion: El tipo de pago 1 (tarjeta) presenta una propina promedio del 25,69%. El tipo de pago 2 (efectivo) registra un valor cercano a cero, lo cual no es interpretable como una ausencia real de propina, sino que refleja que las propinas en efectivo no quedan registradas en el sistema electrónico del taxi.