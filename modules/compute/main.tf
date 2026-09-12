# Cloud Run: the fullstack app container. Database connectivity is Neon
# Postgres, not Cloud SQL — the app role's pooled URL and the migrator's
# direct URL are both Secret Manager references, per
# neon-db/docs/neon-operations.md (T4). This module does not create those
# secrets; it only wires the service to reference them by name.

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}-run"
  display_name = "${var.app_name} ${var.environment} Cloud Run runtime"
}

resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "${var.app_name}-${var.environment}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = var.db_app_pooled_secret_id
            version = "latest"
          }
        }
      }

      dynamic "env" {
        for_each = var.extra_env_secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }
  }

  labels = var.labels
}

# Traffic reaches Cloud Run via the load balancer/CDN (see modules/network),
# not directly — but Cloud Run still needs a policy. Least-privilege default:
# only the load balancer's backend service can invoke it. Loosen explicitly
# per environment if a direct public Cloud Run URL is ever needed.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = var.invoker_member
}
