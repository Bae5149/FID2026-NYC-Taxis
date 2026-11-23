select
    periodo_mes,
    total_amount
from {{ ref('clean_yellow_trips') }}
where
    total_amount is null
    or total_amount < 0