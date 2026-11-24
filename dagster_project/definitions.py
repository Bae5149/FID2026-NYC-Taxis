from dagster import Definitions

from .assets import (
    ingesta_dlt,
    schema_contract,
    dbt_quality,
    curate_partitioned,
    dbt_marts,
)

defs = Definitions(
    assets=[
        ingesta_dlt,
        schema_contract,
        dbt_quality,
        curate_partitioned,
        dbt_marts,
    ]
)