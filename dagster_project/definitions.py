from dagster import Definitions

from .assets import (
    ingesta_dlt,
    schema_contract,
    dbt_quality,
)

defs = Definitions(
    assets=[
        ingesta_dlt,
        schema_contract,
        dbt_quality,
    ]
)