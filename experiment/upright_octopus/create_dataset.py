# Importing dependencies
import pandas as pd
import numpy as np
import os
import subprocess
from feast import FeatureStore
from feast.infra.offline_stores.file_source import SavedDatasetFileStorage
from datetime import datetime


# Getting our FeatureStore
store = FeatureStore(repo_path="feature_repo")


print("Applying feature definitions...")
subprocess.run(["feast", "apply"], cwd="feature_repo")


#### GETTING HISTORICAL FEATURES FOR ALL DRIVER IDS ####

# Creating timestamps
timestamps = pd.date_range(
    start="2025-06-23",    
    end="2025-07-23",     
    freq='h').to_frame(name="event_timestamp", index=False)

# Dropping the first 17 hours of the day
timestamps = timestamps.drop(labels=np.arange(18), axis=0)

# Creating a DataFrame with the driver IDs we want to get features for
driver_ids = pd.DataFrame(data=[1001, 1002, 1003, 1004, 1005], 
                          columns=["driver_id"])

# Creating the cartesian product of our timestamps and entities 
entity_df = timestamps.merge(right=driver_ids, 
                             how="cross")

print("Entity DataFrame shape:", entity_df.shape)
print("Entity DataFrame head:")
print(entity_df.head())

# Getting the indicated historical features
# and joining them with our entity DataFrame
data_job = store.get_historical_features(
    entity_df=entity_df,
    features=[
        "driver_stats:conv_rate",
        "driver_stats:acc_rate",
        "driver_stats:avg_daily_trips",
    ]
)

print("Data job type:", type(data_job))

# Materialize the data to get the actual DataFrame
historical_features_df = data_job.to_df()


print(historical_features_df)

print("Historical features DataFrame shape:", historical_features_df.shape)
print("Historical features DataFrame columns:", historical_features_df.columns.tolist())
print("Historical features DataFrame head:")
print(historical_features_df.head())

# You can also save this DataFrame directly
# output_path = "feature_repo/data/driver_stats_historical.parquet"
# historical_features_df.to_parquet(output_path, index=False)
# print(f"Data saved to: {output_path}")

# Alternative: Create a saved dataset using Feast's dataset functionality
# dataset_path = "feature_repo/data/driver_stats_historical.parquet"



store.materialize_incremental(end_date=datetime.now())



# Fetch Online Features for Driver ID 1001

entity_rows = [
    {
        "driver_id":1001
    },
    {
        "driver_id":1002
    }
]

features_to_fetch = [
    "driver_stats:conv_rate",
    "driver_stats:acc_rate",
    "driver_stats:avg_daily_trips",
]

returned_features = store.get_online_features(
    features=features_to_fetch,
    entity_rows=entity_rows,
).to_dict()

for key, value in sorted(returned_features.items()):
    print(key, " : ", value)





# # Remove existing file if it exists
# if os.path.exists(dataset_path):
#     os.remove(dataset_path)

# dataset = store.create_saved_dataset(
#     from_=data_job,
#     name="driver_stats_historical",
#     storage=SavedDatasetFileStorage(path=dataset_path)
# )




# print(f"Saved dataset created: {dataset}")

#### GETTING HISTORICAL FEATURES FOR DRIVER ID 1001 ####

# Creating a DataFrame with the driver IDs we want to get features for
# entity_df_1001 = pd.DataFrame(data=[1001], columns=["driver_id"])

# Getting the indicated historical features
# and joining them with our entity DataFrame
# data_job_1001 = store.get_historical_features(
#     entity_df=entity_df_1001,
#     features=[
#         "driver_stats:conv_rate",
#         "driver_stats:acc_rate",
#         "driver_stats:avg_daily_trips",
#     ]
# )

# # Storing the dataset as a local file
# dataset_1001 = store.create_saved_dataset(
#     from_=data_job_1001,
#     name="driver_stats_1001",
#     storage=SavedDatasetFileStorage(path="feature_repo/data/driver_stats_1001.parquet")
# )
