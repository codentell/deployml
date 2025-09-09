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

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. PostgreSQL Connection Failed
**Problem:** `connection to server at "localhost" failed`
**Solution:** Use Cloud SQL IP (`34.94.198.168:5432`), not localhost

#### 2. Feature Reference Parsing Error
**Problem:** `ValueError: too many values to unpack (expected 2)`
**Solution:** Use correct feature format: `house_features:price`

#### 3. Entity Not Found
**Problem:** Getting `null` values for features
**Solution:** 
- Use **join key** (`mls_id`) not entity name (`house_id`) in queries
- Ensure data was properly materialized
- Check that entity join key matches your data column

#### 4. Data Source Type Mismatch
**Problem:** `AssertionError: assert isinstance(data_source, PostgreSQLSource)`
**Solution:** Use `type: file` for offline store when using `FileSource`

#### 5. Silent Command Failures
**Problem:** Commands complete without clear success/error messages
**Solution:** Check PostgreSQL connection and verify feature definitions

#### 6. Feature Files Not Found
**Problem:** `feast apply` fails or can't find feature definitions
**Solution:** 
- **Create files on HOST VM** first (`/home/root/deployml/`)
- **Create directories in container** using `mkdir -p` commands
- **Move files to container** using `docker cp` commands
- **Verify file locations** inside the container
- **Remember**: Containers have isolated filesystems - files must be explicitly moved into the container

#### 7. "No such directory" Error
**Problem:** `docker cp` fails with "no such directory" error
**Solution:**
- **Create directories first**: `sudo docker exec -it feast-server mkdir -p /app/feature_repo/features`
- **Then copy files**: `sudo docker cp file.py feast-server:/app/feature_repo/features/`
- **Common directories needed**: `features/`, `data_sources/`, `entities/`

#### 8. Import Errors (NameError)
**Problem:** `NameError: name 'house_entity' is not defined` or similar import errors
**Solution:**
- **Check import statements** in your feature files
- **Ensure relative imports** are correct: `from .entities import house_entity`
- **Verify file structure** matches import paths
- **Common imports needed**:
  - `from .entities import house_entity`
  - `from ..data_sources.data_sources import house_source`

#### 9. Materialization Returns Null Values
**Problem:** Features return `null` values even after successful materialization
**Solution:**
- **Check timestamp range**: Use actual data range, not arbitrary dates
- **Verify data coverage**: Ensure materialization range covers your actual data timestamps
- **Common mistake**: Using `2024-01-01` when data is from `2017-2025`
- **Debug command**: Check your data with `df["event_timestamp"].min()` and `df["event_timestamp"].max()`

### Debugging Commands

#### Check Database Tables
```bash
sudo docker exec -it feast-server python -c "
import psycopg2
conn = psycopg2.connect(
    host='34.94.198.168',
    port=5432,
    database='feast',
    user='feast',
    password='wruwSQnG5G*LbDFB'
)
cursor = conn.cursor()
cursor.execute('SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\'')
tables = cursor.fetchall()
print('Tables:', [t[0] for t in tables])
conn.close()
"
```

#### Check Feature Store Status
```bash
sudo docker exec -it feast-server python -c "
from feast import FeatureStore
store = FeatureStore('/app/feature_repo')
print('Feature store loaded successfully')
print('Available features:', store.list_features())
"
```

## Final Working Configuration

### Feature Store Architecture
- **Registry**: PostgreSQL (Cloud SQL)
- **Online Store**: PostgreSQL (Cloud SQL) 
- **Offline Store**: File-based (local parquet)
- **Data Source**: FileSource pointing to parquet file
- **Entity**: `house_id` with join key `mls_id`

### Data Flow
1. **Parquet file** → **FileSource** → **Feature View**
2. **Feature View** → **Materialization** → **PostgreSQL Online Store**
3. **Online Store** → **Feature Retrieval** via `feast get-online-features`

### Key Success Factors
1. **Correct PostgreSQL credentials** from terraform state
2. **Proper entity join key** matching data column names
3. **File-based offline store** to avoid PostgreSQL conflicts
4. **Data materialization** after feature registration
5. **Correct query syntax** using join keys, not entity names

## Next Steps

With the feature store working, you can now:
- **Add new datasets** by creating new feature views
- **Update existing features** by modifying feature definitions and re-applying
- **Scale horizontally** by adding more feature views and data sources
- **Integrate with ML pipelines** for real-time feature serving

## Resources

- [Feast Documentation](https://docs.feast.dev/)
- [Feast Python SDK Reference](https://docs.feast.dev/reference/python-sdk)
- [PostgreSQL Online Store](https://docs.feast.dev/reference/online-stores/postgres)
- [File Data Sources](https://docs.feast.dev/reference/data-sources/file)
