with fact_totales as (
    select
        count(*) as viajes_fact,
        round(sum(total_amount), 2) as ingreso_fact
    from {{ ref('fact_trips') }}
),
agg_totales as (
    select
        sum(total_viajes) as viajes_agg,
        round(sum(ingreso_total), 2) as ingreso_agg
    from {{ ref('agg_zone_hour') }}
)
select *
from fact_totales f
cross join agg_totales a
where f.viajes_fact <> a.viajes_agg
   or abs(f.ingreso_fact - a.ingreso_agg) > 0.01