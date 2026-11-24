{{ config(
    materialized='external',
    location='data/curated/curated_yellow_trips.parquet',
    format='parquet'
) }}

with limpios as (
    select *
    from {{ ref('int_yellow_trips_dq') }}
    where es_rechazo_dq = false
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

    -- Trazabilidad de advertencia DQ_05
    es_advertencia_dq_05,
    motivo_dq_05
from limpios