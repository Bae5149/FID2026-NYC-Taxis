{{ config(
    materialized='external',
    location='data/quarantine/quarantine_yellow_trips.parquet',
    format='parquet'
) }}

with rechazos as (
    select *
    from {{ ref('int_yellow_trips_dq') }}
    where es_rechazo_dq = true
)

select
    -- Trazabilidad y particion temporal
    periodo_mes,
    es_mes_solicitado,
    source_file,

    -- Campos del viaje normalizados a snake_case
    vendor_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    ratecode_id,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,

    -- Metricas derivadas y flags de calidad
    pickup_mes,
    duracion_segundos,
    velocidad_mph,
    num_ocurrencia,
    es_rechazo_dq,
    es_advertencia_dq_05,
    dq_01_pickup_fuera_de_mes,
    dq_02_duracion_invalida,
    dq_03_distancia_invalida,
    dq_04_monto_total_invalido,
    dq_05_pasajeros_invalido,
    dq_06_zona_invalida,
    dq_07_duplicado_exacto,
    dq_08_velocidad_excesiva,

    -- Motivos legibles por regla
    motivo_dq_01,
    motivo_dq_02,
    motivo_dq_03,
    motivo_dq_04,
    motivo_dq_05,
    motivo_dq_06,
    motivo_dq_07,
    motivo_dq_08
from rechazos