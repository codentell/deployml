from feast import FeatureStore
import pandas as pd

# Initialize store (repo_path points to the directory with feature_store.yaml)
store = FeatureStore(repo_path=".")

entity_rows = [
    {"MLS_ID": 104635},   # Must match the join_keys in your Entity definition
    {"MLS_ID": 535721},
]

features = store.get_online_features(
    features=[
        "housing_features:Price",
        "housing_features:Bedrooms",
        "housing_features:Zipcode_encoded"
    ],
    entity_rows=entity_rows
).to_df()
store.materialize_incremental(end_date=datetime.now())
print(features.head())