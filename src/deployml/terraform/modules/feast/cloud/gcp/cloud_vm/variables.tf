variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

variable "backend_store_uri" {
  type        = string
  description = "Backend store URI for Feast registry (PostgreSQL or SQLite)"
}

variable "postgres_host" {
  type        = string
  description = "PostgreSQL host for online store"
  default     = ""
}

variable "postgres_port" {
  type        = string
  description = "PostgreSQL port for online store"
  default     = "5432"
}

variable "postgres_database" {
  type        = string
  description = "PostgreSQL database name for online store"
  default     = ""
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL username for online store"
  default     = ""
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL password for online store"
  sensitive   = true
  default     = ""
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

variable "use_postgres" {
  type        = bool
  description = "Whether to use PostgreSQL backend"
  default     = false
}

variable "feast_port" {
  type        = number
  description = "Port for Feast server"
  default     = 6566
}

# --- FEAST Database Configuration ---
variable "feast_database_name" {
  type        = string
  description = "Name of the FEAST database"
  default     = "feast"
}

variable "feast_database_user" {
  type        = string
  description = "Name of the FEAST database user"
  default     = "feast"
}

variable "feast_separate_database" {
  type        = bool
  description = "Whether to use a separate database for FEAST"
  default     = true
}