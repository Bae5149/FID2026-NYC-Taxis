with zonas_validas as (
    select distinct
        location_id
    from {{ ref('stg_taxi_zones') }}
    where location_id is not null
)

select
    t.periodo_mes,
    t.pu_location_id,
    t.do_location_id
from {{ ref('curated_yellow_trips') }} t
left join zonas_validas z_pu
    on t.pu_location_id = z_pu.location_id
left join zonas_validas z_do
    on t.do_location_id = z_do.location_id
where
    t.pu_location_id is null
    or t.do_location_id is null
    or z_pu.location_id is null
    or z_do.location_id is null