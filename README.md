# deployml
Infrastructure for academia with cost analysis

## Features

- 🏗️ **Infrastructure as Code**: Deploy ML infrastructure using Terraform
- 💰 **Cost Analysis**: Integrated infracost analysis before deployment
- ☁️ **Multi-Cloud Support**: GCP, AWS, and more
- 🔬 **ML-Focused**: Pre-configured for MLflow, experiment tracking, and model registry
- 🛡️ **Production Ready**: Security best practices and service account management

## Quick Start

```bash
poetry install
poetry run deployml doctor
poetry run deployml generate  # Create a configuration file
poetry run deployml deploy --config-path your-config.yaml
```

## Cost Analysis Integration

deployml integrates with [infracost](https://www.infracost.io/) to provide cost estimates before deployment:

### Installation (Optional)
```bash
# Install infracost for cost analysis
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
```

### Configuration
Add cost analysis settings to your YAML configuration:

```yaml
name: "my-mlops-stack"
cost_analysis:
  enabled: true              # Enable/disable cost analysis (default: true)
  warning_threshold: 100.0   # Warn if monthly cost exceeds this amount
  currency: "USD"            # Currency for cost display
```

### Cost Analysis Output
When deploying, you'll see detailed cost breakdowns:

```
💰 COST ANALYSIS
════════════════════════════════════════
Monthly Cost: $30.34 USD
Hourly Cost:  $0.0416 USD

📋 Resource Breakdown:
• google_compute_instance.mlflow_vm
  Type: google_compute_instance
  Monthly Cost: $30.34
    └─ Instance (e2-medium): $29.38
    └─ Storage (20GB): $0.96

🚀 Deploy stack? 💰 Monthly cost: ~$30.34 USD [y/N]:
```


docker build --platform=linux/amd64 -t gcr.io/mlops-intro-461805/mlflow/mlflow:latest .

gcloud auth configure-docker
docker push gcr.io/PROJECT_ID/mlflow-app:latest

## Cloud Run Service Account Setup

When deploying MLflow, you must specify the service account email that Cloud Run will use. This service account must have permission to access the artifact bucket.

### How to get a service account email

1. List your service accounts:
   ```sh
   gcloud iam service-accounts list
   ```
2. (Recommended) Create a dedicated service account for MLflow if you don't have one:
   ```sh
   gcloud iam service-accounts create mlflow-cloudrun --display-name "MLflow Cloud Run Service Account"
   ```
3. Find the email for your service account (it will look like `mlflow-cloudrun@YOUR_PROJECT.iam.gserviceaccount.com`).

### Grant the service account permissions

The Terraform module will automatically grant the service account the required permissions on the artifact bucket.

### Deploying with Terraform

Pass the service account email as a variable:

```sh
terraform apply -var="cloud_run_service_account=mlflow-cloudrun@YOUR_PROJECT.iam.gserviceaccount.com"
```

Or, if using the CLI, ensure it passes this variable to Terraform.

### Why this is needed

The MLflow server (running on Cloud Run) needs permission to list and read artifacts in the GCS bucket. This setup ensures the MLflow UI works for all users without manual permission fixes.