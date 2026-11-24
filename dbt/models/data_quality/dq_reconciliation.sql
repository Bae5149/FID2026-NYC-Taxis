{{ config(
    materialized='external',
    location='data/dq/dq_reconciliation.parquet',
    format='parquet'
) }}

{% set max_distancia_millas = var('max_distancia_millas', 100.0) %}
{% set max_velocidad_mph = var('max_velocidad_mph', 80.0) %}

with base as (
    select *
    from {{ ref('int_yellow_trips_dq') }}
),

agregado as (
    select
        periodo_mes,
        es_mes_solicitado,

        -- Totales y balance de filas
        count(*) as filas_leidas,
        count(*) filter (where coalesce(es_rechazo_dq, false) = false) as filas_limpias,
        count(*) filter (where coalesce(es_rechazo_dq, false) = true) as filas_cuarentena,
        count(*) - (
            count(*) filter (where coalesce(es_rechazo_dq, false) = false)
            + count(*) filter (where coalesce(es_rechazo_dq, false) = true)
        ) as diferencia_filas,

        -- Tasas y advertencias
        round(
            100.0 * (count(*) filter (where coalesce(es_rechazo_dq, false) = true))
            / nullif(count(*), 0),
            4
        ) as porcentaje_rechazo,
        count(*) filter (where coalesce(es_advertencia_dq_05, false) = true) as advertencias_dq_05_pasajeros,

        -- Rechazos por regla (DQ_01 a DQ_08, excluyendo DQ_05 que es advertencia)
        count(*) filter (where coalesce(dq_01_pickup_fuera_de_mes, false) = true) as rechazos_dq_01_pickup_mes,
        count(*) filter (where coalesce(dq_02_duracion_invalida, false) = true) as rechazos_dq_02_duracion,
        count(*) filter (where coalesce(dq_03_distancia_invalida, false) = true) as rechazos_dq_03_distancia,
        count(*) filter (where coalesce(dq_04_monto_total_invalido, false) = true) as rechazos_dq_04_monto_total,
        count(*) filter (where coalesce(dq_06_zona_invalida, false) = true) as rechazos_dq_06_zona,
        count(*) filter (where coalesce(dq_07_duplicado_exacto, false) = true) as rechazos_dq_07_duplicado,
        count(*) filter (where coalesce(dq_08_velocidad_excesiva, false) = true) as rechazos_dq_08_velocidad,

        -- Trazabilidad de umbrales y ejecucion
        cast({{ max_distancia_millas }} as double) as umbral_max_distancia_millas,
        cast({{ max_velocidad_mph }} as double) as umbral_max_velocidad_mph,
        current_timestamp as ejecutado_en_utc
    from base
    group by
        periodo_mes,
        es_mes_solicitado
)

select *
from agregado
order by
    periodo_mes,
    es_mes_solicitado