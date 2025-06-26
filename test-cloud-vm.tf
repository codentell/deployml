# Test configuration for cloud_vm module
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Google Cloud provider
provider "google" {
  project = "mlopsresearch"  # Replace with your actual project ID
  region  = "us-west1"
  zone    = "us-west1-a"
}

# Test the cloud_vm module
module "test_mlflow_vm" {
  source = "./src/deployml/terraform/modules/mlflow/cloud/gcp/cloud_vm"
  
  # Required variables
  project_id = "mlopsresearch"  # Replace with your actual project ID
  
  # VM configuration
  vm_name      = "test-mlflow-vm"
  machine_type = "e2-medium"
  disk_size_gb = 20
  
  # Service configuration
  create_service = true
  service_name   = "test-mlflow-server"
  
  # MLflow configuration - VM will build/run MLflow locally
  image = ""  # Leave empty - VM will handle MLflow setup
  
  # Storage configuration
  create_bucket   = true
  artifact_bucket = "test-mlflow-artifacts-${random_id.bucket_suffix.hex}"
  
  # Backend store (using SQLite for testing)
  backend_store_uri = "sqlite:///mlflow.db"
  
  # Networking
  allow_public_access = true
  mlflow_port        = 5000
  
  # Optional: Custom metadata
  metadata = {
    environment = "test"
    owner       = "deployml"
  }
}

# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Outputs for testing
output "test_vm_external_ip" {
  description = "External IP of the test VM"
  value       = module.test_mlflow_vm.vm_external_ip
}

output "test_mlflow_url" {
  description = "URL to access test MLflow UI"
  value       = module.test_mlflow_vm.mlflow_url
}

output "test_bucket_name" {
  description = "Name of the test artifact bucket"
  value       = module.test_mlflow_vm.bucket_name
}

output "test_ssh_command" {
  description = "SSH command to connect to test VM"
  value       = module.test_mlflow_vm.ssh_command
} 