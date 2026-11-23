select
    periodo_mes,
    source_file,
    tpep_pickup_datetime,
    tpep_dropoff_datetime
from {{ ref('clean_yellow_trips') }}
where
    coalesce(es_rechazo_dq, false) = true
    or (
        coalesce(es_advertencia_dq_05, false) = false
        and motivo_dq_05 is not null
    )