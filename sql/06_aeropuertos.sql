SELECT
    dz.zona,
    COUNT(*) AS cantidad_viajes,
    ROUND(
        AVG(f.fare_amount),
        2
    ) AS tarifa_media
FROM fact_trips f
JOIN dim_zone dz
    ON f.pu_location_id = dz.location_id
WHERE
    LOWER(dz.zona) LIKE '%jfk%'
    OR LOWER(dz.zona) LIKE '%laguardia%'
GROUP BY dz.zona
ORDER BY cantidad_viajes DESC;

-- @interpretacion: JFK Airport registró 620.227 viajes con una tarifa media de 64,06 dólares, mientras que LaGuardia registró 431.320 viajes con 44,09 dólares. JFK presenta mayor volumen y tarifa, posiblemente por su mayor distancia a los centros urbanos y su perfil de aeropuerto internacional.