# MLflow VM Module Outputs

output "vm_external_ip" {
  description = "External IP address of the MLflow VM"
  value       = google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip
}

output "mlflow_url" {
  description = "URL to access MLflow UI"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.mlflow_port}"
}

output "service_url" {
  description = "Service URL for MLflow (alias for mlflow_url)"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.mlflow_port}"
}

output "fastapi_url" {
  description = "URL to access FastAPI proxy"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}"
}

output "fastapi_health_url" {
  description = "URL to check FastAPI health status"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}/health"
}

output "container_info_url" {
  description = "URL to check container information"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}/container-info"
}

output "bucket_name" {
  description = "Name of the created artifact bucket"
  value       = var.create_bucket && var.artifact_bucket != "" ? google_storage_bucket.mlflow_artifact[0].name : ""
}

output "vm_name" {
  description = "Name of the created VM instance"
  value       = google_compute_instance.mlflow_vm.name
}

output "zone" {
  description = "Zone where the VM is deployed"
  value       = google_compute_instance.mlflow_vm.zone
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh ${google_compute_instance.mlflow_vm.name} --zone=${google_compute_instance.mlflow_vm.zone}"
}

output "docker_commands" {
  description = "Useful Docker commands for container management"
  value = {
    check_containers = "docker ps"
    mlflow_logs      = "docker logs mlflow-server"
    fastapi_logs     = "docker logs fastapi-proxy"
    restart_services = "docker compose restart"
    stop_services    = "docker compose down"
    start_services   = "docker compose up -d"
  }
}

output "service_account_email" {
  description = "Email of the created service account"
  value       = google_service_account.mlflow_vm_sa.email
}

# Feast Outputs (since Feast runs on the same VM)
output "feast_url" {
  description = "URL to access Feast server"
  value       = "http://${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}"
}

output "feast_grpc_url" {
  description = "Feast gRPC endpoint (for gRPC clients)"
  value       = "${google_compute_instance.mlflow_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}"
}

output "bigquery_dataset" {
  description = "BigQuery dataset for Feast offline store"
  value       = var.bigquery_dataset
}
