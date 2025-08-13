# Feast VM Module Outputs

output "vm_external_ip" {
  description = "External IP address of the Feast VM"
  value       = google_compute_instance.feast_vm.network_interface[0].access_config[0].nat_ip
}

output "feast_url" {
  description = "URL to access Feast server"
  value       = "http://${google_compute_instance.feast_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}"
}

output "feast_health_url" {
  description = "URL to check Feast health status"
  value       = "http://${google_compute_instance.feast_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}/health"
}

output "feast_grpc_url" {
  description = "Feast gRPC endpoint (for gRPC clients)"
  value       = "${google_compute_instance.feast_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}"
}

output "service_url" {
  description = "Service URL for Feast (alias for feast_url)"
  value       = "http://${google_compute_instance.feast_vm.network_interface[0].access_config[0].nat_ip}:${var.feast_port}"
}

output "vm_name" {
  description = "Name of the created VM instance"
  value       = google_compute_instance.feast_vm.name
}

output "zone" {
  description = "Zone where the VM is deployed"
  value       = google_compute_instance.feast_vm.zone
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh ${google_compute_instance.feast_vm.name} --zone=${google_compute_instance.feast_vm.zone}"
}

output "service_account_email" {
  description = "Email of the created service account"
  value       = google_service_account.feast_vm_sa.email
}

output "bigquery_dataset" {
  description = "BigQuery dataset for Feast offline store"
  value       = var.create_bigquery_dataset ? google_bigquery_dataset.feast_offline_store[0].dataset_id : var.bigquery_dataset
}

output "feast_deployment_info" {
  description = "Feast deployment configuration and information"
  value = {
    container_name = "feast-server"
    port = var.feast_port
    database = var.use_postgres ? var.postgres_database : "sqlite"
    database_user = var.use_postgres ? var.postgres_user : "sqlite"
    registry_type = var.registry_type
    online_store_type = var.online_store_type
    offline_store_type = var.offline_store_type
    offline_dataset = var.bigquery_dataset
    deployment_type = "vm"
  }
}