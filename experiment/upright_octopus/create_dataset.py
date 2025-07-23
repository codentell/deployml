# Importing dependencies
import pandas as pd
import numpy as np
from feast import FeatureStore
from feast.infra.offline_stores.file_source import SavedDatasetFileStorage

# Getting our FeatureStore
store = FeatureStore(repo_path="feature_repo")



#### GETTING HISTORICAL FEATURES FOR ALL DRIVER IDS ####

# Creating timestamps
timestamps = pd.date_range(
    start="2021-08-31",    
    end="2021-09-04",     
    freq='H').to_frame(name="event_timestamp", index=False)

# Dropping the first 17 hours of the day
timestamps = timestamps.drop(labels=np.arange(18), axis=0)

# Creating a DataFrame with the driver IDs we want to get features for
driver_ids = pd.DataFrame(data=[1001, 1002, 1003, 1004, 1005], 
                          columns=["driver_id"])

# Creating the cartesian product of our timestamps and entities 
entity_df = timestamps.merge(right=driver_ids, 
                             how="cross")

# Getting the indicated historical features
# and joining them with our entity DataFrame
data_job = store.get_historical_features(
    entity_df=entity_df,
    features=[
        "driver_stats_fv:conv_rate",
        "driver_stats_fv:acc_rate",
        "driver_stats_fv:avg_daily_trips",
    ]
)

# Storing the dataset as a local file
dataset = store.create_saved_dataset(
    from_=data_job,
    name="driver_stats",
    storage=SavedDatasetFileStorage(path="feature_repo/data/driver_stats.parquet")
)



#### GETTING HISTORICAL FEATURES FOR DRIVER ID 1001 ####

# Creating a DataFrame with the driver IDs we want to get features for
driver_id = pd.DataFrame(data=[1001], 
                         columns=["driver_id"])

# Creating the cartesian product of our timestamps and entities 
entity_df_1001 = timestamps.merge(right=driver_id, 
                                  how="cross")

# Getting the indicated historical features
# and joining them with our entity DataFrame
data_job_1001 = store.get_historical_features(
    entity_df=entity_df_1001,
    features=[
        "driver_stats_fv:conv_rate",
        "driver_stats_fv:acc_rate",
        "driver_stats_fv:avg_daily_trips",
    ]
)

# Storing the dataset as a local file
dataset_1001 = store.create_saved_dataset(
    from_=data_job_1001,
    name="driver_stats_1001",
    storage=SavedDatasetFileStorage(path="feature_repo/data/driver_stats_1001.parquet")
)
