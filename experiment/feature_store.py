from feast import Entity, FeatureView, FileSource, Field, FeatureService, PushSource
from feast.types import Int64, Float32
from feast.value_type import ValueType
from datetime import timedelta
import pandas as pd

# Define entity
mls_id = Entity(
    name="MLS_ID",
    join_keys=["MLS ID"],           # column name in your data
    value_type=ValueType.INT64
)

# Define offline source
housing_source = FileSource(
    name="housing_source",
    path="data/house_data.parquet",
    timestamp_field="datetime"
    # file_format="csv"  # ✅ Explicitly tell Feast it’s a CSV file
)

# Define feature view
housing_fv = FeatureView(
    name="housing_features",
    entities=[mls_id],               # use the Entity object here
    ttl=timedelta(days=2999),
    schema=[
        Field(name="Price", dtype=Int64),
        Field(name="City", dtype=Int64),
        Field(name="State", dtype=Int64),
        Field(name="Bedrooms", dtype=Int64),
        Field(name="Bathrooms", dtype=Int64),
        Field(name="Area (Sqft)", dtype=Int64),
        Field(name="Lot Size", dtype=Int64),
        Field(name="Year Built", dtype=Int64),
        Field(name="Days on Market", dtype=Int64),
        Field(name="Property Type", dtype=Int64),
        Field(name="Listing Agent", dtype=Int64),
        Field(name="Status", dtype=Int64),
        Field(name="Zipcode_encoded", dtype=Float32),
    ],
    online=True,
    source=housing_source,
    tags={"team": "real_estate"},
)



# entities = [mls_id]
# feature_views = [housing_fv]
# feature_services = [housing_service_v1]

push_source = PushSource(
    name="house_push_source",
    batch_source=housing_source
)

housing_service_v1 = FeatureService(
    name="housing_v1",
    features=[housing_fv]
)