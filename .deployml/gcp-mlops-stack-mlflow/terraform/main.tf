
resource "google_storage_bucket" "mlflow_artifact" {
  name          = var.artifact_bucket
  location      = var.region
  force_destroy = true

  labels = {
    component  = "mlflow-artifacts"
    managed-by = "terraform"
  }
}


provider "google" {
    
    project = var.project_id
    region = var.region
    
}

# Detect if PostgreSQL is needed


  
    
  

  
    
  

  
    
      
    
  


# Create Cloud SQL PostgreSQL instance if needed

module "cloud_sql_postgres" {
  source = "./modules/mlflow/cloud/gcp/cloud_sql_postgres"
  project_id      = var.project_id
  region          = var.region
  db_instance_name = "mlflow-postgres--mlops-intro-461805"
  db_name         = "mlflow"
  db_user         = "mlflow"
}



  
module "experiment_tracking_mlflow" {
  source = "./modules/mlflow/cloud/gcp/cloud_run"
  count  = var.enable_experiment_tracking_mlflow ? 1 : 0
  
  project_id = var.project_id
  region     = var.region
  
  # Control what gets created based on the module purpose
  create_service = true
  allow_public_access = var.allow_public_access
  
  # Resource configuration
  cpu_limit = var.cpu_limit
  memory_limit = var.memory_limit
  cpu_request = var.cpu_request
  memory_request = var.memory_request
  max_scale = var.max_scale
  container_concurrency = var.container_concurrency
  
  # Always pass artifact_bucket to all modules (needed for env vars)
  artifact_bucket = google_storage_bucket.mlflow_artifact.name
  
  backend_store_uri = module.cloud_sql_postgres.connection_string
  cloudsql_instance_annotation = module.cloud_sql_postgres.instance_connection_name
  
  
      image = var.experiment_tracking_mlflow_image != "" ? var.experiment_tracking_mlflow_image : var.global_image
    
  
      service_name = var.service_name
    
  
  
  
}
  

  
module "artifact_tracking_mlflow" {
  source = "./modules/mlflow/cloud/gcp/cloud_run"
  count  = var.enable_artifact_tracking_mlflow ? 1 : 0
  
  project_id = var.project_id
  region     = var.region
  
  # Control what gets created based on the module purpose
  create_service = false
  allow_public_access = var.allow_public_access
  
  # Resource configuration
  cpu_limit = var.cpu_limit
  memory_limit = var.memory_limit
  cpu_request = var.cpu_request
  memory_request = var.memory_request
  max_scale = var.max_scale
  container_concurrency = var.container_concurrency
  
  # Always pass artifact_bucket to all modules (needed for env vars)
  artifact_bucket = google_storage_bucket.mlflow_artifact.name
  
  backend_store_uri = module.cloud_sql_postgres.connection_string
  cloudsql_instance_annotation = module.cloud_sql_postgres.instance_connection_name
  
  
      image = var.artifact_tracking_mlflow_image != "" ? var.artifact_tracking_mlflow_image : var.global_image
    
  
      # Skip - already handled above
    
  
  
}
  

  
module "model_registry_mlflow" {
  source = "./modules/mlflow/cloud/gcp/cloud_run"
  count  = var.enable_model_registry_mlflow ? 1 : 0
  
  project_id = var.project_id
  region     = var.region
  
  # Control what gets created based on the module purpose
  create_service = false
  allow_public_access = var.allow_public_access
  
  # Resource configuration
  cpu_limit = var.cpu_limit
  memory_limit = var.memory_limit
  cpu_request = var.cpu_request
  memory_request = var.memory_request
  max_scale = var.max_scale
  container_concurrency = var.container_concurrency
  
  # Always pass artifact_bucket to all modules (needed for env vars)
  artifact_bucket = google_storage_bucket.mlflow_artifact.name
  
  backend_store_uri = module.cloud_sql_postgres.connection_string
  cloudsql_instance_annotation = module.cloud_sql_postgres.instance_connection_name
  
  
      image = var.model_registry_mlflow_image != "" ? var.model_registry_mlflow_image : var.global_image
    
  
  
}
  



  
output "experiment_tracking_mlflow_url" {
  value = var.enable_experiment_tracking_mlflow && length(module.experiment_tracking_mlflow) > 0 ? module.experiment_tracking_mlflow[0].service_url : ""
}

output "experiment_tracking_mlflow_bucket" {
  value = var.enable_experiment_tracking_mlflow && length(module.experiment_tracking_mlflow) > 0 ? module.experiment_tracking_mlflow[0].bucket_name : ""
}
  

  
output "artifact_tracking_mlflow_url" {
  value = var.enable_artifact_tracking_mlflow && length(module.artifact_tracking_mlflow) > 0 ? module.artifact_tracking_mlflow[0].service_url : ""
}

output "artifact_tracking_mlflow_bucket" {
  value = var.enable_artifact_tracking_mlflow && length(module.artifact_tracking_mlflow) > 0 ? module.artifact_tracking_mlflow[0].bucket_name : ""
}
  

  
output "model_registry_mlflow_url" {
  value = var.enable_model_registry_mlflow && length(module.model_registry_mlflow) > 0 ? module.model_registry_mlflow[0].service_url : ""
}

output "model_registry_mlflow_bucket" {
  value = var.enable_model_registry_mlflow && length(module.model_registry_mlflow) > 0 ? module.model_registry_mlflow[0].bucket_name : ""
}
  



output "mlflow_artifact_bucket" {
  value = google_storage_bucket.mlflow_artifact.name
}



output "instance_connection_name" {
  value = module.cloud_sql_postgres.instance_connection_name
}
output "postgresql_credentials" {
  value = module.cloud_sql_postgres.postgresql_credentials
  sensitive = true
}

