# modules/cron/cloud/gcp/cloud_run/outputs.tf

output "job_names" {
  description = "Names of the created Cloud Run jobs"
  value       = [for job in google_cloud_run_v2_job.scheduled_jobs : job.name]
}

output "job_urls" {
  description = "URLs of the created Cloud Run jobs"
  value       = { for key, job in google_cloud_run_v2_job.scheduled_jobs : key => "https://console.cloud.google.com/run/jobs/details/${job.location}/${job.name}" }
}

output "scheduler_job_names" {
  description = "Names of the created Cloud Scheduler jobs"
  value       = [for job in google_cloud_scheduler_job.scheduled_cron_jobs : job.name]
}

output "scheduler_job_schedules" {
  description = "Schedules of the created Cloud Scheduler jobs"
  value       = { for key, job in google_cloud_scheduler_job.scheduled_cron_jobs : key => job.schedule }
}

output "service_account_email" {
  description = "Service account email used by the jobs"
  value       = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

output "jobs_summary" {
  description = "Summary of all created jobs"
  value = { for key, job in var.jobs : key => {
    service_name    = job.service_name
    image          = job.image
    cron_schedule  = job.cron_schedule
    bigquery_dataset = try(job.bigquery_dataset, "")
    job_url        = "https://console.cloud.google.com/run/jobs/details/${try(google_cloud_run_v2_job.scheduled_jobs[job.service_name].location, "")}/${try(google_cloud_run_v2_job.scheduled_jobs[job.service_name].name, "")}"
    scheduler_name = try(google_cloud_scheduler_job.scheduled_cron_jobs[job.service_name].name, "")
  }}
}