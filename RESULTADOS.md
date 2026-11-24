# RESULTADOS – Parte 5

## a) Top 10 zonas de origen con más viajes y variación respecto al mismo mes de 2024

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

LIMIT 10
```

### Resultado

```text
[('Midtown Center', 343128, 318294, 7.8), ('Upper East Side South', 334898, 308728, 8.48), ('JFK Airport', 318751, 301476, 5.73), ('Upper East Side North', 295300, 283518, 4.16), ('Times Sq/Theatre District', 252156, 231930, 8.72), ('Penn Station/Madison Sq West', 249826, 220504, 13.3), ('Midtown East', 246330, 238710, 3.19), ('Lincoln Square East', 222246, 216915, 2.46), ('Union Sq', 216099, 188508, 14.64), ('Murray Hill', 213931, 201914, 5.95)]
```
| Zona | Viajes mes actual | Viajes 2024 | Variación (%) |
|--------|----------:|----------:|----------:|
| Midtown Center | 343128 | 318294 | 7.80 |
| Upper East Side South | 334898 | 308728 | 8.48 |
| JFK Airport | 318751 | 301476 | 5.73 |
| Upper East Side North | 295300 | 283518 | 4.16 |
| Times Sq/Theatre District | 252156 | 231930 | 8.72 |
| Penn Station/Madison Sq West | 249826 | 220504 | 13.30 |
| Midtown East | 246330 | 238710 | 3.19 |
| Lincoln Square East | 222246 | 216915 | 2.46 |
| Union Sq | 216099 | 188508 | 14.64 |
| Murray Hill | 213931 | 201914 | 5.95 |

### Análisis

Las zonas con mayor volumen de viajes se concentran en áreas de alta actividad comercial, turística y de transporte de Manhattan. Destacan Midtown Center, Upper East Side South y JFK Airport como los principales puntos de origen. Todas las zonas del Top 10 presentan crecimiento respecto al mismo mes de 2024, lo que indica una mayor demanda general del servicio. Los mayores incrementos porcentuales se observan en Union Sq (+14,64%) y Penn Station/Madison Sq West (+13,30%), áreas con gran flujo de pasajeros y conexiones de transporte.

---

## b) Hora del día con mayor ingreso promedio por viaje

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

LIMIT 1
```

### Resultado

```text
[(5, 33.05)]
```
| Hora del día | Ingreso promedio por viaje (USD) |
|-------------:|---------------------------------:|
| 5 | 33.05 |

### Análisis

La hora con mayor ingreso promedio por viaje fue las 05:00, con un valor medio de 33,05 dólares por trayecto. Esto puede explicarse por una mayor proporción de viajes largos durante la madrugada y primeras horas de la mañana, incluyendo desplazamientos hacia aeropuertos o trayectos con menor congestión que permiten recorrer mayores distancias.

---

## c) Porcentaje de viajes con CBD Congestion Fee y zonas con mayor proporción

### c.1 Porcentaje global

#### Consulta SQL

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

WHERE es_mes_solicitado = TRUE
```

#### Resultado

```text
[(74.0,)]
```
| Métrica | Valor |
|----------|------:|
| Porcentaje de viajes con CBD Congestion Fee | 74.00 % |

#### Análisis

El 74% de los viajes del mes analizado estuvieron sujetos al CBD Congestion Fee. Este porcentaje muestra que una gran parte de la actividad de taxis se desarrolla dentro o con destino a las zonas afectadas por el recargo de congestión implementado en Manhattan, reflejando una elevada concentración de demanda en el distrito central de negocios.

---

### c.2 Top 5 zonas con mayor proporción de viajes con CBD Congestion Fee

#### Consulta SQL

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

ORDER BY proporcion*pct DESC

LIMIT 5
```

#### Resultado

```text
[('SoHo', 68405, 68274, 99.81), ('Greenwich Village South', 120824, 120555, 99.78), ('West Village', 184064, 183657, 99.78), ('Greenwich Village North', 112888, 112628, 99.77), ('Little Italy/NoLiTa', 91215, 90987, 99.75)]
```

| Zona | Viajes totales | Viajes con CBD Fee | Proporción (%) |
|--------|----------:|----------:|----------:|
| SoHo | 68405 | 68274 | 99.81 |
| Greenwich Village South | 120824 | 120555 | 99.78 |
| West Village | 184064 | 183657 | 99.78 |
| Greenwich Village North | 112888 | 112628 | 99.77 |
| Little Italy/NoLiTa | 91215 | 90987 | 99.75 |

#### Análisis

