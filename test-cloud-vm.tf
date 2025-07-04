# Test configuration for cloud_vm module
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Google Cloud provider
provider "google" {
  project = "hatchet2"  # Replace with your actual project ID
  region  = "us-west1"
  zone    = "us-west1-c"  # Try different zone due to capacity
}

# Enable required Google Cloud APIs for fresh project
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",                    # Compute Engine (VMs, firewalls)
    "storage.googleapis.com",                    # Cloud Storage (artifact buckets)
    "serviceusage.googleapis.com",               # Service Usage (to enable other APIs)
    "cloudresourcemanager.googleapis.com",      # Cloud Resource Manager (project operations)
    "iam.googleapis.com",                        # Identity and Access Management
    "iamcredentials.googleapis.com",             # Service Account Credentials
    "logging.googleapis.com",                    # Cloud Logging (for VM logs)
    "monitoring.googleapis.com"                  # Cloud Monitoring (optional but useful)
  ])
  
      project = "hatchet2"
  service = each.value
  
  disable_on_destroy = false  # Keep APIs enabled for safety
}

# Wait for API enablement to propagate
resource "time_sleep" "wait_for_api_propagation" {
  depends_on = [
    google_project_service.required_apis
  ]
  
  create_duration = "180s"  # Wait 3 minutes for API propagation
  
  triggers = {
    # Force recreation when APIs change
    apis = join(",", [for k, v in google_project_service.required_apis : v.service])
  }
}

# Verify APIs are ready before proceeding
resource "null_resource" "api_readiness_check" {
  depends_on = [time_sleep.wait_for_api_propagation]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying Compute Engine API is ready..."
      for i in {1..5}; do
        if gcloud compute zones list --project=hatchet2 --limit=1 --format="value(name)" 2>/dev/null | grep -q .; then
          echo "✅ Compute Engine API is ready!"
          exit 0
        else
          echo "⏳ Attempt $i: API still propagating, waiting 30s..."
          sleep 30
        fi
      done
      echo "❌ API readiness check failed, but continuing..."
      exit 0
    EOT
  }
}

# Test the cloud_vm module - explicitly depends on API readiness
module "test_mlflow_vm" {
  source = "./src/deployml/terraform/modules/mlflow/cloud/gcp/cloud_vm"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [null_resource.api_readiness_check]
  
  # Required variables
  project_id = "hatchet2"  # Your actual project ID
  region     = "us-west1"
  zone       = "us-west1-c"  # Override module default to avoid capacity issues
  
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
  artifact_bucket = "deployml-mlflow-storage-${random_id.bucket_suffix.hex}"
  
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