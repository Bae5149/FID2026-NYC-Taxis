{% set mes_actual = var('mes', '2025-03') %}
{% set partes = mes_actual.split('-') %}
{% set anio_actual = partes[0] | int %}
{% set mes_num = partes[1] | int %}

with base as (

    select *
    from read_parquet(
        '/app/data/curated_hive/**/*.parquet',
        hive_partitioning = true
    )
    where month = {{ mes_num }}
      and year in ({{ anio_actual }}, {{ anio_actual - 1 }})

),

origenes as (
    select distinct
        cast(pu_location_id as integer) as location_id,
        pu_borough as borough,
        pu_zona as zona,
        pu_service_zone as service_zone
    from base
    where pu_location_id is not null
),

destinos as (
    select distinct
        cast(do_location_id as integer) as location_id,
        do_borough as borough,
        do_zona as zona,
        do_service_zone as service_zone
    from base
    where do_location_id is not null
),

unidas as (
    select * from origenes
    union
    select * from destinos
)

select
    location_id,
    coalesce(borough, 'Sin Barrio') as borough,
    coalesce(zona, 'Sin Zona') as zona,
    coalesce(service_zone, 'Sin Zona de Servicio') as service_zone
from unidas
order by location_id