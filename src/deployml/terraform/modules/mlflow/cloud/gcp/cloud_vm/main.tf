# MLflow VM Module for GCP
# This module deploys MLflow on a GCP Compute Engine VM

# Enable required Google Cloud APIs for this module
resource "google_project_service" "mlflow_required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project = var.project_id
  service = each.value
  disable_on_destroy = false
}

# Wait for API propagation
resource "time_sleep" "wait_for_api_propagation" {
  depends_on = [google_project_service.mlflow_required_apis]
  create_duration = "120s"
}

# API readiness marker
resource "null_resource" "api_readiness_check" {
  depends_on = [time_sleep.wait_for_api_propagation]
  
  triggers = {
    api_wait_complete = timestamp()
  }
}

# Storage bucket for MLflow artifacts
resource "google_storage_bucket" "mlflow_artifact" {
  count         = var.create_bucket && var.artifact_bucket != "" ? 1 : 0
  name          = var.artifact_bucket
  location      = var.region
  force_destroy = true
  
  depends_on = [null_resource.api_readiness_check]
  
  labels = {
    component  = "mlflow-artifacts"
    managed-by = "terraform"
  }
}

# BigQuery dataset for Feast offline store
resource "google_bigquery_dataset" "feast_offline_store" {
  count       = var.create_bigquery_dataset ? 1 : 0
  dataset_id  = var.bigquery_dataset
  description = "BigQuery dataset for Feast offline store"
  location    = var.region
  project     = var.project_id
  
  depends_on = [null_resource.api_readiness_check]
  
  labels = {
    component  = "feast-offline-store"
    managed-by = "terraform"
  }
}

# Create sample sales data table for Feast if requested
resource "google_bigquery_table" "sample_sales_data" {
  count       = var.create_bigquery_dataset && var.sample_data ? 1 : 0
  dataset_id  = google_bigquery_dataset.feast_offline_store[0].dataset_id
  table_id    = "sample_sales_data"

  schema = <<EOF
[
  {
    "name": "customer_id",
    "type": "STRING",
    "mode": "REQUIRED"
  },
  {
    "name": "product_id", 
    "type": "STRING",
    "mode": "REQUIRED"
  },
  {
    "name": "sale_amount",
    "type": "FLOAT64",
    "mode": "REQUIRED"
  },
  {
    "name": "quantity",
    "type": "INT64",
    "mode": "REQUIRED"
  },
  {
    "name": "sale_date",
    "type": "TIMESTAMP",
    "mode": "REQUIRED"
  },
  {
    "name": "created_timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED"
  },
  {
    "name": "region",
    "type": "STRING",
    "mode": "REQUIRED"
  },
  {
    "name": "customer_segment",
    "type": "STRING",
    "mode": "REQUIRED"
  }
]
EOF

  deletion_protection = false
}

# Random ID for BigQuery job
resource "random_id" "job_suffix" {
  count   = var.create_bigquery_dataset && var.sample_data ? 1 : 0
  byte_length = 4
}

# Insert sample sales data
resource "google_bigquery_job" "insert_sample_data" {
  count   = var.create_bigquery_dataset && var.sample_data ? 1 : 0
  job_id  = "insert_sample_sales_data_${random_id.job_suffix[0].hex}"

  query {
    query = <<EOF
INSERT INTO `${var.project_id}.${var.bigquery_dataset}.sample_sales_data` 
(customer_id, product_id, sale_amount, quantity, sale_date, created_timestamp, region, customer_segment)
VALUES
('CUST_001', 'PROD_A', 29.99, 2, TIMESTAMP('2024-01-15 10:30:00'), TIMESTAMP('2024-01-15 10:30:00'), 'West', 'Premium'),
('CUST_002', 'PROD_B', 49.99, 1, TIMESTAMP('2024-01-15 11:15:00'), TIMESTAMP('2024-01-15 11:15:00'), 'East', 'Standard'),
('CUST_003', 'PROD_A', 29.99, 3, TIMESTAMP('2024-01-15 14:20:00'), TIMESTAMP('2024-01-15 14:20:00'), 'West', 'Premium'),
('CUST_004', 'PROD_C', 79.99, 1, TIMESTAMP('2024-01-15 16:45:00'), TIMESTAMP('2024-01-15 16:45:00'), 'South', 'Standard'),
('CUST_005', 'PROD_B', 49.99, 2, TIMESTAMP('2024-01-15 17:30:00'), TIMESTAMP('2024-01-15 17:30:00'), 'North', 'Premium')
EOF
  }

  depends_on = [google_bigquery_table.sample_sales_data]
}

