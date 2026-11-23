select
    cast(LocationID as integer) as location_id,
    cast(Borough as varchar) as borough,
    cast(Zone as varchar) as zone,
    cast(service_zone as varchar) as service_zone
from read_csv_auto(
    'data/raw/taxi_zone_lookup.csv',
    header = true
)