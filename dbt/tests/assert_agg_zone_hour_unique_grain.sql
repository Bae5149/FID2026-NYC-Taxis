select
    pu_location_id,
    fecha_subida,
    hora_subida,
    count(*) as registros
from {{ ref('agg_zone_hour') }}
group by 1, 2, 3
having count(*) > 1