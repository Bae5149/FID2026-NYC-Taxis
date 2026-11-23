select
    periodo_mes,
    tpep_pickup_datetime,
    tpep_dropoff_datetime
from {{ ref('clean_yellow_trips') }}
where
    tpep_pickup_datetime is null
    or tpep_dropoff_datetime is null
    or tpep_dropoff_datetime <= tpep_pickup_datetime