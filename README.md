# deployml
Infra for academia

# Instructions

```bash
poetry install
poetry run deployml doctor
poetry run deployml
```


docker build --platform=linux/amd64 -t gcr.io/mlops-intro-461805/mlflow/mlflow:latest .

gcloud auth configure-docker
docker push gcr.io/PROJECT_ID/mlflow-app:latest