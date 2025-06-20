variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "global_image" {
  description = "Fallback Docker image for all modules"
  type        = string
  default     = ""
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
  


# Database configuration
variable "db_type" {
  description = "Database type, e.g. mysql"
  type        = string
  default     = "mysql"
}

variable "db_user" {
  description = "Cloud SQL username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Cloud SQL password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_name" {
  description = "Cloud SQL database name"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Cloud SQL port"
  type        = string
  default     = "3306"
}

# Optional: Global control variables
variable "allow_public_access" {
  description = "Allow public access to MLflow services"
  type        = bool
  default     = true
}

variable "auto_approve" {
  description = "Auto-approve Terraform changes (use with caution)"
  type        = bool
  default     = false
}

# Resource configuration defaults
variable "cpu_limit" {
  description = "Default CPU limit for containers"
  type        = string
  default     = "2000m"
}

variable "memory_limit" {
  description = "Default memory limit for containers"
  type        = string
  default     = "2Gi"
}

variable "cpu_request" {
  description = "Default CPU request for containers"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Default memory request for containers"
  type        = string
  default     = "1Gi"
}

variable "max_scale" {
  description = "Maximum number of container instances"
  type        = number
  default     = 10
}

variable "container_concurrency" {
  description = "Maximum concurrent requests per container"
  type        = number
  default     = 80
}