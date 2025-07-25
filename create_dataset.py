import pandas as pd 
import numpy as np
import os 
import subprocess
from feast import FeatureStore
from feast.infra.offline_stores.file_source import SavedDatasetFileStorage
from datetime import datetime


store = FeatureStore(repo_path="experiment")

print("Applying feature definitions...")
subprocess.run(["feast", "apply"], cwd="experiment")


timestamps = pd.date_range(
    start="2000-01-01",    
    end="2008-03-18",     
    ).to_frame(name="event_timestamp", index=False)



mls_ids = pd.DataFrame(data=[104635, 535721, 900458, 318589,
899716,876426], 
                          columns=["MLS ID"])



entity_df = timestamps.merge(right=mls_ids, 
                             how="cross")

print(entity_df)

print("Entity DataFrame shape:", entity_df.shape)


data_job = store.get_historical_features(
    entity_df=entity_df,
    features=[
        "housing_features:Price",
        "housing_features:Bedrooms",
        "housing_features:Bathrooms",
        "housing_features:Area (Sqft)",
        "housing_features:Lot Size",
        "housing_features:Year Built",
        "housing_features:Days on Market",
        "housing_features:City",
        "housing_features:State",
        "housing_features:Property Type",
        "housing_features:Listing Agent",
        "housing_features:Status",
        "housing_features:Zipcode_encoded",
    ]
)

print("Data job type:", type(data_job))

historical_features_df = data_job.to_df()

print(historical_features_df)

print("Historical features DataFrame shape:", historical_features_df.shape)
print("Historical features DataFrame columns:", historical_features_df.columns.tolist())
print("Historical features DataFrame head:")
print(historical_features_df.head())

store.materialize(start_date = datetime.strptime("2000-01-01", "%Y-%m-%d"),
                  end_date = datetime.strptime("2008-03-18", "%Y-%m-%d"))



# Fetch Online Features for MLS ID 104635

entity_rows = [
    {
        "MLS ID":104635
    },
    {
        "MLS ID":899716
    }
]

features_to_fetch = [
    "housing_features:Year Built",
    "housing_features:Price",
    "housing_features:Lot Size"
]

returned_features = store.get_online_features(
    features=features_to_fetch,
    entity_rows=entity_rows,
).to_dict()


for key, value in sorted(returned_features.items()):
    print(key, " : ", value)



# TO CALL ON FASTAPI 

# {
#   "entities": {
#     "MLS ID": [104635, 899716]
#   },
#   "feature_service": "housing_v1",
#   "features": [
#     "housing_features:Year Built",
#     "housing_features:Price", 
#     "housing_features:Lot Size"
#   ],
#   "full_feature_names": false,
#   "query_embedding": [],
#   "query_string": ""
# }