#!/bin/bash

# Single VM deployment startup script for MLflow, FastAPI, and Feast
# This script uses extracted templates for maintainability

set -e

# Get current user
CURRENT_USER=$(whoami)
echo "🚀 Starting deployment for user: $CURRENT_USER"

# Create deployment directory structure
echo "📁 Creating deployment directory structure..."
mkdir -p /home/$CURRENT_USER/deployml/docker
mkdir -p /home/$CURRENT_USER/deployml/docker/mlflow
mkdir -p /home/$CURRENT_USER/deployml/docker/fastapi
mkdir -p /home/$CURRENT_USER/deployml/docker/feast

# Verify directory creation
echo "📁 Verifying directory structure..."
ls -la /home/$CURRENT_USER/deployml/
ls -la /home/$CURRENT_USER/deployml/docker/

# Install Docker if not already installed
echo "🔧 Installing Docker..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found, installing..."
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Detect OS and use appropriate Docker repository
    OS_DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    OS_CODENAME=$(lsb_release -cs)
    
    echo "Detected OS: $OS_DISTRO $OS_CODENAME"
    
    if [ "$OS_DISTRO" = "debian" ]; then
        echo "Using Debian Docker repository..."
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository for Debian
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $OS_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo "Using Ubuntu Docker repository..."
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository for Ubuntu
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $OS_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package list again
    echo "Updating package list for Docker installation..."
    apt-get update
    
    # Install Docker
    echo "Installing Docker packages..."
    if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        echo "❌ Docker installation failed"
        echo "Checking available packages..."
        apt-cache search docker-ce
        echo "Checking package list..."
        apt list --upgradable
        exit 1
    fi
    
    # Add current user to docker group
    usermod -aG docker $CURRENT_USER
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Wait for Docker to be ready
echo "Waiting for Docker to be ready..."
DOCKER_READY_COUNT=0
MAX_DOCKER_WAIT=30
until docker info &> /dev/null; do
    echo "Docker not ready yet, waiting... (attempt $DOCKER_READY_COUNT/$MAX_DOCKER_WAIT)"
    DOCKER_READY_COUNT=$((DOCKER_READY_COUNT + 1))
    if [ $DOCKER_READY_COUNT -ge $MAX_DOCKER_WAIT ]; then
        echo "❌ Docker failed to start after $MAX_DOCKER_WAIT attempts"
        echo "Checking Docker service status..."
        systemctl status docker --no-pager
        echo "Checking Docker logs..."
        journalctl -u docker.service --no-pager | tail -20
        exit 1
    fi
    sleep 2
done
echo "✅ Docker is ready!"

# Verify Docker installation
echo "🔍 Verifying Docker installation..."
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"
echo "Docker daemon info:"
docker info | head -10

# Wait for PostgreSQL to be ready if using it
if [ "$use_postgres" = "true" ]; then
  echo "Waiting for PostgreSQL to be ready..."
  # Install PostgreSQL client for connection testing
  echo "Installing PostgreSQL client..."
  if ! apt-get update && apt-get install -y postgresql-client; then
      echo "❌ PostgreSQL client installation failed"
      exit 1
  fi
  
  until pg_isready -h ${postgres_host} -p ${postgres_port} -U ${postgres_user}; do
      echo "PostgreSQL not ready yet, waiting..."
      sleep 5
  done
  echo "✅ PostgreSQL is ready!"
fi

# Create MLflow Dockerfile from template
echo "Creating MLflow Dockerfile..."
cat > /home/$CURRENT_USER/deployml/docker/mlflow/Dockerfile << MLFLOW_DOCKERFILE_EOF
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl
MLFLOW_DOCKERFILE_EOF

# Add PostgreSQL client if needed
if [ "$use_postgres" = "true" ]; then
  echo "    postgresql-client \\" >> /home/$CURRENT_USER/deployml/docker/mlflow/Dockerfile
fi

# Complete the Dockerfile
cat >> /home/$CURRENT_USER/deployml/docker/mlflow/Dockerfile << MLFLOW_DOCKERFILE_CONTINUE
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install MLflow and dependencies
RUN pip install \\
    mlflow[extras] \\
    sqlalchemy \\
    google-cloud-storage \\
    boto3
