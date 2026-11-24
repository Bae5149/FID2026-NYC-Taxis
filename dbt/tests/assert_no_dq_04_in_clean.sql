select
    periodo_mes,
    total_amount
from {{ ref('curated_yellow_trips') }}
where
    total_amount is null
    or total_amount < 0