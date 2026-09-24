# Cloud Build builds the image on push; Cloud Deploy promotes it to the
# Cloud Run target for this environment. This is separate from each app
# repo's own GitHub Actions CI (lint/tests/promote-PR gating) — those still
# decide *whether* code is good; this decides how an approved build actually
# reaches Cloud Run.

resource "google_cloudbuild_trigger" "build" {
  count       = var.github_trigger_enabled && var.github_repository != null ? 1 : 0
  project     = var.project_id
  name        = "${var.app_name}-${var.environment}-build"
  description = "Build ${var.app_name} on push to ${var.trigger_branch} (${var.environment})"
  location    = var.region

  github {
    owner = split("/", var.github_repository)[0]
    name  = split("/", var.github_repository)[1]
    push {
      branch = "^${var.trigger_branch}$"
    }
  }

  filename = "cloudbuild.yaml"
}

resource "google_clouddeploy_target" "cloud_run" {
  project  = var.project_id
  location = var.region
  name     = "${var.app_name}-${var.environment}"

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  require_approval = var.environment == "production"
}

resource "google_clouddeploy_delivery_pipeline" "app" {
  project  = var.project_id
  location = var.region
  name     = "${var.app_name}-${var.environment}-pipeline"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.cloud_run.name
      profiles  = []
    }
  }
}
