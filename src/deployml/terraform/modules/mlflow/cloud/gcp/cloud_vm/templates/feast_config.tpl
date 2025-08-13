#!/usr/bin/env python3
import os
import json

# Feast configuration
feast_config = {
    "project": "feast_project",
    "provider": "local",
    "online_store": {
        "type": os.environ.get("ONLINE_STORE_TYPE", "sqlite"),
        "connection_string": os.environ.get("POSTGRES_HOST") and 
            f"postgresql://{os.environ.get('POSTGRES_USER')}:{os.environ.get('POSTGRES_PASSWORD')}@{os.environ.get('POSTGRES_HOST')}:{os.environ.get('POSTGRES_PORT')}/{os.environ.get('POSTGRES_DATABASE')}" or 
            "sqlite:///feast.db"
    },
    "offline_store": {
        "type": os.environ.get("OFFLINE_STORE_TYPE", "bigquery"),
        "dataset": os.environ.get("BIGQUERY_DATASET", "feast_offline_store")
    },
    "registry": {
        "type": os.environ.get("REGISTRY_TYPE", "file"),
        "path": "/app/registry.db"
    }
}

# Write Feast configuration
with open("/app/feature_store.yaml", "w") as f:
    import yaml
    yaml.dump(feast_config, f, default_flow_style=False)

print("✅ Feast configuration created successfully!")
