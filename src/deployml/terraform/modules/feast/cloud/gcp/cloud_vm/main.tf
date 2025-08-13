# Feast VM Module for GCP
# This module handles Feast deployment on a GCP VM instance

# Enable required Google Cloud APIs for Feast
resource "google_project_service" "feast_required_apis" {
  for_each = toset([
    "compute.googleapis.com",                   # Compute Engine (VMs, disks, networks)
    "storage.googleapis.com",                   # Cloud Storage (artifact buckets)
    "iam.googleapis.com",                       # Identity and Access Management
    "iamcredentials.googleapis.com",            # IAM Service Account Credentials
    "logging.googleapis.com",                   # Cloud Logging
    "monitoring.googleapis.com",                # Cloud Monitoring
    "serviceusage.googleapis.com",              # Service Usage (for enabling APIs)
    "cloudresourcemanager.googleapis.com",     # Cloud Resource Manager (project operations)
    "bigquery.googleapis.com",                  # BigQuery API (for Feast offline store)
    "datastore.googleapis.com",                 # Datastore API (for Feast online store option)
    "bigtable.googleapis.com",                  # Bigtable API (for Feast online store option)
  ])

  project = var.project_id
  service = each.value
  disable_on_destroy = false
}

# Wait for API propagation
resource "time_sleep" "wait_for_api_propagation" {
  depends_on = [google_project_service.feast_required_apis]
  create_duration = "120s"
}

# API readiness marker
resource "null_resource" "api_readiness_check" {
  depends_on = [time_sleep.wait_for_api_propagation]
  
  triggers = {
    api_wait_complete = timestamp()
  }
}

# BigQuery dataset for Feast offline store
resource "google_bigquery_dataset" "feast_offline_store" {
  count       = var.create_bigquery_dataset ? 1 : 0
  dataset_id  = var.bigquery_dataset
  project     = var.project_id
  location    = var.region
  
  description = "Feast offline store dataset"
  
  labels = {
    component  = "feast-offline-store"
    managed-by = "terraform"
  }
  
  depends_on = [null_resource.api_readiness_check]
}

# Service account for the VM
resource "google_service_account" "feast_vm_sa" {
  account_id   = "feast-vm-sa"
  display_name = "Service Account for Feast VM"
  project      = var.project_id
  
  depends_on = [null_resource.api_readiness_check]
}

