{{ config(materialized='ephemeral') }}

{# Umbrales configurables (ajustables aqui o via --vars en dbt) #}
{% set max_distancia_millas = var('max_distancia_millas', 100.0) %}
{% set max_velocidad_mph = var('max_velocidad_mph', 80.0) %}

with trips as (
    select * from {{ ref('stg_yellow_trips') }}
),

zonas_validas as (
    select distinct
        location_id
    from {{ ref('stg_taxi_zones') }}
    where location_id is not null
),

-- 1. Derivar mes de subida, duracion, velocidad promedio, zonas y duplicados
metricas_y_validaciones as (
    select
        t.*,
        strftime(t.tpep_pickup_datetime, '%Y-%m') as pickup_mes,
        case
            when t.tpep_pickup_datetime is not null
                and t.tpep_dropoff_datetime is not null
                then epoch(t.tpep_dropoff_datetime - t.tpep_pickup_datetime)
            else null
        end as duracion_segundos,
        case
            when t.tpep_pickup_datetime is not null
                and t.tpep_dropoff_datetime is not null
                and epoch(t.tpep_dropoff_datetime - t.tpep_pickup_datetime) > 0
                and t.trip_distance is not null
                then cast(t.trip_distance as double)
                    / (cast(epoch(t.tpep_dropoff_datetime - t.tpep_pickup_datetime) as double) / 3600.0)
            else null
        end as velocidad_mph,
        (
            t.pu_location_id is null
            or z_pu.location_id is null
        ) as pu_zona_invalida,
        (
            t.do_location_id is null
            or z_do.location_id is null
        ) as do_zona_invalida,
        row_number() over (
            partition by
                t.periodo_mes,
                t.vendor_id,
                t.tpep_pickup_datetime,
                t.tpep_dropoff_datetime,
                t.passenger_count,
                t.trip_distance,
                t.ratecode_id,
                t.store_and_fwd_flag,
                t.pu_location_id,
                t.do_location_id,
                t.payment_type,
                t.fare_amount,
                t.extra,
                t.mta_tax,
                t.tip_amount,
                t.tolls_amount,
                t.improvement_surcharge,
                t.total_amount,
                t.congestion_surcharge,
                t.airport_fee,
                t.cbd_congestion_fee
            order by
                t.source_file asc
        ) as num_ocurrencia
    from trips t
    left join zonas_validas z_pu
        on t.pu_location_id = z_pu.location_id
    left join zonas_validas z_do
        on t.do_location_id = z_do.location_id
),

-- 2. Evaluar reglas DQ_01 a DQ_08 por separado
reglas_dq as (
    select
        *,
        (
            tpep_pickup_datetime is null
            or pickup_mes is distinct from periodo_mes
        ) as dq_01_pickup_fuera_de_mes,

        (
            tpep_pickup_datetime is null
            or tpep_dropoff_datetime is null
            or duracion_segundos <= 0
        ) as dq_02_duracion_invalida,

        (
            trip_distance is null
            or trip_distance <= 0
            or trip_distance > {{ max_distancia_millas }}
        ) as dq_03_distancia_invalida,

        (
            total_amount is null
            or total_amount < 0
        ) as dq_04_monto_total_invalido,

        (
            passenger_count is null
            or passenger_count <= 0
        ) as dq_05_pasajeros_invalido,

        (
            pu_zona_invalida
            or do_zona_invalida
        ) as dq_06_zona_invalida,

        (
            num_ocurrencia > 1
        ) as dq_07_duplicado_exacto,

        (
            velocidad_mph is not null
            and velocidad_mph > {{ max_velocidad_mph }}
        ) as dq_08_velocidad_excesiva
    from metricas_y_validaciones
),

-- 3. Construir flags de rechazo, advertencias y motivos legibles
con_motivos as (
    select
        *,
        (
            dq_01_pickup_fuera_de_mes
            or dq_02_duracion_invalida
            or dq_03_distancia_invalida
            or dq_04_monto_total_invalido
            or dq_06_zona_invalida
            or dq_07_duplicado_exacto
            or dq_08_velocidad_excesiva
        ) as es_rechazo_dq,

        dq_05_pasajeros_invalido as es_advertencia_dq_05,

        case
            when tpep_pickup_datetime is null
                then 'DQ_01: tpep_pickup_datetime nulo'
            when pickup_mes is distinct from periodo_mes
                then 'DQ_01: pickup en ' || pickup_mes || ' distinto de ' || periodo_mes
            else null
        end as motivo_dq_01,

        case
            when tpep_pickup_datetime is null or tpep_dropoff_datetime is null
                then 'DQ_02: fecha pickup o dropoff nula'
            when duracion_segundos < 0
                then 'DQ_02: dropoff anterior a pickup (' || cast(duracion_segundos as varchar) || ' s)'
            when duracion_segundos = 0
                then 'DQ_02: duracion cero segundos (dropoff igual a pickup)'
            else null
        end as motivo_dq_02,

        case
            when trip_distance is null
                then 'DQ_03: trip_distance nulo'
            when trip_distance <= 0
                then 'DQ_03: distancia <= 0 (' || cast(trip_distance as varchar) || ' mi)'
            when trip_distance > {{ max_distancia_millas }}
                then 'DQ_03: distancia > ' || cast({{ max_distancia_millas }} as varchar) || ' mi (' || cast(trip_distance as varchar) || ' mi)'
            else null
        end as motivo_dq_03,

        case
            when total_amount is null
                then 'DQ_04: total_amount nulo'
            when total_amount < 0
                then 'DQ_04: total_amount negativo (' || cast(total_amount as varchar) || ')'
            else null
        end as motivo_dq_04,

        case
            when passenger_count is null
                then 'DQ_05: passenger_count nulo'
            when passenger_count <= 0
                then 'DQ_05: passenger_count <= 0 (' || cast(passenger_count as varchar) || ')'
            else null
        end as motivo_dq_05,

        case
            when pu_zona_invalida and do_zona_invalida
                then 'DQ_06: pu_location_id (' || coalesce(cast(pu_location_id as varchar), 'NULL') || ') y do_location_id (' || coalesce(cast(do_location_id as varchar), 'NULL') || ') invalidos'
            when pu_zona_invalida
                then 'DQ_06: pu_location_id (' || coalesce(cast(pu_location_id as varchar), 'NULL') || ') no existe en taxi_zone_lookup'
            when do_zona_invalida
                then 'DQ_06: do_location_id (' || coalesce(cast(do_location_id as varchar), 'NULL') || ') no existe en taxi_zone_lookup'
            else null
        end as motivo_dq_06,

        case
            when num_ocurrencia > 1
                then 'DQ_07: duplicado exacto (ocurrencia #' || cast(num_ocurrencia as varchar) || ')'
            else null
        end as motivo_dq_07,

        case
            when velocidad_mph is not null and velocidad_mph > {{ max_velocidad_mph }}
                then 'DQ_08: velocidad promedio > ' || cast({{ max_velocidad_mph }} as varchar) || ' mph (' || cast(round(velocidad_mph, 2) as varchar) || ' mph)'
            else null
        end as motivo_dq_08
    from reglas_dq
)

select * from con_motivos