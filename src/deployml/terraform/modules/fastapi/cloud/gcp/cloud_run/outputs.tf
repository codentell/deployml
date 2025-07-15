output "service_url" {
  description = "URL of the FastAPI Cloud Run service"
  value       = google_cloud_run_service.fastapi.status[0].url
} 