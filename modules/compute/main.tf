# One Cloud Run service. The root module instantiates it twice (backend and
# frontend). Secrets are referenced from Secret Manager by ID; this module
# grants the runtime service account read access but never creates secrets or
# their values (see modules/platform).

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}-${var.service_name}"
  display_name = "${var.app_name} ${var.environment} ${var.service_name} runtime"
}

resource "google_secret_manager_secret_iam_member" "runtime_access" {
  for_each = var.secret_env

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "${var.app_name}-${var.environment}-${var.service_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = var.labels

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env
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

  depends_on = [google_secret_manager_secret_iam_member.runtime_access]
}

# Users reach the app directly (or through the load balancer when a domain is
# set), so the service must be invocable by anyone. Authentication happens in
# the application (Entra ID + JWT), not at the Cloud Run layer. An org policy
# restricting allUsers will make this fail at apply time.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = var.public ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
