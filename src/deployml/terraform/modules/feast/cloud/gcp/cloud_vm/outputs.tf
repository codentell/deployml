output "bigquery_dataset" {
  value = var.create_bigquery_dataset ? google_bigquery_dataset.feast_dataset[0].dataset_id : var.bigquery_dataset
}

output "feast_registry_uri" {
  value = var.backend_store_uri
}

output "feast_online_store_config" {
  value = var.use_postgres ? {
    type     = "postgres"
    host     = var.postgres_host
    port     = var.postgres_port
    database = var.postgres_database
    user     = var.postgres_user
  } : {
    type = "sqlite"
    path = "data/online_store.db"
  }
  sensitive = true
}

output "feast_offline_store_config" {
  value = {
    type    = "bigquery"
    project = var.project_id
    dataset = var.bigquery_dataset
  }
}

output "bucket_name" {
  value = var.artifact_bucket
}

output "feast_environment_file" {
  value = local_file.feast_env_config.filename
}

output "feast_port" {
  value = var.feast_port
}

output "feast_database_info" {
  description = "FEAST database configuration information"
  value = {
    database_name = var.feast_database_name
    database_user = var.feast_database_user
    separate_database = var.feast_separate_database
    postgres_host = var.postgres_host
    postgres_database = var.postgres_database
    postgres_user = var.postgres_user
    use_postgres = var.use_postgres
  }
}