variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

variable "service_name" {
  type        = string
  description = "Name of the Feast Cloud Run service"
}

variable "image" {
  type        = string
  description = "Docker image URI for Feast service"
}

variable "backend_store_uri" {
  type        = string
  description = "PostgreSQL connection string for Feast registry"
}

variable "postgres_host" {
  type        = string
  description = "PostgreSQL host for online store"
}

variable "postgres_port" {
  type        = string
  description = "PostgreSQL port for online store"
  default     = "5432"
}

variable "postgres_database" {
  type        = string
  description = "PostgreSQL database name for online store"
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL username for online store"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL password for online store"
  sensitive   = true
}

variable "bigquery_dataset" {
  type        = string
  description = "BigQuery dataset name for offline store"
  default     = "feast_offline_store"
}

variable "create_bigquery_dataset" {
  type        = bool
  description = "Whether to create the BigQuery dataset"
  default     = true
}

variable "artifact_bucket" {
  type        = string
  description = "GCS bucket name for Feast artifacts"
}

variable "cpu_limit" {
  type        = string
  description = "CPU limit for the container"
  default     = "1000m"
}

variable "memory_limit" {
  type        = string
  description = "Memory limit for the container"
  default     = "1Gi"
}

variable "cpu_request" {
  type        = string
  description = "CPU request for the container"
  default     = "500m"
}

variable "memory_request" {
  type        = string
  description = "Memory request for the container"
  default     = "512Mi"
}

variable "max_scale" {
  type        = string
  description = "Maximum number of instances"
  default     = "10"
}

variable "container_concurrency" {
  type        = string
  description = "Maximum number of concurrent requests per container"
  default     = "100"
}

variable "allow_public_access" {
  type        = bool
  description = "Whether to allow public access to the Feast service"
  default     = true
}

variable "cloudsql_instance_annotation" {
  type        = string
  description = "Cloud SQL instance connection name annotation"
  default     = ""
}

variable "create_service" {
  type        = bool
  description = "Whether to create the Feast service"
  default     = true
}

variable "use_postgres" {
  type        = bool
  description = "Whether to use PostgreSQL backend"
  default     = true
}