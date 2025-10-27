# Enable required Google Cloud APIs first
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",                   # Compute Engine (VMs, disks, networks)
    "storage.googleapis.com",                   # Cloud Storage (artifact buckets)
    "iam.googleapis.com",                       # Identity and Access Management
    "iamcredentials.googleapis.com",            # IAM Service Account Credentials
    "logging.googleapis.com",                   # Cloud Logging
    "monitoring.googleapis.com",                # Cloud Monitoring
    "serviceusage.googleapis.com",              # Service Usage (for enabling APIs)
    "cloudresourcemanager.googleapis.com",     # Cloud Resource Manager (project operations)
  ])

  project = var.project_id
  service = each.value

  # Keep APIs enabled when destroying resources
  disable_on_destroy = false
}

# Wait for API propagation (critical for fresh projects)
resource "time_sleep" "wait_for_api_propagation" {
  depends_on = [
    google_project_service.required_apis
  ]

  create_duration = "120s"  # 2 minutes for API propagation
}

# Storage bucket - only create if explicitly requested
resource "google_storage_bucket" "artifact" {
  count         = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  name          = var.artifact_bucket
  location      = var.region
  force_destroy = true
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]
  
  labels = {
    component = "mlflow-artifacts"
    managed-by = "terraform"
  }
}

# Create a service account for the VM (optional, but recommended for granular permissions)
resource "google_service_account" "vm_service_account" {
  account_id   = "mlflow-vm-sa"
  display_name = "Service Account for MLflow VM"
  project      = var.project_id
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]
}

# Define a Google Compute Engine instance
resource "google_compute_instance" "mlflow_vm" {
  count        = var.create_service ? 1 : 0
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Debian 11 (Bullseye) - stable and compatible with apt-key
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null
    access_config {
      # This block creates an ephemeral external IP address
    }
  }

  # Service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"] # Grant access to Google Cloud APIs
  }

  # Startup script to install Docker and deploy MLflow
  metadata = merge(var.metadata, {
    startup-script = var.startup_script != "" ? var.startup_script : local.default_startup_script
  })

  tags = concat(var.tags, ["ssh-server", "mlflow-server", "http-server", "https-server", "lb-health-check"]) 

  can_ip_forward = true

  # Allow stopping for update
  allow_stopping_for_update = true
}

