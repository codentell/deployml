# FastAPI VM Module for GCP
# This module handles FastAPI deployment on a GCP VM instance

# Enable required Google Cloud APIs for FastAPI
resource "google_project_service" "fastapi_required_apis" {
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
  disable_on_destroy = false
}

# Wait for API propagation
resource "time_sleep" "wait_for_api_propagation" {
  depends_on = [google_project_service.fastapi_required_apis]
  create_duration = "120s"
}

# API readiness marker
resource "null_resource" "api_readiness_check" {
  depends_on = [time_sleep.wait_for_api_propagation]
  
  triggers = {
    api_wait_complete = timestamp()
  }
}

# Service account for the VM
resource "google_service_account" "fastapi_vm_sa" {
  account_id   = "fastapi-vm-sa"
  display_name = "Service Account for FastAPI VM"
  project      = var.project_id
  
  depends_on = [null_resource.api_readiness_check]
}

# Additional permissions for the VM service account
resource "google_project_iam_member" "fastapi_vm_logging" {
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.fastapi_vm_sa.email}"
  depends_on = [google_service_account.fastapi_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "fastapi_vm_monitoring" {
  project    = var.project_id
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${google_service_account.fastapi_vm_sa.email}"
  depends_on = [google_service_account.fastapi_vm_sa, null_resource.api_readiness_check]
}

# Google Compute Engine instance for FastAPI
resource "google_compute_instance" "fastapi_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  depends_on = [null_resource.api_readiness_check]

  boot_disk {
    initialize_params {
      image = var.image_family
      size  = var.disk_size_gb
      type  = var.disk_type
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.fastapi_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = local.fastapi_startup_script
  }

  tags = ["fastapi-server"]

  allow_stopping_for_update = true
}

# Local variables for startup script
locals {
  fastapi_startup_script = templatefile("${path.module}/startup_script.sh", {
    project_id = var.project_id,
    region = var.region,
    zone = var.zone,
    vm_name = var.vm_name,
    fastapi_port = var.fastapi_port,
    fastapi_app_source = var.fastapi_app_source,
    allow_public_access = var.allow_public_access,
    mlflow_tracking_uri = var.mlflow_tracking_uri,
    model_uri = var.model_uri,
    backend_store_uri = var.backend_store_uri,
    use_postgres = var.use_postgres,
    db_connection_string = var.db_connection_string,
    feast_service_url = var.feast_service_url,
    enable_feast_connection = var.enable_feast_connection
  })
}

# Firewall rule for FastAPI
resource "google_compute_firewall" "allow_fastapi" {
  name    = "allow-fastapi-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = [var.fastapi_port]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["fastapi-server"]
}

# Firewall rules for HTTP/HTTPS if needed
resource "google_compute_firewall" "allow_http_https" {
  count   = var.allow_public_access ? 1 : 0
  name    = "allow-http-https-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "allow_lb_health_checks" {
  count   = var.allow_public_access ? 1 : 0
  name    = "allow-lb-health-checks-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-server", "https-server"]
}
