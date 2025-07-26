output "service_url" {
  description = "URL of the FastAPI Cloud Run service"
  value       = google_cloud_run_service.fastapi.status[0].url
}

output "service_name" {
  description = "Name of the FastAPI Cloud Run service"
  value       = google_cloud_run_service.fastapi.name
}

output "service_location" {
  description = "Location of the FastAPI Cloud Run service"
  value       = google_cloud_run_service.fastapi.location
} 