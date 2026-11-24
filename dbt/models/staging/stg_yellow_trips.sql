{% set mes_actual = var('mes', '2025-03') %}
{% set partes = mes_actual.split('-') %}
{% set anio_actual = partes[0] | int %}
{% set mes_num = partes[1] %}
{% set mes_anterior = (anio_actual - 1) ~ '-' ~ mes_num %}

{% set patron_actual = 'data/raw/yellow/year=' ~ anio_actual ~ '/month=' ~ mes_num ~ '/*.parquet' %}
{% set patron_anterior = 'data/raw/yellow/year=' ~ (anio_actual - 1) ~ '/month=' ~ mes_num ~ '/*.parquet' %}

with raw_actual as (
    select
        *,
        '{{ mes_actual }}' as periodo_mes,
        true as es_mes_solicitado
    from read_parquet(
        '{{ patron_actual }}',
        union_by_name = true,
        filename = true
    )
),

raw_anterior as (
    select
        *,
        '{{ mes_anterior }}' as periodo_mes,
        false as es_mes_solicitado
    from read_parquet(
        '{{ patron_anterior }}',
        union_by_name = true,
        filename = true
    )
),

unificado as (
    select * from raw_actual
    union all by name
    select * from raw_anterior
)

select
    cast(periodo_mes as varchar) as periodo_mes,
    cast(es_mes_solicitado as boolean) as es_mes_solicitado,
    cast(filename as varchar) as source_file,
    cast(VendorID as integer) as vendor_id,
    cast(tpep_pickup_datetime as timestamp) as tpep_pickup_datetime,
    cast(tpep_dropoff_datetime as timestamp) as tpep_dropoff_datetime,
    cast(passenger_count as bigint) as passenger_count,
    cast(trip_distance as double) as trip_distance,
    cast(RatecodeID as bigint) as ratecode_id,
    cast(store_and_fwd_flag as varchar) as store_and_fwd_flag,
    cast(PULocationID as integer) as pu_location_id,
    cast(DOLocationID as integer) as do_location_id,
    cast(payment_type as bigint) as payment_type,
    cast(fare_amount as double) as fare_amount,
    cast(extra as double) as extra,
    cast(mta_tax as double) as mta_tax,
    cast(tip_amount as double) as tip_amount,
    cast(tolls_amount as double) as tolls_amount,
    cast(improvement_surcharge as double) as improvement_surcharge,
    cast(total_amount as double) as total_amount,
    cast(congestion_surcharge as double) as congestion_surcharge,
    cast(coalesce(Airport_fee, airport_fee) as double) as airport_fee,
    cast(cbd_congestion_fee as double) as cbd_congestion_fee
from unificado