# Local variables for startup script
locals {
  default_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    echo "Starting MLflow VM setup..."
    
    # Log all output to a file for debugging
    exec > >(tee /var/log/mlflow-startup.log) 2>&1
    
    echo "$(date): Starting MLflow VM setup..."
    
    # Configure target VM user from Terraform variable or auto-detect
    TARGET_USER="${var.vm_user}"
    if [ -z "$TARGET_USER" ]; then
      echo "Auto-detecting deploy user..."
      # Try metadata legacy SSH keys (format: username:ssh-rsa ...)
      META_SSH=$(curl -sf -H "Metadata-Flavor: Google" \
        http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-keys || true)
      if [ -n "$META_SSH" ]; then
        TARGET_USER=$(echo "$META_SSH" | head -n1 | cut -d: -f1)
        echo "Detected user from metadata ssh-keys: $TARGET_USER"
      fi
      # Fallback: use first non-root user under /home
      if [ -z "$TARGET_USER" ]; then
        CANDIDATE=$(ls -1 /home 2>/dev/null | grep -v '^root$' | head -n1 || true)
        if [ -n "$CANDIDATE" ] && getent passwd "$CANDIDATE" >/dev/null 2>&1; then
          TARGET_USER="$CANDIDATE"
          echo "Detected user from /home: $TARGET_USER"
        fi
      fi
      # Final fallback: create a dedicated deploy user
      if [ -z "$TARGET_USER" ]; then
        TARGET_USER="deployml"
        echo "No user detected, defaulting to: $TARGET_USER"
      fi
    fi
    echo "Target VM user: $TARGET_USER"
    
    # Ensure the user exists with a home directory and bash shell
    if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
      echo "Creating user: $TARGET_USER"
      useradd -m -s /bin/bash "$TARGET_USER"
    else
      echo "User $TARGET_USER already exists"
    fi
    
    # Ensure sudo is available and optionally grant passwordless sudo
    apt-get update -y
    apt-get install -y sudo >/dev/null 2>&1 || true
    usermod -aG sudo "$TARGET_USER" || true
    if [ "${var.grant_sudo}" = "true" ]; then
      echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$TARGET_USER
      chmod 440 /etc/sudoers.d/90-$TARGET_USER
      echo "Granted passwordless sudo to $TARGET_USER"
    else
      echo "Passwordless sudo not granted to $TARGET_USER (grant_sudo=false)"
    fi
    
    # Update system packages
    echo "Updating system packages..."
    sudo apt-get update -y
    
    # Install necessary packages for Docker and Python
    echo "Installing dependencies..."
    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release \
      software-properties-common \
      python3 \
      python3-pip \
      python3-venv \
      python3-dev \
      build-essential \
      git \
      wget \
      unzip
    
    # Verify Python and pip are available
    echo "Verifying Python installation..."
    python3 --version
    pip3 --version
    
    # Add Docker's official GPG key
    echo "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up Docker repository
    echo "Setting up Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update packages and install Docker
    echo "Installing Docker..."
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    echo "Starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Add current user to docker group
    echo "Configuring Docker permissions for user: $TARGET_USER"
    sudo usermod -aG docker $TARGET_USER
    
    # Wait for Docker to be ready
    echo "Waiting for Docker to be ready..."
    sleep 10
    
    # Test Docker installation
    echo "Testing Docker installation..."
    sudo docker run --rm hello-world
    
    # Set up containerized MLflow environment
    echo "Setting up containerized MLflow environment..."
    
    # Create deployment directory structure
    mkdir -p /home/$TARGET_USER/deployml/docker
    mkdir -p /home/$TARGET_USER/deployml/docker/mlflow
    mkdir -p /home/$TARGET_USER/deployml/docker/fastapi
    
    # Create Docker Compose file
    echo "Creating Docker Compose configuration..."
    cat > /home/$TARGET_USER/deployml/docker/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
  mlflow:
    build: 
      context: ./mlflow
      dockerfile: Dockerfile
    container_name: mlflow-server
    ports:
      - "5000:5000"
    environment:
      - MLFLOW_BACKEND_STORE_URI=${var.backend_store_uri}
      - MLFLOW_DEFAULT_ARTIFACT_ROOT=${var.artifact_bucket != "" ? "gs://${var.artifact_bucket}" : "./mlflow-artifacts"}
      - MLFLOW_SERVER_HOST=0.0.0.0
      - MLFLOW_SERVER_PORT=5000
    volumes:
      - mlflow-data:/app/mlflow-data
      - mlflow-config:/app/mlflow-config
    networks:
      - mlflow-network
    restart: unless-stopped
    command: >
      mlflow server 
      --host 0.0.0.0 
      --port 5000
      --backend-store-uri ${var.backend_store_uri}
      --default-artifact-root ${var.artifact_bucket != "" ? "gs://${var.artifact_bucket}" : "./mlflow-artifacts"}
    
  fastapi:
    build:
      context: ./fastapi
      dockerfile: Dockerfile
    container_name: fastapi-proxy
    ports:
      - "${var.fastapi_port}:8000"
    environment:
      - MLFLOW_BASE_URL=http://mlflow:5000
      - FASTAPI_PORT=8000
    depends_on:
      - mlflow
    networks:
      - mlflow-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-server
    ports:
      - "${var.enable_grafana ? var.grafana_port : "3000"}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}
      - GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana-data:/var/lib/grafana
      - grafana-config:/etc/grafana
      - grafana-logs:/var/log/grafana
    networks:
      - mlflow-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  mlflow-data:
  mlflow-config:
  grafana-data:
  grafana-config:
  grafana-logs:

networks:
  mlflow-network:
    driver: bridge
DOCKER_COMPOSE_EOF

    # Create MLflow Dockerfile
    cat > /home/$TARGET_USER/deployml/docker/mlflow/Dockerfile << 'MLFLOW_DOCKERFILE_EOF'
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install MLflow and dependencies
RUN pip install \
    mlflow[extras] \
    sqlalchemy \
    psycopg2-binary \
    google-cloud-storage \
    boto3

# Create mlflow user
RUN useradd -m -s /bin/bash mlflow

# Create directories
RUN mkdir -p /app/mlflow-data /app/mlflow-config
RUN chown -R mlflow:mlflow /app

# Switch to mlflow user
USER mlflow

# Expose MLflow port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Default command
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
MLFLOW_DOCKERFILE_EOF

    # Create FastAPI Dockerfile
    echo "Creating FastAPI Dockerfile..."
    cat > /home/$TARGET_USER/deployml/docker/fastapi/Dockerfile << 'FASTAPI_DOCKERFILE_EOF'
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install FastAPI and dependencies
RUN pip install \
    fastapi \
    uvicorn \
    httpx \
    mlflow \
    pandas \
    joblib \
    scikit-learn \
    numpy

# Create fastapi user
RUN useradd -m -s /bin/bash fastapi

# Create app directory
RUN mkdir -p /app/fastapi-app
RUN chown -R fastapi:fastapi /app

# Copy FastAPI application
COPY main.py /app/fastapi-app/main.py

# Switch to fastapi user
USER fastapi

# Expose FastAPI port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["uvicorn", "fastapi-app.main:app", "--host", "0.0.0.0", "--port", "8000"]
FASTAPI_DOCKERFILE_EOF
    

    
    # Setup FastAPI application
    echo "Setting up FastAPI application..."
    FASTAPI_SOURCE="${var.fastapi_app_source}"
    
    if [ "$FASTAPI_SOURCE" = "template" ]; then
        echo "Using default containerized FastAPI template..."
        # Create a containerized FastAPI application with MLflow proxy and model integration
        cat > /home/$TARGET_USER/deployml/docker/fastapi/main.py << 'FASTAPI_TEMPLATE_EOF'
from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import os
from contextlib import asynccontextmanager
import logging
import asyncio
import mlflow
import pandas as pd
from datetime import datetime
from typing import Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MLflow configuration - use container name for inter-container communication
MLFLOW_BASE_URL = os.getenv("MLFLOW_BASE_URL", "http://mlflow:5000")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))

