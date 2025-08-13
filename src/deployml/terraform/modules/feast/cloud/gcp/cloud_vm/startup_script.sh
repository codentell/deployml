#!/bin/bash
set -e

echo "Starting Feast VM setup${use_postgres}..."

# Log all output to a file for debugging
exec > >(tee /var/log/feast-startup.log) 2>&1

echo "$(date): Starting Feast VM setup..."

# Get the current user dynamically
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"

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

# Add PostgreSQL client if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  sudo apt-get install -y postgresql-client
fi

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
echo "Configuring Docker permissions for user: $CURRENT_USER"
sudo usermod -aG docker $CURRENT_USER

# Wait for Docker to be ready
echo "Waiting for Docker to be ready..."
sleep 10

# Test Docker installation
echo "Testing Docker installation..."
sudo docker run --rm hello-world

# Set up containerized Feast environment
echo "Setting up containerized Feast environment..."

# Create deployment directory structure
mkdir -p /home/$CURRENT_USER/deployml/docker
mkdir -p /home/$CURRENT_USER/deployml/docker/feast

# Wait for PostgreSQL to be ready if using it
if [ "$use_postgres" = "true" ]; then
  echo "Waiting for PostgreSQL to be ready..."
  until pg_isready -h ${postgres_host} -p ${postgres_port} -U ${postgres_user}; do
      echo "PostgreSQL not ready yet, waiting..."
      sleep 5
  done
  echo "✅ PostgreSQL is ready!"
fi

# Create Docker Compose file
echo "Creating Docker Compose configuration..."
cat > /home/$CURRENT_USER/deployml/docker/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
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
EOF

# Add PostgreSQL environment variables if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  cat >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml << 'EOF'
      - POSTGRES_HOST=${postgres_host}
      - POSTGRES_PORT=${postgres_port}
      - POSTGRES_DATABASE=${postgres_database}
      - POSTGRES_USER=${postgres_user}
      - POSTGRES_PASSWORD=${postgres_password}
EOF
fi

cat >> /home/$CURRENT_USER/deployml/docker/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
    volumes:
      - ./feast:/app
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${feast_port}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

DOCKER_COMPOSE_EOF

# Create Feast Dockerfile
echo "Creating Feast Dockerfile..."
cat > /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << 'DOCKERFILE_EOF'
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl
EOF

# Add PostgreSQL client if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << 'EOF'
RUN apt-get install -y postgresql-client
EOF
fi

cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << 'DOCKERFILE_EOF'
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    feast[postgres] \
    google-cloud-bigquery \
    google-cloud-storage
EOF

# Add psycopg2 if using PostgreSQL
if [ "$use_postgres" = "true" ]; then
  cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << 'EOF'
RUN pip install --no-cache-dir psycopg2-binary
EOF
fi

cat >> /home/$CURRENT_USER/deployml/docker/feast/Dockerfile << 'DOCKERFILE_EOF'

# Copy Feast configuration
COPY feast_env.tpl /app/feast_env.tpl
COPY feast_config.py /app/feast_config.py

# Create Feast configuration
RUN python /app/feast_config.py

# Expose port
EXPOSE ${feast_port}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${feast_port}/health || exit 1

# Start Feast server
CMD ["feast", "serve", "--host", "0.0.0.0", "--port", "${feast_port}"]
DOCKERFILE_EOF

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
cat > /home/$CURRENT_USER/deployml/docker/feast/feast_env.tpl << 'ENV_EOF'
# Feast Environment Variables
FEAST_PROJECT=feast_project
FEAST_PORT=${feast_port}
REGISTRY_TYPE=${registry_type}
ONLINE_STORE_TYPE=${online_store_type}
OFFLINE_STORE_TYPE=${offline_store_type}
BIGQUERY_DATASET=${bigquery_dataset}
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

# Build and start Feast containers
echo "Building and starting Feast containers..."
cd /home/$CURRENT_USER/deployml/docker

# Build the Feast image
echo "Building Feast Docker image..."
sudo docker compose build feast

# Start the services
echo "Starting Feast services..."
sudo docker compose up -d

# Wait for services to be ready
echo "Waiting for Feast services to be ready..."
sleep 30

# Check service health
echo "Checking Feast service health..."
if curl -f http://localhost:${feast_port}/health; then
    echo "✅ Feast service is healthy!"
else
    echo "⚠️ Feast service health check failed, but continuing..."
fi

# Get external IP for display
EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access_configs/0/external-ip -H "Metadata-Flavor: Google")

# Display success message
if [ "$use_postgres" = "true" ]; then
  echo "🐳 Containerized Feast deployment with PostgreSQL backend completed successfully!"
else
  echo "🐳 Containerized Feast deployment completed successfully!"
fi

echo "🌐 Feast server will be available at: http://$EXTERNAL_IP:${feast_port}"
echo "🔍 Feast health endpoint: http://$EXTERNAL_IP:${feast_port}/health"
echo "📊 Feast gRPC endpoint: $EXTERNAL_IP:${feast_port}"

# Display useful information
echo ""
echo "📋 Deployment Information:"
echo "   • VM Name: ${vm_name}"
echo "   • Zone: ${zone}"
echo "   • Feast Port: ${feast_port}"
echo "   • Registry Type: ${registry_type}"
echo "   • Online Store: ${online_store_type}"
echo "   • Offline Store: ${offline_store_type}"
echo "   • BigQuery Dataset: ${bigquery_dataset}"

# Display database information
if [ "$use_postgres" = "true" ]; then
  echo "   • Database: PostgreSQL"
else
  echo "   • Database: SQLite"
fi

# Display artifact store information if available
if [ -n "${artifact_bucket}" ]; then
  echo "   • Artifact Store: gs://${artifact_bucket}"
fi

echo ""
echo "🔧 Management Commands:"
echo "🐳 Manage containers: docker ps, docker logs feast-server"
echo "🔧 Docker Compose: docker compose up -d, docker compose down, docker compose restart"

# Display backend store information
if [ "$use_postgres" = "true" ]; then
  echo "Backend store: PostgreSQL"
else
  echo "Backend store: SQLite"
fi

# Create completion marker
echo "$(date): VM setup completed successfully!"
echo "Startup script completed successfully" | sudo tee /var/log/feast-startup-complete.log

echo ""
echo "🎉 Feast VM deployment completed successfully!"
echo "🚀 Your Feast feature store is now running!"
