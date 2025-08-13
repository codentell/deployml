# MLflow VM Module Variables

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
  description = "Name for the VM instance"
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

# MLflow Configuration
variable "mlflow_port" {
  type        = number
  description = "Port for MLflow server"
  default     = 5000
}

variable "fastapi_port" {
  type        = number
  description = "Port for FastAPI proxy server"
  default     = 8000
}

variable "fastapi_app_source" {
  type        = string
  description = "Source for FastAPI application (template, gs://bucket/path.py, or /local/path.py)"
  default     = "template"
}

# Storage Configuration
variable "artifact_bucket" {
  type        = string
  description = "GCS bucket for storing MLflow artifacts"
  default     = ""
}

variable "create_bucket" {
  type        = bool
  description = "Whether to create the artifact storage bucket"
  default     = false
}

# Database Configuration
variable "use_postgres" {
  type        = bool
  description = "Whether to use PostgreSQL backend"
  default     = false
}

variable "db_password" {
  type        = string
  description = "Database password (if empty, will generate random password)"
  default     = ""
  sensitive   = true
}

variable "postgres_host" {
  type        = string
  description = "PostgreSQL host IP address"
  default     = ""
}

# Access Control
variable "allow_public_access" {
  type        = bool
  description = "Whether to allow public access to the services"
  default     = true
}

# Feast Configuration (integrated into MLflow VM)
variable "feast_port" {
  type        = number
  description = "Port for Feast server"
  default     = 6566
}

variable "registry_type" {
  type        = string
  description = "Feast registry type (sql or file)"
  default     = "file"
}

variable "online_store_type" {
  type        = string
  description = "Feast online store type (sqlite, postgres, datastore, bigtable)"
  default     = "sqlite"
}

variable "offline_store_type" {
  type        = string
  description = "Feast offline store type"
  default     = "bigquery"
}

variable "bigquery_dataset" {
  type        = string
  description = "BigQuery dataset for Feast offline store"
  default     = "feast_offline_store"
}

variable "create_bigquery_dataset" {
  type        = bool
  description = "Whether to create the BigQuery dataset"
  default     = true
}

variable "sample_data" {
  type        = bool
  description = "Whether to create sample data tables"
  default     = false
}

