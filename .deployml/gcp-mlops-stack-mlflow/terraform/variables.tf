variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

# --- Added static variables for Cloud Run deployment ---
variable "allow_public_access" {
  description = "Allow public access to Cloud Run"
  type        = bool
  default     = true
}

variable "auto_approve" {
  description = "Auto approve Terraform actions"
  type        = bool
  default     = false
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run"
  type        = string
  default     = "2000m"
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run"
  type        = string
  default     = "2Gi"
}

variable "cpu_request" {
  description = "CPU request for Cloud Run"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Memory request for Cloud Run"
  type        = string
  default     = "1Gi"
}

variable "max_scale" {
  description = "Max scale for Cloud Run"
  type        = number
  default     = 10
}

variable "container_concurrency" {
  description = "Container concurrency for Cloud Run"
  type        = number
  default     = 80
}

variable "global_image" {
  description = "Global image for MLflow"
  type        = string
  default     = ""
}

variable "db_type" {
  description = "Database type"
  type        = string
  default     = "postgresql"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "3306"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-medium"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "image_family" {
  description = "VM image family"
  type        = string
  default     = "cos-cloud/cos-121-lts"
}

variable "network" {
  description = "Network name"
  type        = string
  default     = "default"
}

variable "allow_http_https" {
  description = "Allow HTTP/HTTPS traffic"
  type        = bool
  default     = true
}

# Dynamic variables based on YAML config
  
    
      
      
variable "experiment_tracking_mlflow_image" {
  description = "Custom image for experiment_tracking_mlflow"
  type        = string
  default     = ""
}
      
    
      variable "service_name" {
  description = "Parameter service_name"
  type        = string
  default     = ""
}
      
    
      
      
    
      
      
    
  

  
    
      
      
variable "artifact_tracking_mlflow_image" {
  description = "Custom image for artifact_tracking_mlflow"
  type        = string
  default     = ""
}
      
    
      variable "artifact_bucket" {
  description = "Parameter artifact_bucket"
  type        = string
  default     = ""
}
      
    
      
      
    
  

  
    
      
      
variable "model_registry_mlflow_image" {
  description = "Custom image for model_registry_mlflow"
  type        = string
  default     = ""
}
      
    
      variable "backend_store_uri" {
  description = "Parameter backend_store_uri"
  type        = string
  default     = ""
}
      
    
  


# Control variables for module behavior

  
variable "enable_experiment_tracking_mlflow" {
  description = "Enable/disable experiment_tracking_mlflow module"
  type        = bool
  default     = true
}
  

  
variable "enable_artifact_tracking_mlflow" {
  description = "Enable/disable artifact_tracking_mlflow module"
  type        = bool
  default     = true
}
  

  
variable "enable_model_registry_mlflow" {
  description = "Enable/disable model_registry_mlflow module"
  type        = bool
  default     = true
}
  


variable "create_artifact_bucket" {
  description = "Whether to create the artifact bucket (true) or use an existing one (false)"
  type        = bool
  default     = true
}