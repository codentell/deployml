variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

variable "db_instance_name" {
  type        = string
  description = "Name of the Cloud SQL instance"
  default     = "mlflow-postgres"
}

variable "db_name" {
  type        = string
  description = "Name of the database"
  default     = "mlflow"
}

variable "db_user" {
  type        = string
  description = "Database username"
  default     = "mlflow"
} 