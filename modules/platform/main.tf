# Everything the other modules assume already exists: enabled APIs, the image
# registry, and empty Secret Manager secrets. Secret *values* are never in
# Terraform: add them with `gcloud secrets versions add` so they stay out of
# state.

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.app_name
  format        = "DOCKER"
  description   = "${var.app_name} container images"
  labels        = var.labels

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "secrets" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value
  labels    = var.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}
