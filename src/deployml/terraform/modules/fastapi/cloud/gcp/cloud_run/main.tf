data "google_project" "current" {}

resource "google_cloud_run_service" "fastapi" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
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

resource "google_project_iam_member" "fastapi_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
} 