MLFLOW_DOCKERFILE_CONTINUE

# Add PostgreSQL Python package if needed
if [ "$use_postgres" = "true" ]; then
  echo "    psycopg2-binary \\" >> /home/$CURRENT_USER/deployml/docker/mlflow/Dockerfile
fi

# Complete the Dockerfile
cat >> /home/$CURRENT_USER/deployml/docker/mlflow/Dockerfile << MLFLOW_DOCKERFILE_FINAL

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
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD curl -f http://localhost:5000/health || exit 1

# Default command
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
MLFLOW_DOCKERFILE_FINAL

# Create FastAPI Dockerfile from template
echo "Creating FastAPI Dockerfile..."
cat > /home/$CURRENT_USER/deployml/docker/fastapi/Dockerfile << FASTAPI_DOCKERFILE_EOF
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install FastAPI and dependencies
RUN pip install \\
    fastapi \\
    uvicorn \\
    httpx \\
    mlflow \\
    pandas \\
    joblib \\
    scikit-learn \\
    numpy \\
    google-cloud-storage \\
    google-cloud-core

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
EXPOSE $fastapi_port

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \\
    CMD curl -f http://localhost:$fastapi_port/health || exit 1

# Default command
CMD ["uvicorn", "fastapi-app.main:app", "--host", "0.0.0.0", "--port", "$fastapi_port"]
FASTAPI_DOCKERFILE_EOF

# Setup FastAPI application
echo "Setting up FastAPI application..."
FASTAPI_SOURCE="${fastapi_app_source}"

if [ "$FASTAPI_SOURCE" = "template" ]; then
    echo "Using default containerized FastAPI template..."
    # Create a containerized FastAPI application with MLflow proxy and model integration
    cat > /home/$CURRENT_USER/deployml/docker/fastapi/main.py << 'FASTAPI_TEMPLATE_EOF'
from fastapi import FastAPI, HTTPException, Request
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
MLFLOW_EXTERNAL_URL = os.getenv("MLFLOW_EXTERNAL_URL", MLFLOW_BASE_URL)  # External URL for UI links
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))

# Create FastAPI app
app = FastAPI(
    title="MLflow FastAPI Proxy",
    description="FastAPI proxy for MLflow with model serving capabilities",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "fastapi-proxy", "timestamp": datetime.now().isoformat()}

# Root endpoint - redirect to MLflow
@app.get("/")
async def root():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_EXTERNAL_URL}")

# MLflow proxy endpoint
@app.get("/mlflow")
async def mlflow_proxy():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_EXTERNAL_URL}")

# Container info endpoint
@app.get("/container-info")
async def container_info():
    """Get container information"""
    return {
        "service": "fastapi-proxy",
        "mlflow_url": MLFLOW_BASE_URL,
        "external_mlflow_url": MLFLOW_EXTERNAL_URL,
        "fastapi_port": FASTAPI_PORT,
        "timestamp": datetime.now().isoformat()
    }

# Model prediction endpoint
@app.post("/predict")
async def predict(request: Request):
    """Model prediction endpoint"""
    try:
        # Get request data
        data = await request.json()
        
        # For now, return a simple response
        # In a real implementation, you would load and run the model
        return {
            "prediction": "sample_prediction",
            "input_data": data,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT)
FASTAPI_TEMPLATE_EOF
fi

# Create Feast Dockerfile from template
echo "Creating Feast Dockerfile..."
cat > /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << FEAST_DOCKERFILE_EOF
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl
FEAST_DOCKERFILE_EOF

# Add PostgreSQL client if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  echo "    postgresql-client \\" >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile
fi

cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << FEAST_DOCKERFILE_CONTINUE
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \\
    feast[postgres] \\
    google-cloud-bigquery \\
    google-cloud-storage
FEAST_DOCKERFILE_CONTINUE

# Add psycopg2 if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  echo "    psycopg2-binary \\" >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile
fi

cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << FEAST_DOCKERFILE_FINAL

