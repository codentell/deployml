output "service_url" {
  description = "URL of the MLflow Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].status[0].url : ""
}

output "bucket_name" {
  description = "Name of the artifact storage bucket (provided or external)"
  value       = var.artifact_bucket
}

output "bucket_url" {
  description = "URL of the artifact storage bucket (provided or external)"
  value       = var.artifact_bucket != "" ? "gs://${var.artifact_bucket}" : ""
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].name : ""
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = length(google_cloud_run_service.mlflow) > 0 ? google_cloud_run_service.mlflow[0].location : ""
}