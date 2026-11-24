from dagster import Definitions

from .assets import (
    ingesta,
    esquema,
    calidad,
    cuarentena,
    curated
)

defs = Definitions(
    assets=[
        ingesta,
        esquema,
        calidad,
        cuarentena,
        curated
    ]
)