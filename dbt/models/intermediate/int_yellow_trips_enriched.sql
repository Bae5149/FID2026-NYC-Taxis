{{ config(materialized='ephemeral') }}

with trips_limpios as (
    select *
    from read_parquet('data/curated/curated_yellow_trips.parquet')
),

zonas as (
    select
        location_id,
        borough,
        zone,
        service_zone
    from {{ ref('stg_taxi_zones') }}
),

calculado as (
    select
        t.*,

        -- Duracion en minutos (segundos / 60.0)
        cast(date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) / 60.0 as double)
            as duracion_minutos,

        -- Velocidad promedio en mph (protegida contra duracion nula o <= 0)
        case
            when date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) > 0
                then cast(
                    t.trip_distance / (date_diff('second', t.tpep_pickup_datetime, t.tpep_dropoff_datetime) / 3600.0)
                    as double
                )
            else cast(null as double)
        end as velocidad_promedio_mph,

        -- Fecha, hora y dia de la semana de subida
        cast(t.tpep_pickup_datetime as date) as fecha_subida,
        cast(extract(hour from t.tpep_pickup_datetime) as integer) as hora_subida,
        cast(extract(isodow from t.tpep_pickup_datetime) as integer) as dia_semana_num,
        case extract(isodow from t.tpep_pickup_datetime)
            when 1 then 'Lunes'
            when 2 then 'Martes'
            when 3 then 'Miercoles'
            when 4 then 'Jueves'
            when 5 then 'Viernes'
            when 6 then 'Sabado'
            when 7 then 'Domingo'
        end as dia_semana_nombre,

        -- Propina como porcentaje de la tarifa (protegida contra fare_amount <= 0 o null)
        case
            when t.fare_amount is not null and t.fare_amount > 0
                then cast((t.tip_amount / t.fare_amount) * 100.0 as double)
            else cast(null as double)
        end as porcentaje_propina_tarifa,

        -- Columnas de particion estilo Hive derivadas de la subida
        cast(extract(year from t.tpep_pickup_datetime) as integer) as year,
        cast(extract(month from t.tpep_pickup_datetime) as integer) as month,

        -- Enriquecimiento con zonas (origen y destino)
        pu.borough as pu_borough,
        pu.zone as pu_zona,
        pu.service_zone as pu_service_zone,
        do_z.borough as do_borough,
        do_z.zone as do_zona,
        do_z.service_zone as do_service_zone

    from trips_limpios t
    left join zonas pu
        on t.pu_location_id = pu.location_id
    left join zonas do_z
        on t.do_location_id = do_z.location_id
)

select *
from calculado