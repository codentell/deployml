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
    component = "wandb-artifacts"
    managed-by = "terraform"
  }
}

# Create a service account for the VM
resource "google_service_account" "vm_service_account" {
  account_id   = "wandb-vm-sa"
  display_name = "Service Account for Weights & Biases VM"
  project      = var.project_id
}

# Define a Google Compute Engine instance
resource "google_compute_instance" "wandb_vm" {
  count        = var.create_service ? 1 : 0
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null
    access_config {}
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = merge(var.metadata, {
    startup-script = var.startup_script != "" ? var.startup_script : local.default_startup_script
  })

  tags = concat(var.tags, ["ssh-server"])

  can_ip_forward = true
  allow_stopping_for_update = true
}

locals {
  default_startup_script = <<-EOF
    #!/bin/bash
    set -e
    echo "Starting Weights & Biases VM setup..."
    exec > >(tee /var/log/wandb-startup.log) 2>&1
    echo "$(date): Starting wandb VM setup..."
    CURRENT_USER=$(whoami)
    echo "Current user: $CURRENT_USER"
    sudo apt-get update -y
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
    python3 --version
    pip3 --version
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $CURRENT_USER
    sleep 10
    sudo docker run --rm hello-world
    echo "Setting up wandb server..."
    mkdir -p /home/$CURRENT_USER/wandb-data/env
    mkdir -p /home/$CURRENT_USER/wandb-data/minio
    mkdir -p /home/$CURRENT_USER/wandb-data/mysql
    sudo chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/wandb-data
    sudo chmod -R 777 /home/$CURRENT_USER/wandb-data/env
    sudo chmod -R 777 /home/$CURRENT_USER/wandb-data/minio
    sudo chmod -R 777 /home/$CURRENT_USER/wandb-data/mysql
    EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
    sudo docker pull wandb/local:latest
    sudo docker run -d \
      --restart unless-stopped \
      -e HOST=http://$EXTERNAL_IP:8080 \
      -v /home/$CURRENT_USER/wandb-data:/vol \
      -p 8080:8080 \
      --name wandb-local \
      wandb/local:latest
    sleep 20
    sudo docker ps -a | tee /var/log/wandb-docker-status.log
    echo "🌐 wandb UI will be available at: http://$EXTERNAL_IP:8080"
    echo "🔧 SSH into the VM with: gcloud compute ssh ${var.vm_name} --zone=${var.zone}"
    echo "$(date): VM setup completed successfully!"
    echo "Startup script completed successfully" | sudo tee /var/log/wandb-startup-complete.log
  EOF
}

resource "google_compute_firewall" "allow_wandb" {
  count       = var.create_service && var.allow_public_access ? 1 : 0
  name        = "allow-wandb-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow wandb traffic to VM"
  allow {
    protocol = "tcp"
    ports    = [tostring(var.wandb_port)]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wandb-server"]
}

resource "google_compute_firewall" "allow_http_https" {
  count       = var.create_service ? 1 : 0
  name        = "allow-http-https-wandb-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow HTTP/HTTPS traffic to wandb VM"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "allow_lb_health_checks" {
  count       = var.create_service ? 1 : 0
  name        = "allow-lb-health-check-wandb-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow traffic for Load Balancer Health Checks"
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", tostring(var.wandb_port)]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lb-health-check"]
}

resource "google_compute_firewall" "allow_ssh" {
  count       = var.create_service ? 1 : 0
  name        = "allow-ssh-wandb-vm"
  network     = var.network
  project     = var.project_id
  description = "Allow SSH access to wandb VM"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"] # For Google IAP SSH. Use ["0.0.0.0/0"] for open SSH (not recommended for production)
  target_tags   = ["ssh-server"]
}

output "vm_external_ip" {
  description = "External IP address of the wandb VM"
  value       = var.create_service ? google_compute_instance.wandb_vm[0].network_interface[0].access_config[0].nat_ip : ""
}

output "wandb_url" {
  description = "URL to access wandb UI"
  value       = var.create_service ? "http://${google_compute_instance.wandb_vm[0].network_interface[0].access_config[0].nat_ip}:8080" : ""
}

output "service_url" {
  description = "Service URL for wandb (alias for wandb_url)"
  value       = var.create_service ? "http://${google_compute_instance.wandb_vm[0].network_interface[0].access_config[0].nat_ip}:8080" : ""
}

output "bucket_name" {
  description = "Name of the created artifact bucket"
  value       = var.create_bucket && var.artifact_bucket != "" ? google_storage_bucket.artifact[0].name : ""
}

output "vm_name" {
  description = "Name of the created VM instance"
  value       = var.create_service ? google_compute_instance.wandb_vm[0].name : ""
}

output "zone" {
  description = "Zone where the VM is deployed"
  value       = var.create_service ? google_compute_instance.wandb_vm[0].zone : ""
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = var.create_service ? "gcloud compute ssh ${google_compute_instance.wandb_vm[0].name} --zone=${google_compute_instance.wandb_vm[0].zone}" : ""
}

resource "google_storage_bucket_iam_member" "wandb_vm_artifact_access" {
  count  = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  bucket = google_storage_bucket.artifact[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vm_service_account.email}"
}
