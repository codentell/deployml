resource "google_storage_bucket" "artifact" {
    name = var.artifact_bucket
    location = var.region
    force_destroy = true
}

resource "google_cloud_run_service" "mlflow" {
    name = "mlflow-server"
    location = var.region

    template {
        spec {
            containers {
                image = var.image
                env {
                    name = "MLFLOW_BACKEND_URI"
                    value = var.backend_store_uri
                }
                env {
                    name = "MLFLOW_ARTIFACT_ROOT"
                    value = "gs://${google_storage_bucket.artifact.name}"
                }
            }
        }
    }
    autogenerate_revision_name = true
}