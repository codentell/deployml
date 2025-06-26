# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Storage bucket - only create if explicitly requested
resource "google_storage_bucket" "artifact" {
  count         = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  name          = var.artifact_bucket
  location      = var.region
  force_destroy = true
  
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
}

# Define a Google Compute Engine instance
resource "google_compute_instance" "mlflow_vm" {
  count        = var.create_service ? 1 : 0
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Debian 12 (Bookworm) - better for Python/pip
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

  tags = var.tags

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
    
    # Set up MLflow environment
    echo "Setting up MLflow environment..."
    
    # Create a Python virtual environment
    echo "Creating Python virtual environment..."
    python3 -m venv /home/$CURRENT_USER/mlflow-env
    source /home/$CURRENT_USER/mlflow-env/bin/activate
    
    # Upgrade pip in the virtual environment
    echo "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    # Install MLflow and dependencies
    echo "Installing MLflow..."
    pip install mlflow[extras] sqlalchemy psycopg2-binary
    
    # Verify MLflow installation
    echo "Verifying MLflow installation..."
    mlflow --version
    
    # Create MLflow configuration directory
    mkdir -p /home/$CURRENT_USER/mlflow-config
    mkdir -p /home/$CURRENT_USER/mlflow-data
    
    # Set up environment variables
    export MLFLOW_SERVER_HOST=0.0.0.0
    export MLFLOW_SERVER_PORT=5000
    
    if [ -n "${var.backend_store_uri}" ]; then
      export MLFLOW_BACKEND_STORE_URI=${var.backend_store_uri}
    fi
    
    if [ -n "${var.artifact_bucket}" ]; then
      export MLFLOW_DEFAULT_ARTIFACT_ROOT=gs://${var.artifact_bucket}
    fi
    
    # Create systemd service for MLflow
    echo "Creating MLflow systemd service..."
    sudo tee /etc/systemd/system/mlflow.service > /dev/null <<SERVICE_EOF
[Unit]
Description=MLflow Server
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER
Environment=PATH=/home/$CURRENT_USER/mlflow-env/bin
Environment=MLFLOW_SERVER_HOST=0.0.0.0
Environment=MLFLOW_SERVER_PORT=5000
Environment=MLFLOW_BACKEND_STORE_URI=${var.backend_store_uri}
Environment=MLFLOW_DEFAULT_ARTIFACT_ROOT=gs://${var.artifact_bucket}
ExecStart=/home/$CURRENT_USER/mlflow-env/bin/mlflow server --host 0.0.0.0 --port 5000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    # Set proper permissions
    echo "Setting proper permissions for user: $CURRENT_USER"
    sudo chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/mlflow-env
    sudo chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/mlflow-config
    sudo chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/mlflow-data
    
    # Reload systemd and enable MLflow service
    echo "Enabling and starting MLflow service..."
    sudo systemctl daemon-reload
    sudo systemctl enable mlflow.service
    sudo systemctl start mlflow.service
    
    # Wait for MLflow to start
    echo "Waiting for MLflow to start..."
    sleep 20
    
    # Check if MLflow is running
    echo "Checking MLflow service status..."
    sudo systemctl status mlflow --no-pager
    
    # Test MLflow locally
    echo "Testing MLflow locally..."
    for i in {1..5}; do
      if curl -s http://localhost:5000 > /dev/null; then
        echo "✅ MLflow server is running successfully!"
        break
      else
        echo "Attempt $i: MLflow server not responding yet..."
        if [ $i -eq 5 ]; then
          echo "⚠️  MLflow server may still be starting up..."
          echo "Checking MLflow logs..."
          sudo journalctl -u mlflow --no-pager -n 30
        fi
        sleep 10
      fi
    done
    
    # Get external IP for display
    EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
    echo "🌐 MLflow UI will be available at: http://$EXTERNAL_IP:${var.mlflow_port}"
    echo "🔧 SSH into the VM with: gcloud compute ssh ${var.vm_name} --zone=${var.zone}"
    
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

  allow {
    protocol = "tcp"
    ports    = [tostring(var.mlflow_port)]
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

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# Firewall rule for load balancer health checks
resource "google_compute_firewall" "allow_lb_health_checks" {
  count       = var.create_service ? 1 : 0
  name        = "allow-lb-health-check-mlflow-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow traffic for Load Balancer Health Checks"

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