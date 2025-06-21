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

variable "artifact_bucket" {
    type = string
    description = "GCS bucket for storing MLflow artifacts"
}

variable "backend_store_uri" {
    type = string
    description = "URI for MLflow backend store"
}

variable "image" {
    type = string
    description = "Docker image URI for MLflow server"
}

