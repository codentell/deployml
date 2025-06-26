# modules/mlflow/cloud/gcp/cloud_run/variables.tf

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

# Control what gets created
variable "create_service" {
  type        = bool
  description = "Whether to create the Cloud Run service"
  default     = true
}

variable "create_bucket" {
  type        = bool
  description = "Whether to create the storage bucket"
  default     = false
}

variable "allow_public_access" {
  type        = bool
  description = "Whether to allow public access to the MLflow service"
  default     = true
}

# Service configuration
variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service"
  default     = "mlflow-server"
}

variable "image" {
  type        = string
  description = "Docker image URI for MLflow server"
  default     = ""
}

# Storage configuration
variable "artifact_bucket" {
  type        = string
  description = "GCS bucket name for storing MLflow artifacts"
  default     = ""
}

# MLflow configuration
variable "backend_store_uri" {
  type        = string
  description = "URI for MLflow backend store (database)"
  default     = ""
}

# Resource configuration
variable "cpu_limit" {
  type        = string
  description = "CPU limit for the container"
  default     = "2000m"
}

variable "memory_limit" {
  type        = string
  description = "Memory limit for the container"
  default     = "2Gi"
}

variable "cpu_request" {
  type        = string
  description = "CPU request for the container"
  default     = "1000m"
}

variable "memory_request" {
  type        = string
  description = "Memory request for the container"
  default     = "1Gi"
}

variable "max_scale" {
  type        = number
  description = "Maximum number of container instances"
  default     = 10
}

variable "container_concurrency" {
  type        = number
  description = "Maximum number of concurrent requests per container"
  default     = 80
}

variable "bucket_exists" {
  type        = bool
  description = "Whether the artifact bucket already exists. If true, do not attempt to create it."
  default     = false
}

variable "cloudsql_instance_annotation" {
  type        = string
  default     = ""
  description = "Cloud SQL instance connection name for annotation."
}

variable "use_postgres" {
  type        = bool
  default     = false
  description = "Whether to use PostgreSQL (Cloud SQL) as the backend. If false, use SQLite."
}