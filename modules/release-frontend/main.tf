# Identity for the Frontend GitHub release pipeline (Frontend repo:
# .github/workflows/deploy-production.yml + scripts/release.sh). It builds the
# image in GitHub Actions, pushes it, and deploys it to ONE Cloud Run service.
# There is no database and no migration, so it gets far less than the Backend
# deployer: every role below is scoped to the single resource it needs, not the
# whole project.

locals {
  # Service account IDs are limited to 30 characters.
  account_id = "${var.app_name}-${substr(var.environment, 0, 4)}-fe-deployer"
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = local.account_id
  display_name = "${var.app_name} ${var.environment} Frontend GitHub release deployer"
}

# Only jobs of the Frontend repository, in its GitHub Environment, may act as
# this account.
resource "google_service_account_iam_member" "github_impersonates_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repo_env/${var.github_repository}/${var.github_environment}"
}

# Create revisions of the Frontend service and shift its traffic (gcloud run
# deploy and update-traffic). Not run.admin: it cannot touch other services or
# change who may invoke this one.
resource "google_cloud_run_v2_service_iam_member" "deployer_develops" {
  project  = var.project_id
  location = var.region
  name     = var.service_name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# Push the image it builds, and read it back to resolve its digest. Scoped to the
# one repository, not every registry in the project.
resource "google_artifact_registry_repository_iam_member" "deployer_pushes" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

# Deploying a service "as" its runtime identity needs actAs on that identity.
resource "google_service_account_iam_member" "deployer_acts_as_runtime" {
  service_account_id = var.runtime_service_account_name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# gcloud calls project APIs on the deployer's behalf; this lets it use the
# project's enabled services and nothing else.
resource "google_project_iam_member" "deployer_service_usage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}
