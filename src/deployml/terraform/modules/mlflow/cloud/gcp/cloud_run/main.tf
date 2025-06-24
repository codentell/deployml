# modules/mlflow/cloud/gcp/cloud_run/main.tf

data "google_project" "current" {}

# Storage bucket - only create if explicitly requested
resource "google_storage_bucket" "artifact" {
  count         = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  name          = var.artifact_bucket
  location      = var.region
  force_destroy = true
  
  labels = {
    component = "mlflow-artifacts"
    managed-by = "terraform"
  }
}

# Cloud Run service - only create if explicitly requested
resource "google_cloud_run_service" "mlflow" {
  count    = var.create_service && var.image != "" && var.service_name != "" ? 1 : 0
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
    
    spec {
      container_concurrency = 80
      timeout_seconds       = 300
      
      containers {
        image = var.image
        
        # Always set basic MLflow environment
        env {
          name  = "MLFLOW_SERVER_HOST"
          value = "0.0.0.0"
        }
        
        env {
          name  = "MLFLOW_SERVER_PORT"
          value = "5000"
        }
        
        # Backend store URI
        dynamic "env" {
          for_each = var.backend_store_uri != "" ? [1] : []
          content {
            name  = "MLFLOW_BACKEND_STORE_URI"
            value = var.backend_store_uri
          }
        }
        
        # Artifact root - use bucket if created, otherwise local
        env {
          name = "MLFLOW_DEFAULT_ARTIFACT_ROOT"
          value = var.artifact_bucket != "" ? "gs://${var.artifact_bucket}" : "/tmp/mlflow-artifacts"
        }

        ports {
          container_port = 5000
        }
        
        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
          requests = {
            cpu    = var.cpu_request
            memory = var.memory_request
          }
        }
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
  
  autogenerate_revision_name = true
}

# Make the service publicly accessible
resource "google_cloud_run_service_iam_member" "public" {
  count    = var.create_service && var.allow_public_access ? 1 : 0
  location = google_cloud_run_service.mlflow[0].location
  project  = google_cloud_run_service.mlflow[0].project
  service  = google_cloud_run_service.mlflow[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}


# Add to modules/mlflow/cloud/gcp/cloud_run/main.tf

# Grant Cloud Run service account access to the artifact bucket
resource "google_storage_bucket_iam_member" "mlflow_service_access" {
  count  = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket = google_storage_bucket.artifact[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}