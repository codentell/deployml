resource "google_cloud_run_service" "fastapi" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = var.image
        env {
          name  = "MLFLOW_TRACKING_URI"
          value = var.mlflow_tracking_uri
        }
        env {
          name  = "MODEL_URI"
          value = var.model_uri
        }
        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "public" {
  count    = var.allow_public_access ? 1 : 0
  location = google_cloud_run_service.fastapi.location
  project  = google_cloud_run_service.fastapi.project
  service  = google_cloud_run_service.fastapi.name
  role     = "roles/run.invoker"
  member   = "allUsers"
} 