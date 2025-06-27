resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$*+-.=_"

}

resource "google_sql_database_instance" "postgres" {
  name             = var.db_instance_name
  database_version = "POSTGRES_14"
  region           = var.region
  project          = var.project_id
  depends_on       = [google_project_service.required]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
      ipv4_enabled = true
    }
  }

  deletion_protection = false
}

resource "null_resource" "cleanup_postgres" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      gcloud sql connect ${google_sql_database_instance.postgres.name} --user=postgres --project=${var.project_id} --quiet --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${var.db_name}'; REASSIGN OWNED BY ${var.db_user} TO postgres; DROP OWNED BY ${var.db_user};"
    EOT
  }
  depends_on = [google_sql_database_instance.postgres]
}

resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres, null_resource.cleanup_postgres]
}

resource "google_sql_user" "users" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id
  depends_on = [google_sql_database_instance.postgres, null_resource.cleanup_postgres]
}

resource "google_project_service" "required" {
  for_each           = toset(var.gcp_service_list)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}




