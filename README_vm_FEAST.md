# Feast Feature Store Setup and Data Upload Guide

This README documents the complete process of setting up a Feast feature store on a Google Cloud VM and successfully uploading a parquet file (`house_data.parquet`) to it.

## Overview

We successfully deployed a Feast feature store on a GCP VM with:
- **PostgreSQL registry and online store** (Cloud SQL)
- **File-based offline store** (local parquet)
- **3,000 house sales records** loaded and materialized
- **Features**: price, bedrooms, bathrooms, area_sqft, year_built, days_on_market

## Prerequisites

- GCP VM instance running (`mlflow-postgres-vm-instance`)
- Docker and Docker Compose installed on the VM
- Feast server running in a Docker container
- PostgreSQL database accessible (Cloud SQL instance)
- Parquet file (`house_data.parquet`) with house sales data

## Step-by-Step Process

### 1. Initial Setup and Troubleshooting

#### 1.1 Connect to the VM
```bash
gcloud compute ssh --zone us-west2-a mlflow-postgres-vm-instance
```

#### 1.2 Check Running Containers
```bash
sudo docker ps
# Look for feast-server container
```

#### 1.3 Copy Parquet File to VM
```bash
# From your local machine
gcloud compute scp house_data.parquet skier@mlflow-postgres-vm-instance:/home/root/deployml/
```

### 2. Feast Configuration

#### 2.1 Create Feature Store Configuration
Create `feature_store.yaml` with PostgreSQL connections:

```yaml
project: house_sales
provider: local
registry:
  registry_type: sql
  path: postgresql://feast:wruwSQnG5G*LbDFB@34.94.198.168:5432/feast
  cache_ttl_seconds: 60
  sqlalchemy_config_kwargs:
    echo: false
    pool_pre_ping: true
online_store:
  type: postgres
  host: 34.94.198.168
  port: 5432
  database: feast
  user: feast
  password: wruwSQnG5G*LbDFB
offline_store:
  type: file
entity_key_serialization_version: 2
```

**Key Points:**
- Use **Cloud SQL IP** (`34.94.198.168:5432`), not localhost
- **Registry and online store** both use PostgreSQL
- **Offline store** uses file (not PostgreSQL) to avoid conflicts
- **Password** from terraform state: `wruwSQnG5G*LbDFB`

#### 2.2 Copy Configuration to Container
```bash
# Copy config to the Feast container
sudo docker cp feature_store.yaml feast-server:/app/feature_repo/feature_store.yaml
sudo docker cp feature_store.yaml feast-server:/app/feature_store.yaml
```

### 3. Feature Definitions

**⚠️ IMPORTANT: Create these files on the HOST VM first, then copy them to the container**

#### 3.1 Create Entity Definition (`entities.py`)
Create this file in `/home/root/deployml/` on the VM:
```python
from feast import Entity, ValueType

house_entity = Entity(
    name="mls_id",
    value_type=ValueType.INT64,
    description="Unique identifier for a house",
    join_keys=["mls_id"]  # This matches your parquet column
)
```

#### 3.2 Create Data Source (`data_sources.py`)
Create this file in `/home/root/deployml/` on the VM:
```python
from feast import FileSource
from feast.data_format import ParquetFormat

house_source = FileSource(
    name="house_source",
    path="/app/house_data.parquet",
    timestamp_field="event_timestamp",
    file_format=ParquetFormat()
)
```

#### 3.3 Create Feature View (`house_features.py`)
Create this file in `/home/root/deployml/` on the VM:
```python
from datetime import timedelta
from feast import FeatureView, Field
from feast.types import Float64, Int64
from .entities import house_entity
from ..data_sources.data_sources import house_source

house_features = FeatureView(
    name="house_features",
    entities=[house_entity],
    ttl=timedelta(weeks=52),
    schema=[
        Field(name="price", dtype=Float64),
        Field(name="bedrooms", dtype=Int64),
        Field(name="bathrooms", dtype=Float64),
        Field(name="area_sqft", dtype=Float64),
        Field(name="year_built", dtype=Int64),
        Field(name="days_on_market", dtype=Int64),
    ],
    source=house_source,
    tags={"team": "house_sales"},
)
```

