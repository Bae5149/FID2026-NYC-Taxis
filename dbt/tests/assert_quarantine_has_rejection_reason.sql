select
    periodo_mes,
    source_file,
    tpep_pickup_datetime,
    tpep_dropoff_datetime
from {{ ref('quarantine_yellow_trips') }}
where
    coalesce(es_rechazo_dq, false) is not true
    or not (
        coalesce(dq_01_pickup_fuera_de_mes, false)
        or coalesce(dq_02_duracion_invalida, false)
        or coalesce(dq_03_distancia_invalida, false)
        or coalesce(dq_04_monto_total_invalido, false)
        or coalesce(dq_06_zona_invalida, false)
        or coalesce(dq_07_duplicado_exacto, false)
        or coalesce(dq_08_velocidad_excesiva, false)
    )