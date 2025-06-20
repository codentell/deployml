# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Define a Google Compute Engine instance
resource "google_compute_instance" "docker_vm" {
  name         = "docker-vm-instance"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = image = "cos-cloud/cos-121-lts" # Or your preferred Linux distribution
      size = 10
      type = "pd-balanced"
    }
  }

  network_interface {
    network = "default" # Use the default VPC network
    access_config {
      # This block creates an ephemeral external IP address
    }
  

  # Service account (optional, but good practice)
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"] # Grant full access to Google Cloud APIs for simplicity, refine as needed
  }

  # Startup script to install Docker
  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      echo "Updating apt packages..."
      sudo apt-get update -y

      echo "Installing necessary packages for Docker..."
      sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

      echo "Adding Docker's official GPG key..."
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

      echo "Setting up the stable Docker repository..."
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

      echo "Updating apt packages again with new Docker repo..."
      sudo apt-get update -y

      echo "Installing Docker Engine..."
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io

      echo "Adding current user to docker group (optional, for non-root docker commands)..."
      # Assuming you'll connect as the default Debian user 'debian'
      sudo usermod -aG docker debian

      echo "Docker installation complete. Verifying..."
      sudo systemctl enable docker
      sudo systemctl start docker
      docker run hello-world # Test Docker installation

      echo "Startup script finished."

      echo "Pulling and running nginx container..."
      docker run -d -p 80:80 --name my-nginx nginx:latest
      echo "Startup script finished. Check http://<VM_EXTERNAL_IP> if firewall allows."
    EOF
  }

  tags = ["http-server", "https-server"] # Add firewall tags if you need to open ports

  can_ip_forward = true
}

# Create a service account for the VM (optional, but recommended for granular permissions)
resource "google_service_account" "vm_service_account" {
  account_id   = "docker-vm-sa"
  display_name = "Service Account for Docker VM"
  project      = var.project_id
}

# Firewall rule to allow HTTP/HTTPS traffic (if needed for applications running on Docker)
resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https-docker-vm"
  network = "default"
  project = var.project_id
  description = "Allow HTTP traffic to VMs with 'http-server' tag"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "allow_lb_health_checks" {
  name = "allow_lb-health-check-docker-vm"
  network = "default"
  project = var.project_id
  description = "Allow traffic for Load Balancer Health Checks"

  allow {
    protocol = "tcp"
    ports = ["80","443","8080"] # Common ports for health Checks
  }
  source_ranges = =["0.0.0.0/0"]
  target_tags = ["lb-health-check"]

}


# Output the external IP address of the VM
output "vm_external_ip" {
  value = google_compute_instance.docker_vm.network_interface[0].access_config[0].nat_ip
}