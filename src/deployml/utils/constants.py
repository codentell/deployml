from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
TERRAFORM_DIR = Path(__file__).parent.parent / "terraform"

TOOL_VARIABLES = {
    "mlflow": [
        {"name": "project_id", "type": "string", "description": "GCP project ID"},
        {"name": "region", "type": "string", "description": "Deployment region"},
        {"name": "artifact_bucket", "type": "string", "description": "Bucket for MLflow artifacts"},
        {"name": "backend_store_uri", "type": "string", "description": "URI for MLflow backend store"},
        {"name": "image", "type": "string", "description": "MLflow Docker image"},
    ],
    "fastapi": [
        {"name": "project_id", "type": "string", "description": "GCP project ID"},
        {"name": "region", "type": "string", "description": "Deployment region"},
        {"name": "image", "type": "string", "description": "FastAPI Docker image"},
    ]
}