# FastAPI VM Module Outputs

output "vm_external_ip" {
  description = "External IP address of the FastAPI VM"
  value       = google_compute_instance.fastapi_vm.network_interface[0].access_config[0].nat_ip
}

output "fastapi_url" {
  description = "URL to access FastAPI server"
  value       = "http://${google_compute_instance.fastapi_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}"
}

output "fastapi_health_url" {
  description = "URL to check FastAPI health status"
  value       = "http://${google_compute_instance.fastapi_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}/health"
}

output "service_url" {
  description = "Service URL for FastAPI (alias for fastapi_url)"
  value       = "http://${google_compute_instance.fastapi_vm.network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}"
}

output "vm_name" {
  description = "Name of the created VM instance"
  value       = google_compute_instance.fastapi_vm.name
}

output "zone" {
  description = "Zone where the VM is deployed"
  value       = google_compute_instance.fastapi_vm.zone
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh ${google_compute_instance.fastapi_vm.name} --zone=${google_compute_instance.fastapi_vm.zone}"
}

output "service_account_email" {
  description = "Email of the created service account"
  value       = google_service_account.fastapi_vm_sa.email
}
