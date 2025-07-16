output "service_url" {
  description = "URL of the Grafana service"
  value       = google_cloud_run_service.grafana.status[0].url
}