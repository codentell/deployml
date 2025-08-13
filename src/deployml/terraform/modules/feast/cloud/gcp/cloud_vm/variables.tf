# Feast VM Module Variables

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
}

variable "zone" {
  type        = string
  description = "The GCP zone to deploy the VM in"
}

# VM Configuration
variable "vm_name" {
  type        = string
  description = "Name for the Feast VM instance"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type for the VM"
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GB"
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Boot disk type"
  default     = "pd-balanced"
}

variable "image_family" {
  type        = string
  description = "VM image family"
  default     = "debian-cloud/debian-12"
}

# Feast Configuration
variable "feast_port" {
  type        = number
  description = "Port for Feast server"
  default     = 6566
}

variable "registry_type" {
  type        = string
  description = "Feast registry type (sql or file)"
  default     = "file"
}

variable "online_store_type" {
  type        = string
  description = "Feast online store type (sqlite, postgres, datastore, bigtable)"
  default     = "sqlite"
}

variable "offline_store_type" {
  type        = string
  description = "Feast offline store type"
  default     = "bigquery"
}

# Database Configuration
variable "use_postgres" {
  type        = bool
  description = "Whether to use PostgreSQL backend"
  default     = false
}

variable "backend_store_uri" {
  type        = string
  description = "Feast backend store URI"
  default     = ""
}

variable "postgres_host" {
  type        = string
  description = "PostgreSQL host"
  default     = ""
}

variable "postgres_port" {
  type        = string
  description = "PostgreSQL port"
  default     = "5432"
}

variable "postgres_database" {
  type        = string
  description = "PostgreSQL database name"
  default     = ""
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL user"
  default     = ""
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL password"
  default     = ""
  sensitive   = true
}

# BigQuery Configuration
variable "bigquery_dataset" {
  type        = string
  description = "BigQuery dataset for Feast offline store"
  default     = "feast_offline_store"
}

variable "create_bigquery_dataset" {
  type        = bool
  description = "Whether to create the BigQuery dataset"
  default     = true
}

variable "sample_data" {
  type        = bool
  description = "Whether to create sample data tables"
  default     = false
}

# Artifact Storage (for compatibility)
variable "artifact_bucket" {
  type        = string
  description = "Artifact storage bucket (if any)"
  default     = ""
}