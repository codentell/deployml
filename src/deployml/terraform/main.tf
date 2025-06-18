


provider "google" {
    
    project = var.project_id
    region = var.region
    
    
}


module "mlflow" {
    source             = "./modules/mlflow/cloud/gcp/cloud_run"
    project_id         = var.project_id 
    region             = var.region 
    artifact_bucket    = var.artifact_bucket
    backend_store_uri  = var.backend_store_uri 
    image              = var.image 
}


output "mlflow_url" {
    value = module.mlflow.service_url
}