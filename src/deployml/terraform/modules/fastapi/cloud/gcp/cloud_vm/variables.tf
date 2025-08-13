# FastAPI VM Module Variables

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

variable "zone" {
  type        = string
  description = "The GCP zone to deploy the VM in"
}

# VM Configuration
variable "vm_name" {
  type        = string
  description = "Name for the FastAPI VM instance"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type for the VM"
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GB"
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Boot disk type"
  default     = "pd-balanced"
}

variable "image_family" {
  type        = string
  description = "VM image family"
  default     = "debian-cloud/debian-12"
}

# FastAPI Configuration
variable "fastapi_port" {
  type        = number
  description = "Port for FastAPI server"
  default     = 8000
}

variable "fastapi_app_source" {
  type        = string
  description = "Source for FastAPI application (template, gs://bucket/path.py, or /local/path.py)"
  default     = "template"
}

# Access Control
variable "allow_public_access" {
  type        = bool
  description = "Whether to allow public access to the FastAPI service"
  default     = true
}

# MLflow Integration
variable "mlflow_tracking_uri" {
  type        = string
  description = "MLflow tracking URI for model integration"
  default     = ""
}

variable "model_uri" {
  type        = string
  description = "Model URI for MLflow model loading"
  default     = ""
}

variable "backend_store_uri" {
  type        = string
  description = "Backend store URI for MLflow"
  default     = ""
}

variable "use_postgres" {
  type        = bool
  description = "Whether to use PostgreSQL backend"
  default     = false
}

variable "db_connection_string" {
  type        = string
  description = "Database connection string"
  default     = ""
}

# Feast Integration
variable "feast_service_url" {
  type        = string
  description = "Feast service URL for feature store integration"
  default     = ""
}

variable "enable_feast_connection" {
  type        = bool
  description = "Whether to enable Feast connection"
  default     = false
}
