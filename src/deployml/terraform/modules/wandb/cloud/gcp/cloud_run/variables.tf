# modules/wandb/cloud/gcp/cloud_run/variables.tf

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
  description = "Whether to allow public access to the wandb service"
  default     = true
}

# Service configuration
variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service"
  default     = "wandb-server"
}

variable "image" {
  type        = string
  description = "Docker image URI for wandb server"
  default     = "gcr.io/mlops-intro-461805/wandb/wandb:latest"
}

# Storage configuration
variable "artifact_bucket" {
  type        = string
  description = "GCS bucket name for storing wandb artifacts"
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

variable "gcp_service_list" {
  description = "The list of APIs necessary for wandb with Cloud Run"
  type        = list(string)
  default = [
    "run.googleapis.com",                      # Cloud Run
    "iam.googleapis.com",                      # IAM
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "storage-api.googleapis.com",              # Google Cloud Storage
    "storage-component.googleapis.com",        # Storage component API
    "monitoring.googleapis.com",               # For monitoring
    "logging.googleapis.com",                  # For logging
  ]
}
