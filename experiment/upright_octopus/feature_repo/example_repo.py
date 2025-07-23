# Importing dependencies
from datetime import timedelta
from feast.types import Int64, Float32, Int32
from feast import Entity, Feature, FeatureView, FileSource, ValueType

# Declaring an entity for the dataset
driver = Entity(
    name="driver_id", 
    value_type=ValueType.INT64, 
    description="The ID of the driver"
    )

# Declaring the source for raw feature data
file_source = FileSource(
    path="data/driver_stats.parquet",
    event_timestamp_column="event_timestamp",
    created_timestamp_column="created"
)

# Defining the features in a feature view
driver_stats_fv = FeatureView(
    name="driver_stats_fv",
    ttl=timedelta(days=2),
    entities=["driver_id"],
    features=[
        Feature(name="conv_rate", dtype=Float32),
        Feature(name="acc_rate", dtype=Float32),
        Feature(name="avg_daily_trips", dtype=Int32)        
        ],    
    source=file_source,
    online=True
)