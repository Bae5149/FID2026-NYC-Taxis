# Resultados de las Preguntas de Negocio

## 01 Top Zonas

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
| zona                         |   viajes_actual |   viajes_2024 |   variacion_pct |
|:-----------------------------|----------------:|--------------:|----------------:|
| JFK Airport                  |          170541 |        152068 |           12.15 |
| Upper East Side South        |          169806 |        156485 |            8.51 |
| Midtown Center               |          168094 |        159309 |            5.51 |
| Upper East Side North        |          147490 |        140804 |            4.75 |
| Midtown East                 |          122379 |        118054 |            3.66 |
| Penn Station/Madison Sq West |          121977 |        108725 |           12.19 |
| Times Sq/Theatre District    |          121466 |        113368 |            7.14 |
| Lincoln Square East          |          108998 |        105072 |            3.74 |
| LaGuardia Airport            |          108949 |        112956 |           -3.55 |
| Murray Hill                  |          108371 |        101300 |            6.98 |

**Interpretación:** Las zonas con mayor volumen de viajes se concentran en áreas de alta actividad comercial, turística y de transporte de Manhattan y aeropuertos. Destacan JFK Airport, Upper East Side South y Midtown Center. Con excepción de LaGuardia Airport (-3.55%), todas las zonas del Top 10 presentan crecimiento positivo respecto a 2024.

---

## 02 Hora Ingreso Promedio

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
|   hora_subida |   ingreso_promedio |
|--------------:|-------------------:|
|             5 |              32.56 |

**Interpretación:** La hora con mayor ingreso promedio por viaje fue las 05:00, con un valor medio de 32,56 dólares por trayecto. Esto puede explicarse por una mayor proporción de viajes largos durante la madrugada y primeras horas de la mañana, incluyendo desplazamientos hacia aeropuertos.

---

## 03 Cbd Global

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
|   porcentaje_cbd |
|-----------------:|
|            73.75 |

**Interpretación:** El 73,75% de los viajes del mes analizado estuvieron sujetos al CBD Congestion Fee, reflejando una elevada concentración de la demanda en el distrito central de negocios de Manhattan.

---

## 04 Cbd Zones

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
| zona                    |   viajes_totales |   viajes_cbd |   proporcion_pct |
|:------------------------|-----------------:|-------------:|-----------------:|
| Greenwich Village South |            56768 |        56660 |            99.81 |
| West Village            |            88064 |        87893 |            99.81 |
| SoHo                    |            33903 |        33830 |            99.78 |
| Greenwich Village North |            54712 |        54593 |            99.78 |
| Union Sq                |           106064 |       105812 |            99.76 |

**Interpretación:** Las zonas con mayor proporción de viajes sujetos al CBD Fee son Greenwich Village South, West Village, SoHo, Greenwich Village North y Union Sq. Todas presentan proporciones superiores al 99,76%, coherente con su ubicación en el sur de Manhattan.

---

## 05 Propina Por Pago

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
|   payment_type |   propina_pct_promedio |
|---------------:|-----------------------:|
|              0 |                   1.49 |
|              1 |                  25.25 |
|              2 |                   0    |
|              3 |                   0.07 |
|              4 |                   0.03 |
|              5 |                   0    |

**Interpretación:** El tipo de pago 1 (tarjeta) presenta una propina promedio del 25,25%. Los tipos 0 y 3 registran valores menores al 1,5%, mientras que los tipos 2, 4 y 5 muestran valores cercanos a cero, reflejando que las transacciones en efectivo u otros medios no electrónicos no registran propinas formales en el sistema.

---

## 06 Aeropuertos

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
| zona              |   cantidad_viajes |   tarifa_media |
|:------------------|------------------:|---------------:|
| JFK Airport       |            322609 |          64.27 |
| LaGuardia Airport |            221905 |          44.93 |

**Interpretación:** JFK Airport registró 322.609 viajes con una tarifa media de 64,27 dólares, mientras que LaGuardia Airport registró 221.905 viajes con una tarifa media de 44,93 dólares. JFK presenta mayor volumen de viajes y una tarifa superior debido a su mayor distancia respecto a los centros urbanos.

---

## 07 Variacion Mensual

### Consulta SQL
```sql
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

-- @interpretacion
```

### Respuesta
|   viajes_actual |   viajes_2024 |   variacion_viajes_pct |   variacion_tarifa_pct |
|----------------:|--------------:|-----------------------:|-----------------------:|
|     4.05093e+06 |   3.44048e+06 |                  17.74 |                   -0.8 |

**Interpretación:** La cantidad de viajes aumentó un 17,74% respecto al mismo mes de 2024 (pasando de 3,44 a 4,05 millones de viajes), mientras que la tarifa media descendió un 0,80%.

**Hipótesis causal:** El incremento de los viajes responde a una mayor actividad urbana y comercial, mientras que la leve baja en la tarifa media se explica por un mayor predominio de trayectos cortos dentro de la ciudad frente a viajes largos de mayor costo.

---