# Global variables for model
model = None
feature_names = None
model_info = {
    "name": None,
    "version": None,
    "loaded_at": None,
    "last_checked": None,
    "status": "not_loaded"
}

# Configuration for model refresh
MODEL_CHECK_INTERVAL = int(os.getenv("MODEL_CHECK_INTERVAL", "300"))  # 5 minutes default
AUTO_REFRESH_ENABLED = os.getenv("AUTO_REFRESH_ENABLED", "true").lower() == "true"

# Pydantic model for prediction request
class PredictionRequest(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

async def load_mlflow_model() -> bool:
    """Load or reload the MLflow model. Returns True if successful."""
    global model, feature_names, model_info
    
    try:
        logger.info("Loading/refreshing MLflow model...")
        model_name = os.getenv("MODEL_NAME", "best_iris_model")
        mlflow_tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db")
        experiment_name = os.getenv("EXPERIMENT_NAME", "iris_experiment")
        
        mlflow.set_tracking_uri(mlflow_tracking_uri)
        mlflow.set_experiment(experiment_name)
        
        # Get model info first
        client = mlflow.tracking.MlflowClient()
        try:
            latest_version = client.get_latest_versions(model_name, stages=["None", "Staging", "Production"])
            if latest_version:
                # Get the latest version (highest version number)
                latest_model = max(latest_version, key=lambda x: int(x.version))
                model_version = latest_model.version
                
                # Check if this is a new version
                if model_info["version"] == model_version and model is not None:
                    logger.info(f"Model version {model_version} already loaded, skipping refresh")
                    model_info["last_checked"] = datetime.now().isoformat()
                    return True
                
                logger.info(f"Loading model version: {model_version}")
            else:
                logger.warning("No model versions found, trying latest anyway")
                model_version = "latest"
        except Exception as e:
            logger.warning(f"Could not get model version info: {e}, using 'latest'")
            model_version = "latest"
        
        model_uri = f"models:/{model_name}/latest"
        new_model = mlflow.pyfunc.load_model(model_uri)
        
        feature_names = [
            "sepal length",
            "sepal width", 
            "petal length",
            "petal width",
        ]
        
        # Update model and info atomically
        model = new_model
        model_info.update({
            "name": model_name,
            "version": model_version,
            "loaded_at": datetime.now().isoformat(),
            "last_checked": datetime.now().isoformat(),
            "status": "loaded"
        })
        
        logger.info(f"✅ Successfully loaded model: {model_name} (version: {model_version})")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to load MLflow model: {e}")
        model_info.update({
            "last_checked": datetime.now().isoformat(),
            "status": "error",
            "error": str(e)
        })
        return False

async def check_for_model_updates():
    """Background task to periodically check for model updates."""
    while True:
        try:
            if AUTO_REFRESH_ENABLED and model_info["status"] == "loaded":
                logger.info("Checking for model updates...")
                await load_mlflow_model()
            await asyncio.sleep(MODEL_CHECK_INTERVAL)
        except Exception as e:
            logger.error(f"Error in background model check: {e}")
            await asyncio.sleep(MODEL_CHECK_INTERVAL)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    logger.info("FastAPI MLflow Proxy starting...")
    logger.info(f"Proxying requests to MLflow at: {MLFLOW_BASE_URL}")
    logger.info(f"Auto-refresh enabled: {AUTO_REFRESH_ENABLED}, Check interval: {MODEL_CHECK_INTERVAL}s")
    
    # Wait for MLflow to be ready
    logger.info("Waiting for MLflow to be ready...")
    max_retries = 30
    for i in range(max_retries):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{MLFLOW_BASE_URL}/health", timeout=5.0)
                if response.status_code == 200:
                    logger.info("✅ MLflow is ready!")
                    break
        except Exception as e:
            logger.info(f"Waiting for MLflow... (attempt {i+1}/{max_retries})")
            if i == max_retries - 1:
                logger.error(f"❌ MLflow not ready after {max_retries} attempts: {e}")
            await asyncio.sleep(2)
    
    # Load MLflow model on startup
    await load_mlflow_model()
    
    # Start background task for model checking
    if AUTO_REFRESH_ENABLED:
        asyncio.create_task(check_for_model_updates())
    
    yield
    logger.info("FastAPI MLflow Proxy shutting down...")

# Create FastAPI application
app = FastAPI(
    title="MLflow Model API",
    description="Containerized FastAPI server with MLflow model integration for predictions and MLflow proxy",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", response_class=HTMLResponse)
async def root():
    """Root endpoint with links to available services"""
    model_status = "✅ Ready" if model is not None else "❌ Not Loaded"
    model_version = model_info.get("version", "Unknown")
    loaded_at = model_info.get("loaded_at", "Never")
    last_checked = model_info.get("last_checked", "Never")
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>MLflow Model API</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            h1 {{ color: #333; }}
            .links {{ margin: 20px 0; }}
            .link {{ display: block; padding: 10px; margin: 5px 0; background: #f0f0f0; text-decoration: none; border-radius: 5px; }}
            .link:hover {{ background: #e0e0e0; }}
            .container-info {{ background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .model-status {{ background: #f0f8e7; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .refresh-section {{ background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .refresh-button {{ background: #28a745; color: white; padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; display: inline-block; }}
            .refresh-button:hover {{ background: #218838; }}
            .config-info {{ background: #e2e3e5; padding: 15px; border-radius: 5px; margin: 20px 0; font-size: 0.9em; }}
        </style>
        <script>
            async function refreshModel() {{
                const button = document.getElementById('refresh-btn');
                button.disabled = true;
                button.textContent = 'Refreshing...';
                
                try {{
                    const response = await fetch('/refresh-model', {{ method: 'POST' }});
                    const result = await response.json();
                    
                    if (response.ok) {{
                        alert('Model refreshed successfully!');
                        location.reload();
                    }} else {{
                        alert('Failed to refresh model: ' + result.detail);
                    }}
                }} catch (error) {{
                    alert('Error refreshing model: ' + error.message);
                }} finally {{
                    button.disabled = false;
                    button.textContent = '🔄 Refresh Model';
                }}
            }}
        </script>
    </head>
    <body>
        <h1>🚀 MLflow Model API</h1>
        <div class="container-info">
            <h3>🐳 Containerized Deployment</h3>
            <p>This FastAPI server is running in a Docker container with MLflow model integration.</p>
            <p><strong>MLflow URL:</strong> {MLFLOW_BASE_URL}</p>
        </div>
        <div class="model-status">
            <h3>🤖 Model Status</h3>
            <p><strong>Status:</strong> {model_status}</p>
            <p><strong>Model:</strong> {model_info.get('name', 'None')}</p>
            <p><strong>Version:</strong> {model_version}</p>
            <p><strong>Loaded At:</strong> {loaded_at}</p>
            <p><strong>Last Checked:</strong> {last_checked}</p>
        </div>
        <div class="refresh-section">
            <h3>🔄 Model Management</h3>
            <p>Click to manually refresh the model from MLflow:</p>
            <button id="refresh-btn" class="refresh-button" onclick="refreshModel()">🔄 Refresh Model</button>
        </div>
        <div class="config-info">
            <h3>⚙️ Configuration</h3>
            <p><strong>Auto-refresh:</strong> {'Enabled' if AUTO_REFRESH_ENABLED else 'Disabled'}</p>
            <p><strong>Check Interval:</strong> {MODEL_CHECK_INTERVAL} seconds</p>
            <p><strong>MLflow URL:</strong> {MLFLOW_BASE_URL}</p>
            <p><strong>Deployment:</strong> Containerized</p>
        </div>
        <div class="links">
            <a class="link" href="/predict">🔮 Model Prediction (POST)</a>
            <a class="link" href="/model-info">📋 Model Information</a>
            <a class="link" href="/mlflow">📊 MLflow UI</a>
            <a class="link" href="/health">🏥 Health Check</a>
            <a class="link" href="/docs">📚 API Documentation</a>
            <a class="link" href="/container-info">🐳 Container Info</a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/predict")
async def predict(data: PredictionRequest):
    """Predict using the loaded MLflow model"""
    if model is None:
        raise HTTPException(
            status_code=503, 
            detail="Model not loaded. Please check MLflow configuration and ensure model exists."
        )
    
    try:
        # Convert request to DataFrame
        input_data = pd.DataFrame([data.dict()])
        input_data = input_data[
            ["sepal_length", "sepal_width", "petal_length", "petal_width"]
        ]
        
        # Rename columns to match training data
        input_data.columns = feature_names
        
        # Make prediction
        predictions = model.predict(input_data)
        
        return {
            "predictions": predictions.tolist(),
            "model_info": "MLflow loaded model",
            "input_features": data.dict(),
            "deployment": "containerized"
        }
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"Prediction failed: {str(e)}"
        )

@app.post("/refresh-model")
async def refresh_model():
    """Manually refresh the MLflow model"""
    logger.info("Manual model refresh requested")
    success = await load_mlflow_model()
    
    if success:
        return {
            "status": "success",
            "message": "Model refreshed successfully",
            "model_info": model_info
        }
    else:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to refresh model: {model_info.get('error', 'Unknown error')}"
        )

@app.get("/model-info")
async def get_model_info():
    """Get current model information"""
    return {
        "model_loaded": model is not None,
        "model_info": model_info,
        "config": {
            "auto_refresh_enabled": AUTO_REFRESH_ENABLED,
            "check_interval_seconds": MODEL_CHECK_INTERVAL,
            "model_name": os.getenv("MODEL_NAME", "best_iris_model"),
            "mlflow_tracking_uri": os.getenv("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db"),
            "experiment_name": os.getenv("EXPERIMENT_NAME", "iris_experiment")
        },
        "deployment": "containerized"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{MLFLOW_BASE_URL}/health", timeout=5.0)
            if response.status_code == 200:
                return {
                    "status": "healthy",
                    "mlflow": "connected",
                    "mlflow_url": MLFLOW_BASE_URL,
                    "proxy_port": FASTAPI_PORT,
                    "deployment": "containerized",
                    "model_loaded": model is not None
                }
            else:
                return {
                    "status": "unhealthy",
                    "mlflow": "disconnected",
                    "mlflow_status_code": response.status_code,
                    "deployment": "containerized",
                    "model_loaded": model is not None
                }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "mlflow_url": MLFLOW_BASE_URL,
            "deployment": "containerized",
            "model_loaded": model is not None
        }

@app.get("/container-info")
async def container_info():
    """Container information endpoint"""
    return {
        "container_name": "fastapi-proxy",
        "mlflow_container": "mlflow-server",
        "mlflow_url": MLFLOW_BASE_URL,
        "network": "mlflow-network",
        "ports": {
            "fastapi": FASTAPI_PORT,
            "mlflow": 5000
        },
        "model_loaded": model is not None
    }

@app.get("/mlflow")
async def mlflow_ui_redirect():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_BASE_URL}/")

@app.get("/mlflow/{path:path}")
async def proxy_mlflow_ui(path: str, request: Request):
    """Proxy MLflow UI requests"""
    try:
        query_params = str(request.url.query)
        url = f"{MLFLOW_BASE_URL}/{path}"
        if query_params:
            url += f"?{query_params}"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=dict(request.headers))
            return response.content
    except Exception as e:
        logger.error(f"MLflow UI proxy error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.api_route("/api/2.0/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_mlflow_api(path: str, request: Request):
    """Proxy MLflow API requests"""
    try:
        query_params = str(request.url.query)
        url = f"{MLFLOW_BASE_URL}/api/2.0/{path}"
        if query_params:
            url += f"?{query_params}"
        
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=request.method,
                url=url,
                headers=dict(request.headers),
                content=await request.body()
            )
            return response.content
    except Exception as e:
        logger.error(f"MLflow API proxy error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT)
FASTAPI_TEMPLATE_EOF
        echo "✅ Default FastAPI template created successfully!"
    elif [[ "$FASTAPI_SOURCE" == gs://* ]]; then
        echo "Downloading FastAPI application from GCS: $FASTAPI_SOURCE"
        if gsutil cp "$FASTAPI_SOURCE" /home/$TARGET_USER/deployml/docker/fastapi/main.py; then
            echo "✅ FastAPI application downloaded successfully from GCS!"
        else
            echo "❌ ERROR: Failed to download FastAPI application from GCS: $FASTAPI_SOURCE"
            echo "Please ensure the file exists and you have proper permissions."
            exit 1
        fi
    elif [[ "$FASTAPI_SOURCE" == /* ]]; then
        echo "Copying FastAPI application from local path: $FASTAPI_SOURCE"
        if [ -f "$FASTAPI_SOURCE" ]; then
            cp "$FASTAPI_SOURCE" /home/$TARGET_USER/deployml/docker/fastapi/main.py
            echo "✅ FastAPI application copied successfully!"
        else
            echo "❌ ERROR: FastAPI application not found at: $FASTAPI_SOURCE"
            echo "Please provide a valid file path or use 'template' for the default application."
            exit 1
        fi
    else
        echo "❌ ERROR: Invalid FastAPI source: $FASTAPI_SOURCE"
        echo "Supported sources:"
        echo "  - 'template' for default FastAPI application"
        echo "  - 'gs://bucket/path/main.py' for GCS file"
        echo "  - '/absolute/path/main.py' for local file"
        exit 1
    fi

    # Set proper permissions
    echo "Setting proper permissions for user: $TARGET_USER"
    sudo chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/deployml
    
    # Create systemd service for Docker Compose
    echo "Creating Docker Compose systemd service..."
    sudo tee /etc/systemd/system/mlflow-docker.service > /dev/null <<DOCKER_SERVICE_EOF
[Unit]
Description=MLflow Docker Compose Stack
After=network.target docker.service
Requires=docker.service

[Service]
Type=forking
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=/home/$TARGET_USER/deployml/docker
Environment=MLFLOW_BACKEND_STORE_URI=${var.backend_store_uri}
Environment=MLFLOW_DEFAULT_ARTIFACT_ROOT=${var.artifact_bucket != "" ? "gs://${var.artifact_bucket}" : "./mlflow-artifacts"}
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
ExecReload=/usr/bin/docker-compose restart
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
DOCKER_SERVICE_EOF

    # Reload systemd and enable Docker Compose service
    echo "Enabling and starting Docker Compose service..."
    sudo systemctl daemon-reload
    sudo systemctl enable mlflow-docker.service
    
    # Build and start Docker containers
    echo "Building Docker containers..."
    cd /home/$TARGET_USER/deployml/docker
    sudo -u $TARGET_USER docker-compose build
    
    echo "Starting Docker containers..."
    sudo systemctl start mlflow-docker.service
    
    # Wait for containers to start
    echo "Waiting for containers to start..."
    sleep 30
    
    # Check Docker Compose service status
    echo "Checking Docker Compose service status..."
    sudo systemctl status mlflow-docker --no-pager
    
    # Check container status
    echo "Checking container status..."
    sudo -u $TARGET_USER docker ps
    
    # Test MLflow container
    echo "Testing MLflow container..."
    for i in {1..10}; do
      if curl -s http://localhost:5000/health > /dev/null; then
        echo "✅ MLflow container is running successfully!"
        break
      else
        echo "Attempt $i: MLflow container not responding yet..."
        if [ $i -eq 10 ]; then
          echo "⚠️  MLflow container may still be starting up..."
          echo "Checking MLflow container logs..."
          sudo -u $TARGET_USER docker logs mlflow-server
        fi
        sleep 15
      fi
    done
    
    # Test FastAPI container
    echo "Testing FastAPI container..."
    for i in {1..10}; do
      if curl -s http://localhost:${var.fastapi_port}/health > /dev/null; then
        echo "✅ FastAPI container is running successfully!"
        break
      else
        echo "Attempt $i: FastAPI container not responding yet..."
        if [ $i -eq 10 ]; then
          echo "⚠️  FastAPI container may still be starting up..."
          echo "Checking FastAPI container logs..."
          sudo -u $TARGET_USER docker logs fastapi-proxy
        fi
        sleep 15
      fi
    done
    
    # Get external IP for display
    EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
    echo "🐳 Containerized MLflow deployment completed successfully!"
    echo "🌐 MLflow UI will be available at: http://$EXTERNAL_IP:${var.mlflow_port}"
    echo "🚀 FastAPI Proxy will be available at: http://$EXTERNAL_IP:${var.fastapi_port}"
    echo "📊 Container Info: http://$EXTERNAL_IP:${var.fastapi_port}/container-info"
    echo "🔧 SSH into the VM with: gcloud compute ssh ${var.vm_name} --zone=${var.zone}"
    echo "🐳 Manage containers: docker ps, docker logs mlflow-server, docker logs fastapi-proxy"
    
    echo "$(date): VM setup completed successfully!"
    echo "Startup script completed successfully" | sudo tee /var/log/mlflow-startup-complete.log
  EOF
}

# Firewall rule to allow MLflow traffic
resource "google_compute_firewall" "allow_mlflow" {
  count       = var.create_service && var.allow_public_access ? 1 : 0
  name        = "allow-mlflow-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow MLflow traffic to VM"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.mlflow_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mlflow-server"]
}

# Firewall rule to allow FastAPI traffic
resource "google_compute_firewall" "allow_fastapi" {
  count       = var.create_service && var.allow_public_access ? 1 : 0
  name        = "allow-fastapi-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow FastAPI traffic to VM"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.fastapi_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mlflow-server"]
}

# Firewall rule to allow Grafana traffic
resource "google_compute_firewall" "allow_grafana" {
  count       = var.create_service && var.allow_public_access && var.enable_grafana ? 1 : 0
  name        = "allow-grafana-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow Grafana traffic to VM"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.grafana_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mlflow-server"]
}

# Firewall rule to allow HTTP/HTTPS traffic (if needed for additional services)
resource "google_compute_firewall" "allow_http_https" {
  count       = var.create_service ? 1 : 0
  name        = "allow-http-https-mlflow-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow HTTP/HTTPS traffic to MLflow VM"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# Firewall rule to allow SSH (prefer IAP tunnel source range)
resource "google_compute_firewall" "allow_ssh" {
  count       = var.create_service ? 1 : 0
  name        = "allow-ssh-mlflow-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow SSH access to MLflow VM"

  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Open SSH to the internet (educational use). Consider restricting in production.
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-server"]
}

# Firewall rule for load balancer health checks
resource "google_compute_firewall" "allow_lb_health_checks" {
  count       = var.create_service ? 1 : 0
  name        = "allow-lb-health-check-mlflow-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow traffic for Load Balancer Health Checks"
  
  # Explicit dependency to ensure APIs are ready FIRST
  depends_on = [time_sleep.wait_for_api_propagation]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", tostring(var.mlflow_port)]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lb-health-check"]
}

# Outputs
output "vm_external_ip" {
  description = "External IP address of the MLflow VM"
  value       = var.create_service ? google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip : ""
}

output "mlflow_url" {
  description = "URL to access MLflow UI"
  value       = var.create_service ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.mlflow_port}" : ""
}

output "service_url" {
  description = "Service URL for MLflow (alias for mlflow_url)"
  value       = var.create_service ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.mlflow_port}" : ""
}

output "bucket_name" {
  description = "Name of the created artifact bucket"
  value       = var.create_bucket && var.artifact_bucket != "" ? google_storage_bucket.artifact[0].name : ""
}

output "vm_name" {
  description = "Name of the created VM instance"
  value       = var.create_service ? google_compute_instance.mlflow_vm[0].name : ""
}

output "zone" {
  description = "Zone where the VM is deployed"
  value       = var.create_service ? google_compute_instance.mlflow_vm[0].zone : ""
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = var.create_service ? "gcloud compute ssh ${google_compute_instance.mlflow_vm[0].name} --zone=${google_compute_instance.mlflow_vm[0].zone}" : ""
}

output "fastapi_url" {
  description = "URL to access FastAPI proxy"
  value       = var.create_service ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}" : ""
}

output "fastapi_health_url" {
  description = "URL to check FastAPI health status"
  value       = var.create_service ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}/health" : ""
}

output "container_info_url" {
  description = "URL to check container information"
  value       = var.create_service ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.fastapi_port}/container-info" : ""
}

output "docker_commands" {
  description = "Useful Docker commands for container management"
  value = {
    check_containers = "docker ps"
    mlflow_logs      = "docker logs mlflow-server"
    fastapi_logs     = "docker logs fastapi-proxy"
    grafana_logs     = var.enable_grafana ? "docker logs grafana-server" : "Grafana not enabled"
    restart_services = "docker-compose restart"
    stop_services    = "docker-compose down"
    start_services   = "docker-compose up -d"
  }
}

output "grafana_url" {
  description = "URL to access Grafana UI"
  value       = var.create_service && var.enable_grafana ? "http://${google_compute_instance.mlflow_vm[0].network_interface[0].access_config[0].nat_ip}:${var.grafana_port}" : null
}

output "grafana_enabled" {
  description = "Whether Grafana is enabled"
  value       = var.enable_grafana
}

# Debug outputs for IAM troubleshooting
output "service_account_email" {
  description = "Email of the created service account"
  value       = google_service_account.vm_service_account.email
}

output "iam_debug_info" {
  description = "Debug information for IAM configuration"
  value = {
    create_bucket      = var.create_bucket
    artifact_bucket    = var.artifact_bucket
    bucket_iam_count   = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
    existing_iam_count = !var.create_bucket && var.artifact_bucket != "" ? 1 : 0
    project_iam_count  = var.artifact_bucket != "" ? 1 : 0
    service_account_id = google_service_account.vm_service_account.account_id
    project_id         = var.project_id
  }
}

# IAM bindings for when bucket is created by this module
resource "google_storage_bucket_iam_member" "mlflow_vm_artifact_access_admin" {
  count      = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket     = google_storage_bucket.artifact[0].name
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_storage_bucket.artifact, google_service_account.vm_service_account]
}

resource "google_storage_bucket_iam_member" "mlflow_vm_artifact_access_viewer" {
  count      = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket     = google_storage_bucket.artifact[0].name
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_storage_bucket.artifact, google_service_account.vm_service_account]
}

# IAM bindings for when using existing bucket (not created by this module)
resource "google_storage_bucket_iam_member" "mlflow_vm_existing_bucket_access_admin" {
  count      = !var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket     = var.artifact_bucket
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account]
}

resource "google_storage_bucket_iam_member" "mlflow_vm_existing_bucket_access_viewer" {
  count      = !var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket     = var.artifact_bucket
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account]
}

# Project-level IAM bindings (these will show up in the main IAM UI)
resource "google_project_iam_member" "vm_service_account_storage_admin" {
  count      = var.artifact_bucket != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account, time_sleep.wait_for_api_propagation]
}

resource "google_project_iam_member" "vm_service_account_storage_viewer" {
  count      = var.artifact_bucket != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account, time_sleep.wait_for_api_propagation]
}

# Additional useful permissions for the VM service account
resource "google_project_iam_member" "vm_service_account_logging" {
  count      = var.create_service ? 1 : 0
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account, time_sleep.wait_for_api_propagation]
}

resource "google_project_iam_member" "vm_service_account_monitoring" {
  count      = var.create_service ? 1 : 0
  project    = var.project_id
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
  depends_on = [google_service_account.vm_service_account, time_sleep.wait_for_api_propagation]
}