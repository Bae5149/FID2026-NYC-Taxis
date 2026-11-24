from dagster import Definitions

from .assets import (
    ingesta_dlt,
    schema_contract,
    dbt_quality,
    curate_partitioned,
)

defs = Definitions(
    assets=[
        ingesta_dlt,
        schema_contract,
        dbt_quality,
        curate_partitioned,
    ]
)