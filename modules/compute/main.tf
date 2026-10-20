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

# Read/write/delete objects in the buckets this service is allowed to use.
# Keys are static labels so for_each works even when the bucket name is only
# known after apply.
resource "google_storage_bucket_iam_member" "object_admin" {
  for_each = var.bucket_object_admin

  bucket = each.value
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

# One Cloud Run service in one of two forms, chosen by var.release_managed:
#   app      - Terraform owns the image and environment (default; the Frontend).
#   released - an external pipeline (`gcloud run deploy`) owns them, so Terraform
#              ignores those fields after creating the service (the Backend).
# The two have the same settings otherwise. Moving a *live* service between them
# is a state move, not a flag flip: `terraform state mv` the resource, or
# Terraform will plan to destroy and recreate it.
moved {
  from = google_cloud_run_v2_service.app
  to   = google_cloud_run_v2_service.app[0]
}

resource "google_cloud_run_v2_service" "app" {
  count = var.release_managed ? 0 : 1

  project  = var.project_id
  name     = "${var.app_name}-${var.environment}-${var.service_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = var.labels

  template {
    service_account       = google_service_account.runtime.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

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
        # Request-based CPU billing. The v2 API default is "always allocated",
        # which also rejects memory below 512Mi.
        cpu_idle          = true
        startup_cpu_boost = true
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

resource "google_cloud_run_v2_service" "released" {
  count = var.release_managed ? 1 : 0

  project  = var.project_id
  name     = "${var.app_name}-${var.environment}-${var.service_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = var.labels

  template {
    service_account       = google_service_account.runtime.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

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
        # Request-based CPU billing. The v2 API default is "always allocated",
        # which also rejects memory below 512Mi.
        cpu_idle          = true
        startup_cpu_boost = true
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

  # `gcloud run deploy` (the Backend's release pipeline) updates these on every
  # release. Terraform sets them when it creates the service and then leaves them
  # alone, otherwise each `terraform apply` would roll the service back to the
  # image and environment in the tfvars. Every field in this list is also
  # something Terraform sets once; change them through a release, not here.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,
      template[0].containers[0].command,
      template[0].containers[0].args,
      template[0].revision,
      template[0].max_instance_request_concurrency,
      client,
      client_version,
    ]
  }

  depends_on = [google_secret_manager_secret_iam_member.runtime_access]
}

# Users reach the app directly (or through the load balancer when a domain is
# set), so the service must be invocable by anyone. Authentication happens in
# the application (Entra ID + JWT), not at the Cloud Run layer. An org policy
# restricting allUsers will make this fail at apply time.
locals {
  service_name = var.release_managed ? google_cloud_run_v2_service.released[0].name : google_cloud_run_v2_service.app[0].name
  service_uri  = var.release_managed ? google_cloud_run_v2_service.released[0].uri : google_cloud_run_v2_service.app[0].uri
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = var.public ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = local.service_name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
