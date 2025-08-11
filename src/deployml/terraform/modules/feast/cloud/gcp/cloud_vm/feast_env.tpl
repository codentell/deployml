# Feast Environment Configuration for VM Deployment
# Database Configuration
FEAST_REGISTRY_TYPE=${use_postgres ? "sql" : "file"}
FEAST_REGISTRY_PATH=${use_postgres ? backend_store_uri : "data/registry.db"}
FEAST_ONLINE_STORE_TYPE=${use_postgres ? "postgres" : "sqlite"}

%{ if use_postgres ~}
# PostgreSQL Configuration
FEAST_ONLINE_STORE_HOST=${postgres_host}
FEAST_ONLINE_STORE_PORT=${postgres_port}
FEAST_ONLINE_STORE_DATABASE=${postgres_database}
FEAST_ONLINE_STORE_USER=${postgres_user}
FEAST_ONLINE_STORE_PASSWORD=${postgres_password}
%{ else ~}
# SQLite Configuration
FEAST_ONLINE_STORE_PATH=data/online_store.db
%{ endif ~}

# BigQuery Configuration
FEAST_OFFLINE_STORE_TYPE=bigquery
FEAST_OFFLINE_STORE_PROJECT=${project_id}
FEAST_OFFLINE_STORE_DATASET=${bigquery_dataset}

# GCS Configuration
FEAST_ARTIFACT_BUCKET=${artifact_bucket}

# GCP Configuration
GOOGLE_CLOUD_PROJECT=${project_id}

# Service Configuration
USE_POSTGRES=${use_postgres ? "true" : "false"}
FEAST_PORT=${feast_port}

# Deployment Information
FEAST_DEPLOYMENT_TYPE=vm
FEAST_DEPLOYMENT_VERSION=2.0