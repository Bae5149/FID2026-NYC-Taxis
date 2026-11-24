with base as (
    select distinct
        fecha_subida,
        year,
        month,
        dia_semana_num,
        dia_semana_nombre
    from read_parquet('data/curated_hive/**/*.parquet', hive_partitioning = true)
    where fecha_subida is not null
)

select
    fecha_subida,
    cast(year as integer) as year,
    cast(month as integer) as month,
    cast(extract(day from fecha_subida) as integer) as dia_mes,
    cast(dia_semana_num as integer) as dia_semana_num,
    dia_semana_nombre,
    case when dia_semana_num in (6, 7) then true else false end as es_fin_de_semana
from base
order by fecha_subida