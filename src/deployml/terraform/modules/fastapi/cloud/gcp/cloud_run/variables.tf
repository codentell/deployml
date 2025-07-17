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
  description = "Name of the Cloud Run service"
}

variable "image" {
  type        = string
  description = "Docker image URI for FastAPI service"
}

variable "mlflow_tracking_uri" {
  type        = string
  description = "MLflow Tracking Server URI"
}

variable "model_uri" {
  type        = string
  description = "MLflow Model URI (can be registry or artifact path)"
  default     = "models:/MyModel/Production"
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

variable "allow_public_access" {
  type        = bool
  description = "Whether to allow public access to the FastAPI service"
  default     = true
}

variable "mlflow_artifact_bucket" {
  type        = string
  description = "MLflow artifact bucket name"
  default     = ""
} 