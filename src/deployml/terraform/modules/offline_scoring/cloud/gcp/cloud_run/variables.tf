# modules/offline_scoring/cloud/gcp/cloud_run/variables.tf

# Core GCP Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-west1"
}

variable "gcp_service_list" {
  description = "List of GCP services to enable"
  type        = list(string)
  default     = [
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    "bigquery.googleapis.com"
  ]
}

# Cloud Run Service Configuration
variable "create_service" {
  description = "Whether to create the Cloud Run service"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "image" {
  description = "Container image for the offline scoring service"
  type        = string
}

variable "cpu_limit" {
  description = "CPU limit for the Cloud Run service"
  type        = string
  default     = "2000m"
}

variable "memory_limit" {
  description = "Memory limit for the Cloud Run service"
  type        = string
  default     = "4Gi"
}

variable "cpu_request" {
  description = "CPU request for the Cloud Run service"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Memory request for the Cloud Run service"
  type        = string
  default     = "2Gi"
}

# Database Configuration
variable "database_url" {
  description = "PostgreSQL connection string for storing predictions (can be passed from cloud_sql_postgres module)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudsql_instance_annotation" {
  description = "Cloud SQL instance annotation for Cloud Run"
  type        = string
  default     = ""
}

# Feast Configuration
variable "bigquery_dataset" {
  description = "BigQuery dataset for Feast offline store"
  type        = string
  default     = "feast_housing"
}

# Optional MLflow Configuration
variable "mlflow_tracking_uri" {
  description = "MLflow tracking server URI (automatically passed from mlflow module if available)"
  type        = string
  default     = ""
}

variable "model_name" {
  description = "Name of the MLflow model to use for predictions"
  type        = string
  default     = ""
}

variable "model_stage" {
  description = "Stage of the MLflow model (Production, Staging, etc.)"
  type        = string
  default     = ""
}

# Optional Batch Processing Configuration
variable "batch_size" {
  description = "Number of records to process in each batch"
  type        = string
  default     = ""
}

variable "days_lookback" {
  description = "Number of days to look back for feature data"
  type        = string
  default     = ""
}

# Cron Scheduling Configuration
variable "enable_cron" {
  description = "Whether to enable cron scheduling"
  type        = bool
  default     = true
}

variable "cron_schedule" {
  description = "Cron schedule for offline scoring job (default: every Monday at 3 AM)"
  type        = string
  default     = "0 3 * * 1"
}

variable "time_zone" {
  description = "Time zone for the cron schedule"
  type        = string
  default     = "America/Los_Angeles"
}

# Access Control
variable "allow_public_access" {
  description = "Whether to allow public access to the Cloud Run service"
  type        = bool
  default     = false
}

# Feast Online Store Configuration (PostgreSQL)
variable "feast_online_store_host" {
  description = "PostgreSQL host for Feast online store"
  type        = string
  default     = ""
}

variable "feast_online_store_port" {
  description = "PostgreSQL port for Feast online store"
  type        = string
  default     = "5432"
}

variable "feast_online_store_database" {
  description = "PostgreSQL database name for Feast online store"
  type        = string
  default     = ""
}

variable "feast_online_store_user" {
  description = "PostgreSQL user for Feast online store"
  type        = string
  default     = ""
}

variable "feast_online_store_password" {
  description = "PostgreSQL password for Feast online store"
  type        = string
  default     = ""
  sensitive   = true
}

variable "feast_registry_path" {
  description = "Feast registry path (PostgreSQL connection string for registry)"
  type        = string
  default     = ""
  sensitive   = true
}