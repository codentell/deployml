# Importing dependencies
from datetime import timedelta
from feast.types import Int64, Float32, Int32
from feast import Entity, Field, FeatureView, FileSource, ValueType

# Declaring an entity for the dataset
driver_id = Entity(
    name="driver_id",
    join_keys=["driver_id"],
    value_type=ValueType.INT64, 
    description="The ID of the driver"
)

# Declaring the source for raw feature data
file_source = FileSource(
    name="driver_stats_source",
    path="data/driver_stats.parquet",
    timestamp_field="event_timestamp"
)

# Defining the features in a feature view
driver_stats_fv = FeatureView(
    name="driver_stats",
    entities=[driver_id],
    ttl=timedelta(days=2),
    schema=[
        Field(name="conv_rate", dtype=Float32),
        Field(name="acc_rate", dtype=Float32),
        Field(name="avg_daily_trips", dtype=Int32)        
        ],    
    source=file_source,
    online=True
)