project_id = "mlops-intro-461805"
region = "us-west1"
zone = "us-west1-a"
global_image = "gcr.io/mlops-intro-461805/mlflow/mlflow:latest"
allow_public_access = true
auto_approve = false

# Cloud Run specific defaults
cpu_limit = "2000m"
memory_limit = "2Gi"
cpu_request = "1000m"
memory_request = "1Gi"
max_scale = 10
container_concurrency = 80

# Database defaults
db_type = "postgresql" 
db_user = "mlflow"      # Set to match cloud_sql_postgres module
db_password = ""        # Auto-generated
db_name = "mlflow"      # Set to match cloud_sql_postgres module
db_port = "5432"        


  
    
    
      
experiment_tracking_mlflow_image = "gcr.io/mlops-intro-461805/mlflow/mlflow:latest"
      
    
      
service_name = "mlflow-server"
      
    
      
    
      
    
  

  
    
artifact_bucket = "model-bucket-mlops-intro-461805-w820"
    
    
      
artifact_tracking_mlflow_image = "gcr.io/mlops-intro-461805/mlflow/mlflow:latest"
      
    
      
    
      
    
  

  
    
    
      
model_registry_mlflow_image = "gcr.io/mlops-intro-461805/mlflow/mlflow:latest"
      
    
      
backend_store_uri = "postgresql"
      
    
  


create_artifact_bucket = true 