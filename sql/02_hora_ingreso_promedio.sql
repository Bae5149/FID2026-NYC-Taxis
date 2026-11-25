SELECT
    hora_subida,
    ROUND(
        AVG(total_amount),
        2
    ) AS ingreso_promedio
FROM fact_trips
WHERE es_mes_solicitado = TRUE
GROUP BY hora_subida
ORDER BY ingreso_promedio DESC
LIMIT 1;

-- @interpretacion: La hora con mayor ingreso promedio por viaje fue las 05:00, con un valor medio de 33,05 dólares por trayecto. Esto puede explicarse por una mayor proporción de viajes largos durante la madrugada y primeras horas de la mañana, incluyendo desplazamientos hacia aeropuertos.