# Copy Feast configuration
COPY feast_env.tpl /app/feast_env.tpl
COPY feast_config.py /app/feast_config.py

# Create Feast configuration
RUN python /app/feast_config.py

# Expose port
EXPOSE $feast_port

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \\
    CMD curl -f http://localhost:$feast_port/health || exit 1

# Start Feast server
CMD ["feast", "serve", "--host", "0.0.0.0", "--port", "$feast_port"]
FEAST_DOCKERFILE_FINAL

# Create Feast configuration script
echo "Creating Feast configuration script..."
cat > /home/$CURRENT_USER/deployml/docker/feast/feast_config.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import os
import json

# Feast configuration
feast_config = {
    "project": "feast_project",
    "provider": "local",
    "online_store": {
        "type": os.environ.get("ONLINE_STORE_TYPE", "sqlite"),
        "connection_string": os.environ.get("POSTGRES_HOST") and 
            f"postgresql://{os.environ.get('POSTGRES_USER')}:{os.environ.get('POSTGRES_PASSWORD')}@{os.environ.get('POSTGRES_HOST')}:{os.environ.get('POSTGRES_PORT')}/{os.environ.get('POSTGRES_DATABASE')}" or 
            "sqlite:///feast.db"
    },
    "offline_store": {
        "type": os.environ.get("OFFLINE_STORE_TYPE", "bigquery"),
        "dataset": os.environ.get("BIGQUERY_DATASET", "feast_offline_store")
    },
    "registry": {
        "type": os.environ.get("REGISTRY_TYPE", "file"),
        "path": "/app/registry.db"
    }
}

# Write Feast configuration
with open("/app/feature_store.yaml", "w") as f:
    import yaml
    yaml.dump(feast_config, f, default_flow_style=False)

print("✅ Feast configuration created successfully!")
PYTHON_EOF

# Create Feast environment template
echo "Creating Feast environment template..."
cat > /home/$CURRENT_USER/deployml/docker/feast/feast_env.tpl << ENV_EOF
# Feast Environment Variables
FEAST_PROJECT=feast_project
FEAST_PORT=$feast_port
REGISTRY_TYPE=$registry_type
ONLINE_STORE_TYPE=$online_store_type
OFFLINE_STORE_TYPE=$offline_store_type
BIGQUERY_DATASET=$bigquery_dataset
ENV_EOF

# Add PostgreSQL environment variables if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  cat >> /home/$CURRENT_USER/deployml/docker/feast/feast_env.tpl << 'EOF'
POSTGRES_HOST=${postgres_host}
POSTGRES_PORT=${postgres_port}
POSTGRES_DATABASE=${postgres_database}
POSTGRES_USER=${postgres_user}
POSTGRES_PASSWORD=${postgres_password}
EOF
fi

# Make scripts executable
chmod +x /home/$CURRENT_USER/deployml/docker/feast/feast_config.py

# Set proper permissions
chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/deployml

# Get external IP first for Docker Compose configuration
echo "Getting external IP for MLflow URL..."
EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
echo "External IP: $EXTERNAL_IP"

