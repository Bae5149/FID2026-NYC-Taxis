select
    periodo_mes,
    tpep_pickup_datetime
from {{ ref('clean_yellow_trips') }}
where
    tpep_pickup_datetime is null
    or strftime(tpep_pickup_datetime, '%Y-%m') is distinct from periodo_mes