resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!*-_."
}

resource "google_sql_database_instance" "postgres" {
  name             = var.db_instance_name
  database_version = "POSTGRES_14"
  region           = var.region
  project          = var.project_id
  depends_on       = [google_project_service.required]

  settings {
    tier = var.db_tier
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
      ipv4_enabled = true
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres]
}

resource "google_sql_database" "feast_db" {
  name     = "feast"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres]
  
  lifecycle {
    ignore_changes = [name]
  }
}

resource "google_sql_database" "metrics_db" {
  name     = "metrics"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres]
  
  lifecycle {
    ignore_changes = [name]
  }
}

resource "google_sql_user" "users" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres]
}

resource "google_project_service" "required" {
  for_each           = toset(var.gcp_service_list)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}




