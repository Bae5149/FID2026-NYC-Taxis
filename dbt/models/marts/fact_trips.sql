with base as (
    select *
    from read_parquet('data/curated_hive/**/*.parquet', hive_partitioning = true)
)

select
    row_number() over (
        order by tpep_pickup_datetime, tpep_dropoff_datetime, pu_location_id, do_location_id
    ) as trip_sk,
    periodo_mes,
    es_mes_solicitado,
    year,
    month,
    fecha_subida,
    hora_subida,
    pu_location_id,
    do_location_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    duracion_minutos,
    velocidad_promedio_mph,
    payment_type,
    fare_amount,
    tip_amount,
    porcentaje_propina_tarifa,
    cbd_congestion_fee,
    total_amount
from base