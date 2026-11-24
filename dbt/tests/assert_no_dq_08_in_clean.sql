{% set max_velocidad_mph = var('max_velocidad_mph', 80.0) %}

select
    periodo_mes,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    trip_distance,
    cast(trip_distance as double)
        / (cast(epoch(tpep_dropoff_datetime - tpep_pickup_datetime) as double) / 3600.0) as velocidad_mph
from {{ ref('curated_yellow_trips') }}
where
    tpep_pickup_datetime is not null
    and tpep_dropoff_datetime is not null
    and epoch(tpep_dropoff_datetime - tpep_pickup_datetime) > 0
    and trip_distance is not null
    and (
        cast(trip_distance as double)
            / (cast(epoch(tpep_dropoff_datetime - tpep_pickup_datetime) as double) / 3600.0)
    ) > {{ max_velocidad_mph }}