# Service account for the VM
resource "google_service_account" "mlflow_vm_sa" {
  account_id   = "mlflow-vm-sa"
  display_name = "Service Account for MLflow VM"
  project      = var.project_id
  
  depends_on = [null_resource.api_readiness_check]
}

# IAM bindings for storage access
resource "google_project_iam_member" "mlflow_vm_storage_admin" {
  count      = var.artifact_bucket != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${google_service_account.mlflow_vm_sa.email}"
  depends_on = [google_service_account.mlflow_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "mlflow_vm_storage_viewer" {
  count      = var.artifact_bucket != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.mlflow_vm_sa.email}"
  depends_on = [google_service_account.mlflow_vm_sa, null_resource.api_readiness_check]
}

# Additional permissions for the VM service account
resource "google_project_iam_member" "mlflow_vm_logging" {
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.mlflow_vm_sa.email}"
  depends_on = [google_service_account.mlflow_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "mlflow_vm_monitoring" {
  project    = var.project_id
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${google_service_account.mlflow_vm_sa.email}"
  depends_on = [google_service_account.mlflow_vm_sa, null_resource.api_readiness_check]
}

# Google Compute Engine instance for MLflow
resource "google_compute_instance" "mlflow_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  depends_on = [
    null_resource.api_readiness_check
  ]

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
    email  = google_service_account.mlflow_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = local.mlflow_startup_script
  }

  tags = ["mlflow-server", "feast-server"]

  allow_stopping_for_update = true
}

# Local variables for startup script
locals {
  db_password = var.use_postgres ? var.db_password : ""
  
  postgres_connection_string = var.use_postgres ? "postgresql+psycopg2://mlflow:${local.db_password}@${var.postgres_host}:5432/mlflow" : ""
  backend_store_uri = var.use_postgres ? local.postgres_connection_string : "sqlite:///mlflow.db"
  
  mlflow_startup_script = templatefile("${path.module}/startup_script.sh", {
    project_id = var.project_id,
    region = var.region,
    zone = var.zone,
    vm_name = var.vm_name,
    mlflow_port = var.mlflow_port,
    fastapi_port = var.fastapi_port,
    artifact_bucket = var.artifact_bucket,
    backend_store_uri = local.backend_store_uri,
    use_postgres = var.use_postgres,
    postgres_host = var.postgres_host,
    postgres_port = "5432",
    postgres_database = "mlflow",
    postgres_user = "mlflow",
    postgres_password = local.db_password,
    fastapi_app_source = var.fastapi_app_source,
    allow_public_access = var.allow_public_access,
    # Feast Configuration Variables
    feast_port = var.feast_port,
    registry_type = var.registry_type,
    online_store_type = var.online_store_type,
    offline_store_type = var.offline_store_type,
    bigquery_dataset = var.bigquery_dataset,
    create_bigquery_dataset = var.create_bigquery_dataset,
    sample_data = var.sample_data
  })
}

# Firewall rules for MLflow access
resource "google_compute_firewall" "allow_mlflow" {
  name    = "allow-mlflow-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = [var.mlflow_port]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mlflow-server", "feast-server"]
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
  target_tags   = ["mlflow-server", "feast-server"]
}

# Firewall rule for Feast
resource "google_compute_firewall" "allow_feast" {
  name    = "allow-feast-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = [var.feast_port]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mlflow-server", "feast-server"]
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