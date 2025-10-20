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

variable "create_service" {
  type = bool
  description = "Whether to create the wandb service"
  default = true
}

variable "create_bucket" {
  type = bool
  description = "Whether to create the artifact storage bucket"
  default = false
}

variable "service_name" {
  type = string
  description = "Name for the wandb service container"
  default = "wandb-server"
}

variable "vm_name" {
  type = string
  description = "Name for the VM instance"
  default = "wandb-vm"
}

variable "machine_type" {
  type = string
  description = "GCP machine type for the VM"
  default = "e2-medium"
}

variable "disk_size_gb" {
  type = number
  description = "Boot disk size in GB"
  default = 20
}

variable "disk_type" {
  type = string
  description = "Boot disk type"
  default = "pd-balanced"
}

variable "image_family" {
  type = string
  description = "VM image family"
  default = "debian-cloud/debian-11"
}

variable "artifact_bucket" {
    type = string
    description = "GCS bucket for storing wandb artifacts"
    default = ""
}

variable "allow_public_access" {
  type = bool
  description = "Whether to allow public access to wandb UI"
  default = true
}

variable "wandb_port" {
  type = number
  description = "Port for wandb server"
  default = 8080
}

variable "service_account_email" {
  type = string
  description = "Custom service account email (optional)"
  default = ""
}

variable "network" {
  type = string
  description = "VPC network name"
  default = "default"
}

variable "subnetwork" {
  type = string
  description = "VPC subnetwork name"
  default = ""
}

variable "allow_http_https" {
  type = bool
  description = "Allow HTTP/HTTPS traffic"
  default = true
}

variable "tags" {
  type = list(string)
  description = "Network tags for the VM"
  default = ["wandb-server", "http-server", "https-server"]
}

variable "metadata" {
  type = map(string)
  description = "Additional metadata for the VM"
  default = {}
}

variable "startup_script" {
  type = string
  description = "Custom startup script (optional, overrides default)"
  default = ""
} 

# New: VM user management
variable "vm_user" {
  type        = string
  description = "Linux username to create and use for deployment"
  default     = ""
}

variable "grant_sudo" {
  type        = bool
  description = "Whether to grant passwordless sudo to vm_user"
  default     = true
}