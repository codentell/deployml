# modules/offline_scoring/cloud/gcp/cloud_run/outputs.tf

output "job_name" {
  description = "Name of the offline scoring Cloud Run job"
  value       = var.create_service && length(google_cloud_run_v2_job.offline_scoring) > 0 ? google_cloud_run_v2_job.offline_scoring[0].name : ""
}

output "job_location" {
  description = "Location of the offline scoring Cloud Run job"
  value       = var.create_service && length(google_cloud_run_v2_job.offline_scoring) > 0 ? google_cloud_run_v2_job.offline_scoring[0].location : ""
}

output "job_id" {
  description = "Full resource ID of the Cloud Run job"
  value       = var.create_service && length(google_cloud_run_v2_job.offline_scoring) > 0 ? google_cloud_run_v2_job.offline_scoring[0].id : ""
}

output "service_account_email" {
  description = "Email of the service account used by the offline scoring service"
  value       = var.create_service ? "${data.google_project.current.number}-compute@developer.gserviceaccount.com" : ""
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = var.create_service && var.enable_cron && length(google_cloud_scheduler_job.offline_scoring_cron) > 0 ? google_cloud_scheduler_job.offline_scoring_cron[0].name : ""
}

output "cron_schedule" {
  description = "Cron schedule for the offline scoring job"
  value       = var.cron_schedule
}

output "bigquery_dataset" {
  description = "BigQuery dataset used for feature store"
  value       = var.bigquery_dataset
}

output "model_configuration" {
  description = "MLflow model configuration"
  value = {
    model_name  = var.model_name
    model_stage = var.model_stage
    tracking_uri = var.mlflow_tracking_uri
  }
}