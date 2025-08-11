data "google_project" "current" {}

resource "google_project_service" "feast_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# VM Service Account IAM permissions for FEAST
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
  count   = var.use_postgres ? 1 : 0
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
  
  description = "Feast offline store dataset for VM deployment"
  
  labels = {
    component  = "feast-offline-store"
    managed-by = "terraform"
    deployment = "vm"
  }
  
  lifecycle {
    ignore_changes = [dataset_id]
  }
}

# Output for VM startup script to use
resource "local_file" "feast_env_config" {
  content = templatefile("${path.module}/feast_env.tpl", {
    project_id              = var.project_id
    region                  = var.region
    use_postgres           = var.use_postgres
    backend_store_uri      = var.backend_store_uri
    postgres_host          = var.postgres_host
    postgres_port          = var.postgres_port
    postgres_database      = var.postgres_database
    postgres_user          = var.postgres_user
    postgres_password      = var.postgres_password
    bigquery_dataset       = var.bigquery_dataset
    artifact_bucket        = var.artifact_bucket
    feast_port            = var.feast_port
  })
  
  filename = "${path.module}/feast_environment.env"
  
  depends_on = [
    google_project_service.feast_apis
  ]
}