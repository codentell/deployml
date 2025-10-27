variable "project_id" {
    type = string
    description = "GCP project ID"
}

variable "region" {
    type = string
    description = "GCP region for deployment"
    default = "us-west1"
}

variable "zone" {
  description = "The GCP zone to deploy the VM in"
  type        = string
  default     = "us-west1-a"
}

variable "create_service" {
  type = bool
  description = "Whether to create the MLflow service"
  default = true
}

variable "create_bucket" {
  type = bool
  description = "Whether to create the artifact storage bucket"
  default = false
}

variable "service_name" {
  type = string
  description = "Name for the MLflow service container"
  default = "mlflow-server"
}

variable "vm_name" {
  type = string
  description = "Name for the VM instance"
  default = "mlflow-vm"
}

variable "machine_type" {
  type = string
  description = "GCP machine type for the VM"
  default = "e2-medium"
}

variable "disk_size_gb" {
  type = number
  description = "Boot disk size in GB"
  default = 20
}

variable "disk_type" {
  type = string
  description = "Boot disk type"
  default = "pd-balanced"
}

variable "image_family" {
  type = string
  description = "VM image family"
  default = "debian-cloud/debian-11"
}

variable "artifact_bucket" {
    type = string
    description = "GCS bucket for storing MLflow artifacts"
    default = ""
}

variable "backend_store_uri" {
    type = string
    description = "URI for MLflow backend store"
    default = ""
}

variable "image" {
    type = string
    description = "Docker image URI for MLflow server (optional - if empty, MLflow will be installed locally on the VM)"
    default = ""
}

variable "allow_public_access" {
  type = bool
  description = "Whether to allow public access to MLflow UI"
  default = true
}

variable "mlflow_port" {
  type = number
  description = "Port for MLflow server"
  default = 5000
}

variable "fastapi_port" {
  type = number
  description = "Port for FastAPI proxy server"
  default = 8000
}

variable "enable_https" {
  type = bool
  description = "Whether to enable HTTPS for MLflow"
  default = false
}

variable "service_account_email" {
  type = string
  description = "Custom service account email (optional)"
  default = ""
}

variable "network" {
  type = string
  description = "VPC network name"
  default = "default"
}

variable "subnetwork" {
  type = string
  description = "VPC subnetwork name"
  default = ""
}

variable "allow_http_https" {
  type = bool
  description = "Allow HTTP/HTTPS traffic"
  default = true
}

variable "use_postgres" {
  type = bool
  description = "Whether to use PostgreSQL backend"
  default = false
}

variable "cloudsql_instance_annotation" {
  type = string
  description = "Cloud SQL instance connection name"
  default = ""
}

variable "tags" {
  type = list(string)
  description = "Network tags for the VM"
  default = ["mlflow-server", "http-server", "https-server"]
}

variable "metadata" {
  type = map(string)
  description = "Additional metadata for the VM"
  default = {}
}

variable "startup_script" {
  type = string
  description = "Custom startup script (optional, overrides default)"
  default = ""
}

variable "fastapi_app_source" {
  type = string
  description = "Source location for FastAPI application main.py (GCS path, local file, or 'template' for default)"
  default = "template"
}

variable "api_dependency" {
  type = string
  description = "Dependency trigger to ensure APIs are ready before creating resources"
  default = ""
}

variable "enable_grafana" {
  type = bool
  description = "Whether to enable Grafana monitoring service"
  default = false
}

variable "grafana_port" {
  type = number
  description = "Port for Grafana server"
  default = 3000
}

variable "grafana_admin_user" {
  type = string
  description = "Admin username for Grafana"
  default = "admin"
}

variable "grafana_admin_password" {
  type = string
  description = "Admin password for Grafana"
  default = "admin"
}

# New: VM user management
variable "vm_user" {
  type        = string
  description = "Linux username to create and use for deployment (e.g., 'skier')"
  default     = ""
}

variable "grant_sudo" {
  type        = bool
  description = "Whether to grant passwordless sudo to vm_user via /etc/sudoers.d"
  default     = true
}