# BigQuery permissions for Feast
resource "google_project_iam_member" "feast_vm_bigquery_user" {
  project    = var.project_id
  role       = "roles/bigquery.user"
  member     = "serviceAccount:${google_service_account.feast_vm_sa.email}"
  depends_on = [google_service_account.feast_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "feast_vm_bigquery_data_editor" {
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.feast_vm_sa.email}"
  depends_on = [google_service_account.feast_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "feast_vm_bigquery_job_user" {
  project    = var.project_id
  role       = "roles/bigquery.jobUser"
  member     = "serviceAccount:${google_service_account.feast_vm_sa.email}"
  depends_on = [google_service_account.feast_vm_sa, null_resource.api_readiness_check]
}

# Additional permissions for the VM service account
resource "google_project_iam_member" "feast_vm_logging" {
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${google_service_account.feast_vm_sa.email}"
  depends_on = [google_service_account.feast_vm_sa, null_resource.api_readiness_check]
}

resource "google_project_iam_member" "feast_vm_monitoring" {
  project    = var.project_id
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${google_service_account.feast_vm_sa.email}"
  depends_on = [google_service_account.feast_vm_sa, null_resource.api_readiness_check]
}

# Google Compute Engine instance for Feast
resource "google_compute_instance" "feast_vm" {
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
    email  = google_service_account.feast_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = local.feast_startup_script
  }

  tags = ["feast-server"]

  allow_stopping_for_update = true
}

# Local variables for startup script
locals {
  feast_startup_script = templatefile("${path.module}/startup_script.sh", {
    project_id = var.project_id,
    region = var.region,
    zone = var.zone,
    vm_name = var.vm_name,
    feast_port = var.feast_port,
    backend_store_uri = var.backend_store_uri,
    use_postgres = var.use_postgres,
    postgres_host = var.postgres_host,
    postgres_port = var.postgres_port,
    postgres_database = var.postgres_database,
    postgres_user = var.postgres_user,
    postgres_password = var.postgres_password,
    bigquery_dataset = var.bigquery_dataset,
    registry_type = var.registry_type,
    online_store_type = var.online_store_type,
    offline_store_type = var.offline_store_type,
    artifact_bucket = var.artifact_bucket
  })
}

# Firewall rule for Feast server
resource "google_compute_firewall" "allow_feast" {
  name    = "allow-feast-${var.vm_name}"
  network = "default"
  
  depends_on = [null_resource.api_readiness_check]
  
  allow {
    protocol = "tcp"
    ports    = [var.feast_port]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["feast-server"]
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

# Insert sample sales data
resource "google_bigquery_job" "insert_sample_data" {
  count   = var.create_bigquery_dataset && var.sample_data ? 1 : 0
  job_id  = "insert_sample_sales_data_${random_id.job_suffix[0].hex}"

  query {
    query = <<EOF
INSERT INTO `${var.project_id}.${var.bigquery_dataset}.sample_sales_data` 
(customer_id, product_id, sale_amount, quantity, sale_date, created_timestamp, region, customer_segment)
VALUES
('CUST001', 'PROD001', 299.99, 1, TIMESTAMP('2024-01-15 10:30:00'), TIMESTAMP('2024-01-15 10:30:00'), 'West', 'Premium'),
('CUST002', 'PROD002', 149.50, 2, TIMESTAMP('2024-01-15 11:15:00'), TIMESTAMP('2024-01-15 11:15:00'), 'East', 'Standard'),
('CUST003', 'PROD001', 599.98, 2, TIMESTAMP('2024-01-15 14:20:00'), TIMESTAMP('2024-01-15 14:20:00'), 'North', 'Premium'),
('CUST004', 'PROD003', 89.99, 1, TIMESTAMP('2024-01-15 16:45:00'), TIMESTAMP('2024-01-15 16:45:00'), 'South', 'Standard'),
('CUST005', 'PROD002', 448.50, 3, TIMESTAMP('2024-01-16 09:30:00'), TIMESTAMP('2024-01-16 09:30:00'), 'West', 'Premium'),
('CUST006', 'PROD001', 299.99, 1, TIMESTAMP('2024-01-16 12:00:00'), TIMESTAMP('2024-01-16 12:00:00'), 'East', 'Standard'),
('CUST007', 'PROD003', 179.98, 2, TIMESTAMP('2024-01-16 15:30:00'), TIMESTAMP('2024-01-16 15:30:00'), 'North', 'Premium'),
('CUST008', 'PROD002', 149.50, 1, TIMESTAMP('2024-01-16 17:15:00'), TIMESTAMP('2024-01-16 17:15:00'), 'South', 'Standard'),
('CUST009', 'PROD001', 899.97, 3, TIMESTAMP('2024-01-17 08:45:00'), TIMESTAMP('2024-01-17 08:45:00'), 'West', 'Premium'),
('CUST010', 'PROD003', 269.97, 3, TIMESTAMP('2024-01-17 11:30:00'), TIMESTAMP('2024-01-17 11:30:00'), 'East', 'Standard')
EOF

    destination_table {
      project_id = var.project_id
      dataset_id = var.bigquery_dataset
      table_id   = "sample_sales_data"
    }
  }

  depends_on = [google_bigquery_table.sample_sales_data]
}

resource "random_id" "job_suffix" {
  count       = var.create_bigquery_dataset && var.sample_data ? 1 : 0
  byte_length = 4
}