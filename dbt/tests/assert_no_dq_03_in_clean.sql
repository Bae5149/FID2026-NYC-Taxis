{% set max_distancia_millas = var('max_distancia_millas', 200.0) %}

select
    periodo_mes,
    trip_distance
from {{ ref('clean_yellow_trips') }}
where
    trip_distance is null
    or trip_distance <= 0
    or trip_distance > {{ max_distancia_millas }}