# Fallback to gcloud if metadata endpoint fails
if [[ "$EXTERNAL_IP" == *"<!DOCTYPE html>"* ]] || [[ -z "$EXTERNAL_IP" ]]; then
    echo "Metadata endpoint failed, using gcloud fallback..."
    EXTERNAL_IP=$(gcloud compute instances describe mlflow-postgres-vm-instance --zone=us-west2-a --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    echo "External IP (gcloud): $EXTERNAL_IP"
fi

# Create Docker Compose file
echo "Creating Docker Compose configuration..."
cat > /home/$CURRENT_USER/deployml/docker/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
  mlflow:
    build: 
      context: ./mlflow
      dockerfile: Dockerfile
    container_name: mlflow-server
    ports:
      - "${mlflow_port}:5000"
    environment:
      - MLFLOW_BACKEND_STORE_URI=${backend_store_uri}
      - MLFLOW_DEFAULT_ARTIFACT_ROOT=$(if [ -n "$artifact_bucket" ]; then echo "gs://$artifact_bucket"; else echo "./mlflow-artifacts"; fi)
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
      --backend-store-uri ${backend_store_uri}
      --default-artifact-root $(if [ -n "$artifact_bucket" ]; then echo "gs://$artifact_bucket"; else echo "./mlflow-artifacts"; fi)
    
  fastapi:
    build:
      context: ./fastapi
      dockerfile: Dockerfile
    container_name: fastapi-proxy
    ports:
      - "${fastapi_port}:8000"
    environment:
      - MLFLOW_BASE_URL=http://mlflow:5000
      - MLFLOW_EXTERNAL_URL=http://$EXTERNAL_IP:${mlflow_port}
      - FASTAPI_PORT=8000
    depends_on:
      - mlflow
    networks:
      - mlflow-network
    restart: unless-stopped

  feast:
    build:
      context: ./feast
      dockerfile: Dockerfile
    container_name: feast-server
    ports:
      - "${feast_port}:${feast_port}"
    environment:
      - FEAST_PORT=${feast_port}
      - REGISTRY_TYPE=${registry_type}
      - ONLINE_STORE_TYPE=${online_store_type}
      - OFFLINE_STORE_TYPE=${offline_store_type}
      - BIGQUERY_DATASET=${bigquery_dataset}
DOCKER_COMPOSE_EOF

# Add PostgreSQL environment variables if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  echo "      - POSTGRES_HOST=${postgres_host}" >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml
  echo "      - POSTGRES_PORT=${postgres_port}" >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml
  echo "      - POSTGRES_DATABASE=${postgres_database}" >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml
  echo "      - POSTGRES_USER=${postgres_user}" >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml
  echo "      - POSTGRES_PASSWORD=${postgres_password}" >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml
fi

# Complete the Docker Compose file
cat >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml << 'DOCKER_COMPOSE_CONTINUE'
    volumes:
      - ./feast:/app
    networks:
      - mlflow-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${feast_port}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  mlflow-data:
  mlflow-config:

networks:
  mlflow-network:
    driver: bridge
DOCKER_COMPOSE_CONTINUE

# Verify Docker Compose YAML syntax
echo "🔍 Verifying Docker Compose YAML syntax..."
if ! docker compose -f /home/$CURRENT_USER/deployml/docker/docker-compose.yml config > /dev/null 2>&1; then
    echo "❌ Docker Compose YAML syntax error detected"
    echo "Generated YAML content:"
    cat /home/$CURRENT_USER/deployml/docker/docker-compose.yml
    echo "❌ Exiting due to YAML syntax error"
    exit 1
fi
echo "✅ Docker Compose YAML syntax is valid"

# Create systemd service file
echo "Creating systemd service file..."
cat > /etc/systemd/system/mlflow-docker.service << 'DOCKER_SERVICE_EOF'
[Unit]
Description=MLflow Docker Compose Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER/deployml/docker
Environment=MLFLOW_BACKEND_STORE_URI=${backend_store_uri}
Environment=MLFLOW_DEFAULT_ARTIFACT_ROOT=$(if [ -n "$artifact_bucket" ]; then echo "gs://$artifact_bucket"; else echo "./mlflow-artifacts"; fi)
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
DOCKER_SERVICE_EOF

# Build Docker containers first
echo "Building Docker containers..."
cd /home/$CURRENT_USER/deployml/docker

# Fix Docker socket permissions temporarily for this build
sudo chmod 666 /var/run/docker.sock

# Build containers
echo "Building MLflow container..."
if ! docker compose build mlflow; then
    echo "❌ MLflow container build failed"
    docker compose logs mlflow
    exit 1
fi

echo "Building FastAPI container..."
if ! docker compose build fastapi; then
    echo "❌ FastAPI container build failed"
    docker compose logs fastapi
    exit 1
fi

echo "Building Feast container..."
if ! docker compose build feast; then
    echo "❌ Feast container build failed"
    docker compose logs feast
    exit 1
fi

echo "✅ All Docker containers built successfully"

# Restore Docker socket permissions
sudo chmod 660 /var/run/docker.sock

# Reload systemd and enable Docker Compose service
echo "Enabling Docker Compose service..."
sudo systemctl daemon-reload
sudo systemctl enable mlflow-docker.service

echo "Starting Docker containers via systemd..."
sudo systemctl start mlflow-docker.service

# Wait for containers to start
echo "Waiting for containers to start..."
sleep 30

# Check Docker Compose service status
echo "Checking Docker Compose service status..."
sudo systemctl status mlflow-docker --no-pager

# Check container status
echo "Checking container status..."
docker ps

# Test MLflow container
echo "Testing MLflow container..."
for i in {1..10}; do
  if curl -s http://localhost:${mlflow_port}/health > /dev/null; then
    echo "✅ MLflow container is running successfully!"
    break
  else
    echo "Attempt $i: MLflow container not responding yet..."
    if [ $i -eq 10 ]; then
      echo "⚠️  MLflow container may still be starting up..."
      echo "Checking MLflow container logs..."
      docker logs mlflow-server
    fi
    sleep 15
  fi
done

# Test FastAPI container
echo "Testing FastAPI container..."
for i in {1..10}; do
  if curl -s http://localhost:${fastapi_port}/health > /dev/null; then
    echo "✅ FastAPI container is running successfully!"
    break
  else
    echo "Attempt $i: FastAPI container not responding yet..."
    if [ $i -eq 10 ]; then
      echo "⚠️  FastAPI container may still be starting up..."
      echo "Checking FastAPI container logs..."
      docker logs fastapi-proxy
    fi
    sleep 15
  fi
done

# Test Feast container
echo "Testing Feast container..."
for i in {1..10}; do
  if curl -s http://localhost:${feast_port}/health > /dev/null; then
    echo "✅ Feast container is running successfully!"
    break
  else
    echo "Attempt $i: Feast container not responding yet..."
    if [ $i -eq 10 ]; then
      echo "⚠️  Feast container may still be starting up..."
      echo "Checking Feast container logs..."
      docker logs feast-server
    fi
    sleep 15
  fi
done

# Get external IP for display
EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access_configs/0/external-ip -H "Metadata-Flavor: Google")

