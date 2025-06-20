output "service_url" {
  description = "URL of the MLflow Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].status[0].url : ""
}

output "bucket_name" {
  description = "Name of the created storage bucket"
  value       = length(google_storage_bucket.artifact) > 0 ? google_storage_bucket.artifact[0].name : ""
}

output "bucket_url" {
  description = "URL of the created storage bucket"
  value       = length(google_storage_bucket.artifact) > 0 ? google_storage_bucket.artifact[0].url : ""
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].name : ""
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].location : ""
}