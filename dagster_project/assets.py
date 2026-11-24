from dagster import asset


@asset
def ingesta():
    return "ingesta_ok"


@asset(deps=[ingesta])
def esquema():
    return "esquema_ok"


@asset(deps=[esquema])
def calidad():
    return "calidad_ok"


@asset(deps=[calidad])
def cuarentena():
    return "cuarentena_ok"


@asset(deps=[calidad])
def curated():
    return "curated_ok"