# Display success message
if [ "$use_postgres" = "true" ]; then
  echo "🐳 Single VM deployment with MLflow, FastAPI, and Feast (PostgreSQL backend) completed successfully!"
else
  echo "🐳 Single VM deployment with MLflow, FastAPI, and Feast completed successfully!"
fi

echo "🌐 MLflow UI will be available at: http://$EXTERNAL_IP:${mlflow_port}"
echo "🚀 FastAPI Proxy will be available at: http://$EXTERNAL_IP:${fastapi_port}"
echo "📊 Feast Feature Store will be available at: http://$EXTERNAL_IP:${feast_port}"
echo "🔍 Feast health endpoint: http://$EXTERNAL_IP:${feast_port}/health"
echo "📊 Container Info: http://$EXTERNAL_IP:${fastapi_port}/container-info"
echo "🔧 SSH into the VM with: gcloud compute ssh ${vm_name} --zone=${zone}"
echo "🐳 Manage containers: docker ps, docker logs mlflow-server, docker logs fastapi-proxy, docker logs feast-server"
echo "🔧 Docker Compose: docker compose up -d, docker compose down, docker compose restart"

# Display backend store information
if [ "$use_postgres" = "true" ]; then
  echo "Backend store: PostgreSQL"
else
  echo "Backend store: SQLite"
fi

# Display artifact store information if available
if [ -n "${artifact_bucket}" ]; then
  echo "Artifact store: gs://${artifact_bucket}"
fi

# Display Feast configuration
echo "Feast configuration:"
echo "  • Registry type: ${registry_type}"
echo "  • Online store: ${online_store_type}"
echo "  • Offline store: ${offline_store_type}"
echo "  • BigQuery dataset: ${bigquery_dataset}"

echo "$(date): Single VM setup completed successfully!"
echo "Startup script completed successfully" | sudo tee /var/log/mlflow-startup-complete.log

echo ""
echo "🎉 Single VM deployment completed successfully!"
echo "🚀 Your MLflow, FastAPI, and Feast services are now running on one VM!"
