select
    f.pu_location_id,
    dz.borough as pu_borough,
    dz.zona as pu_zona,
    f.fecha_subida,
    f.hora_subida,
    f.year,
    f.month,
    count(*) as total_viajes,
    round(sum(f.total_amount), 2) as ingreso_total,
    round(avg(f.duracion_minutos), 2) as duracion_media_minutos
from {{ ref('fact_trips') }} f
left join {{ ref('dim_zone') }} dz
    on f.pu_location_id = dz.location_id
group by
    f.pu_location_id,
    dz.borough,
    dz.zona,
    f.fecha_subida,
    f.hora_subida,
    f.year,
    f.month