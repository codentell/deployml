data "google_project" "current" {}

resource "google_cloud_run_service" "feast" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    metadata {
      annotations = var.use_postgres && var.cloudsql_instance_annotation != "" ? {
        "autoscaling.knative.dev/maxScale" = var.max_scale
        "run.googleapis.com/cloudsql-instances" = var.cloudsql_instance_annotation
        "run.googleapis.com/execution-environment" = "gen2"
        "run.googleapis.com/memory" = var.memory_limit
        "run.googleapis.com/cpu" = var.cpu_limit
      } : {
        "autoscaling.knative.dev/maxScale" = var.max_scale
        "run.googleapis.com/execution-environment" = "gen2"
        "run.googleapis.com/memory" = var.memory_limit
        "run.googleapis.com/cpu" = var.cpu_limit
      }
    }
    spec {
      service_account_name = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
      container_concurrency = var.container_concurrency
      containers {
        image = var.image
        
        env {
          name  = "FEAST_REGISTRY_TYPE"
          value = var.use_postgres ? "sql" : "file"
        }
        
        env {
          name  = "FEAST_REGISTRY_PATH"
          value = var.backend_store_uri
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_TYPE"
          value = var.use_postgres ? "postgres" : "sqlite"
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_HOST"
          value = var.postgres_host
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_PORT"
          value = var.postgres_port
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_DATABASE"
          value = var.postgres_database
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_USER"
          value = var.postgres_user
        }
        
        env {
          name  = "FEAST_ONLINE_STORE_PASSWORD"
          value = var.postgres_password
        }
        
        env {
          name  = "USE_POSTGRES"
          value = var.use_postgres ? "true" : "false"
        }
        
        env {
          name  = "FEAST_OFFLINE_STORE_TYPE"
          value = "bigquery"
        }
        
        env {
          name  = "FEAST_OFFLINE_STORE_PROJECT"
          value = var.project_id
        }
        
        env {
          name  = "FEAST_OFFLINE_STORE_DATASET"
          value = var.bigquery_dataset
        }
        
        env {
          name  = "FEAST_ARTIFACT_BUCKET"
          value = var.artifact_bucket
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
        
        ports {
          container_port = 8080
        }
        
        startup_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 60
          timeout_seconds = 5
          period_seconds = 10
          failure_threshold = 3
        }
        
        liveness_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 120
          timeout_seconds = 25
          period_seconds = 30
          failure_threshold = 3
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  
  depends_on = [
    google_project_service.feast_apis
  ]
}

resource "google_cloud_run_service_iam_member" "public" {
  count    = var.allow_public_access ? 1 : 0
  location = google_cloud_run_service.feast.location
  project  = google_cloud_run_service.feast.project
  service  = google_cloud_run_service.feast.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_project_service" "feast_apis" {
  for_each = toset([
    "run.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

resource "google_project_iam_member" "feast_storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "feast_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "feast_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "feast_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "feast_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "feast_artifact_access" {
  count  = var.artifact_bucket != "" ? 1 : 0
  bucket = var.artifact_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_bigquery_dataset" "feast_dataset" {
  count       = var.create_bigquery_dataset ? 1 : 0
  dataset_id  = var.bigquery_dataset
  project     = var.project_id
  location    = var.region
  
  description = "Feast offline store dataset"
  
  labels = {
    component  = "feast-offline-store"
    managed-by = "terraform"
  }
  
  lifecycle {
    ignore_changes = [dataset_id]
  }
}