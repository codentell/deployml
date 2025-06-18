
variable "project_id" {
    type = string
    description = "GCP project ID"
}

variable "region" {
    type = string
    description = "Deployment region"
}

variable "artifact_bucket" {
    type = string
    description = "Bucket for MLflow artifacts"
}

variable "backend_store_uri" {
    type = string
    description = "URI for MLflow backend store"
}

variable "image" {
    type = string
    description = "MLflow Docker image"
}
