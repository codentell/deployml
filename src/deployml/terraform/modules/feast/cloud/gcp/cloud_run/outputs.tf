output "service_url" {
  value = google_cloud_run_service.feast.status[0].url
}

output "service_name" {
  value = google_cloud_run_service.feast.name
}

output "service_location" {
  value = google_cloud_run_service.feast.location
}

output "service_project" {
  value = google_cloud_run_service.feast.project
}

output "bigquery_dataset" {
  value = var.bigquery_dataset
}

output "feast_registry_uri" {
  value = var.backend_store_uri
}

output "feast_online_store_config" {
  value = {
    type     = "postgres"
    host     = var.postgres_host
    port     = var.postgres_port
    database = var.postgres_database
    user     = var.postgres_user
  }
  sensitive = true
}

output "feast_offline_store_config" {
  value = {
    type    = "bigquery"
    project = var.bigquery_project != "" ? var.bigquery_project : var.project_id
    dataset = var.bigquery_dataset
  }
}

output "bucket_name" {
  value = var.artifact_bucket
}