**⚠️ IMPORTANT: The import statements are crucial!**
- `from .entities import house_entity` - imports the entity definition
- `from ..data_sources.data_sources import house_source` - imports the data source
- Without these imports, Feast will fail with "NameError: name not defined"

#### 3.4 Move Feature Files to the Container
**CRITICAL STEP:** After creating the files on the VM, you MUST move them to the Feast container where Feast can find them:

```bash
# First, create the required directories in the container
sudo docker exec -it feast-server mkdir -p /app/feature_repo/features
sudo docker exec -it feast-server mkdir -p /app/feature_repo/data_sources

# Then move feature definition files to the container
sudo docker cp entities.py feast-server:/app/feature_repo/features/
sudo docker cp data_sources.py feast-server:/app/feature_repo/data_sources/
sudo docker cp house_features.py feast-server:/app/feature_repo/features/

# Verify the files are in the right place
sudo docker exec -it feast-server ls -la /app/feature_repo/features/
sudo docker exec -it feast-server ls -la /app/feature_repo/data_sources/

# Optional: Remove the original files from the VM since they're now in the container
rm entities.py data_sources.py house_features.py
```

**Key Points:**
- **Entity join key** must match your data column (`mls_id`)
- **Schema fields** must match your parquet columns exactly
- **Data source path** must be accessible from within the container

### 4. Deploy Features

#### 4.1 Apply Feature Definitions
```bash
sudo docker exec -it feast-server feast apply
```

**Expected Output:**
```
Applying changes for project house_sales
Deploying infrastructure for house_features
```

#### 4.2 Verify Registration
```bash
# List projects
sudo docker exec -it feast-server feast projects list

# List entities
sudo docker exec -it feast-server feast entities list

# List features
sudo docker exec -it feast-server feast features list

# List data sources
sudo docker exec -it feast-server feast data-sources list
```

### 5. Data Materialization

#### 5.1 Copy Parquet File to Container
```bash
# Copy the parquet file to the Feast container
sudo docker cp house_data.parquet feast-server:/app/house_data.parquet
```

#### 5.2 Materialize Data to Online Store
```bash
sudo docker exec -it feast-server feast materialize \
  --views house_features \
  2017-06-04T00:00:00 2025-08-20T23:59:59
```

**⚠️ CRITICAL: Use the ACTUAL timestamp range from your data!**

**Expected Output:**
```
Materializing 1 feature views from 2017-06-04 00:00:00+00:00 to 2025-08-20 23:59:59+00:00 into the postgres online store.

house_features:
100%|███████████████████████████████████████████████████████████| 3000+/3000+ [00:XX<00:00, XXX.XXit/s]
```

**Why This Matters:**
- **Wrong range** (e.g., 2024-01-01 to 2024-12-31): No data loaded, results in `null` values
- **Correct range** (e.g., 2017-06-04 to 2025-08-20): All data loaded, features return actual values
- **Check your data**: Use `df["event_timestamp"].min()` and `df["event_timestamp"].max()` to find the actual range

### 6. Query Features

#### 6.1 Get Online Features
```bash
sudo docker exec -it feast-server feast get-online-features \
  --features house_features:price \
  --entities mls_id=112914
```

**Expected Output:**
```json
{
    "mls_id": [112914],
    "price": [843750]
}
```

#### 6.2 Get Multiple Features
```bash
sudo docker exec -it feast-server python -c "
from feast import FeatureStore
store = FeatureStore('/app/feature_repo')

# Get multiple features
features = store.get_online_features(
    features=['house_features:price', 'house_features:bedrooms', 'house_features:bathrooms'],
    entity_rows=[{'mls_id': 112914}]
)
print('Features retrieved successfully:')
print(features.to_dict())
"
```

**Expected Output:**
```json
{
    "mls_id": [112914],
    "bedrooms": [1],
    "price": [843750.0],
    "bathrooms": [3.0]
}
```

**Note:** The CLI has parsing issues with comma-separated features. Use the Python SDK for reliable multiple feature retrieval.