# Cloud SQL — matches the reference architecture diagram, but the project's
# actual database is Neon Postgres (see neon-db/docs/neon-inventario.md and
# neon-db/docs/neon-operations.md). This module is scaffolded for shape
# parity only and is gated by var.enable_cloud_sql (default false) so it
# never provisions a second, unused Postgres instance by accident.
#
# If the team ever decides to move off Neon onto Cloud SQL, this is the
# starting point — but that migration is a deliberate decision to make
# first, not a side effect of running `terraform apply`.

resource "google_sql_database_instance" "this" {
  count = var.enable_cloud_sql ? 1 : 0

  project          = var.project_id
  name             = "${var.app_name}-${var.environment}"
  region           = var.region
  database_version = "POSTGRES_18"

  settings {
    tier              = var.tier
    availability_type = var.environment == "production" ? "REGIONAL" : "ZONAL"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled = false
    }

    user_labels = var.labels
  }

  deletion_protection = var.environment == "production"
}

resource "google_sql_database" "app" {
  count = var.enable_cloud_sql ? 1 : 0

  project  = var.project_id
  name     = var.app_name
  instance = google_sql_database_instance.this[0].name
}