Las zonas con mayor proporción de viajes sujetos al CBD Congestion Fee son SoHo, Greenwich Village South, West Village, Greenwich Village North y Little Italy/NoLiTa. Todas presentan porcentajes cercanos al 100%, lo que resulta coherente con su ubicación en el sur de Manhattan, dentro o muy próximas al área de aplicación del recargo por congestión. Esto confirma que el CBD Fee afecta principalmente a viajes realizados en las zonas más densamente urbanizadas y con mayor actividad económica de la ciudad.

---

## d) Propina promedio como porcentaje de la tarifa por tipo de pago

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

ORDER BY payment_type
```

### Resultado

```text
[(0, 1.7), (1, 25.69), (2, 0.0), (3, 0.04), (4, 0.04), (5, 0.0)]
```
| Payment Type | Propina promedio (% de la tarifa) |
|-------------:|-----------------------------------:|
| 0 | 1.70 |
| 1 | 25.69 |
| 2 | 0.00 |
| 3 | 0.04 |
| 4 | 0.04 |
| 5 | 0.00 |

### Análisis

Se observan diferencias significativas entre los distintos tipos de pago. El tipo de pago 1 presenta una propina promedio equivalente al 25,69% de la tarifa, mientras que el tipo 2 registra un valor cercano a cero. Los tipos 3 y 4 muestran porcentajes prácticamente nulos.

El resultado correspondiente al tipo de pago 2 debe interpretarse con cautela. Según la codificación habitual de los datos TLC, este valor corresponde a pagos en efectivo. Las propinas abonadas en efectivo no siempre quedan registradas en el sistema electrónico del taxi, por lo que el porcentaje calculado no refleja necesariamente la propina real entregada por el pasajero y no resulta directamente comparable con los pagos con tarjeta.

---

## e) Viajes y tarifa media asociados a los aeropuertos JFK y LaGuardia

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

ORDER BY cantidad_viajes DESC
```

### Resultado

```text
[('JFK Airport', 620227, 64.06), ('LaGuardia Airport', 431320, 44.09)]
```

| Aeropuerto | Cantidad de viajes | Tarifa media (USD) |
|------------|------------------:|-------------------:|
| JFK Airport | 620227 | 64.06 |
| LaGuardia Airport | 431320 | 44.09 |

### Análisis

JFK Airport registró 620.227 viajes con una tarifa media de 64,06 dólares, mientras que LaGuardia Airport registró 431.320 viajes con una tarifa media de 44,09 dólares. JFK presenta tanto un mayor volumen de viajes como un importe medio significativamente superior.

Una posible explicación es que JFK se encuentra más alejado de los principales centros urbanos de Manhattan y Brooklyn, lo que genera trayectos más largos y, por tanto, tarifas más elevadas. Además, es uno de los principales aeropuertos internacionales de la ciudad, lo que contribuye a mantener un flujo constante de pasajeros.

---

## f) Variación de viajes totales y tarifa media entre ambos meses

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

    FROM resumen
```

### Resultado

```text
[(8006116, 6893944, 16.13, -2.06)]
```

| Métrica | Valor |
|----------|----------:|
| Viajes mes actual | 8006116 |
| Viajes mismo mes de 2024 | 6893944 |
| Variación de viajes (%) | 16.13 |
| Variación de tarifa media (%) | -2.06 |

### Análisis

#### Variación observada

La cantidad de viajes aumentó un 16,13% respecto al mismo mes de 2024, pasando de 6.893.944 a 8.006.116 trayectos. En contraste, la tarifa media disminuyó un 2,06%.

Este comportamiento sugiere que el crecimiento de la demanda estuvo impulsado por un mayor número de viajes, aunque con trayectos ligeramente más cortos o de menor importe medio.

#### Hipótesis de causa

Una posible explicación es la consolidación de la recuperación de la movilidad urbana y del turismo en Nueva York respecto al mismo periodo del año anterior. El incremento de viajes podría estar asociado a una mayor actividad económica y turística, mientras que la reducción de la tarifa media puede indicar una mayor proporción de desplazamientos cortos dentro de la ciudad o una redistribución de la demanda hacia trayectos menos costosos.

---

# Conclusiones generales

Los resultados evidencian un crecimiento significativo de la actividad del servicio de taxis respecto al mismo mes de 2024, especialmente en zonas de alta densidad comercial y turística de Manhattan. La mayor parte de los viajes estuvieron sujetos al CBD Congestion Fee, confirmando la concentración de la demanda en el centro de la ciudad. Los aeropuertos continúan siendo polos relevantes de generación de viajes, particularmente JFK, que presenta tanto mayor volumen como mayores tarifas medias. En conjunto, el incremento del número de viajes acompañado de una ligera reducción de la tarifa media sugiere una expansión de la movilidad urbana basada principalmente en trayectos de menor coste unitario.