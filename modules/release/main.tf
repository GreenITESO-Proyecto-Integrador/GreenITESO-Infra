# Identities and trust the GitHub release pipeline (Backend repo: _deploy.yml +
# scripts/release.sh) needs to migrate and deploy production without any key
# files: Workload Identity Federation for GitHub, a deployer service account
# and a separate migration service account. Nothing here is a secret.
#
# The pipeline runs `gcloud run jobs create/update/execute` and
# `gcloud run deploy`, builds and pushes an image, and mounts secrets, so the
# deployer needs those roles and must be allowed to act as the two runtime
# identities.

locals {
  trusted_repositories = concat([var.github_repository], var.extra_github_repositories)
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}-deployer"
  display_name = "${var.app_name} ${var.environment} GitHub release deployer"
}

# Separate from the runtime account on purpose: release.sh rejects identical
# runtime and migration accounts. This one only reads the direct (migrator) URL.
resource "google_service_account" "migrator" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}-migrator"
  display_name = "${var.app_name} ${var.environment} migration job"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.app_name}-github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
    # repository + environment in one attribute, so a service account can be
    # bound to "this repo, in this environment" and not to the environment name
    # alone (which any repository in the pool could also claim).
    "attribute.repo_env" = "assertion.repository + \"/\" + assertion.environment"
  }

  # Only tokens minted for these repositories are accepted at all. Each repo is
  # then bound to its own service account below.
  attribute_condition = "assertion.repository in [${join(", ", [for r in local.trusted_repositories : "\"${r}\""])}]"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Only jobs of THIS repository running in the GitHub Environment named below may
# impersonate the deployer. Binding by environment name alone would let any other
# trusted repository in the pool claim the same environment and reuse it.
resource "google_service_account_iam_member" "github_impersonates_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_env/${var.github_repository}/${var.github_environment}"
}

locals {
  deployer_roles = [
    "roles/run.admin",               # create/update the service and the two jobs
    "roles/artifactregistry.writer", # push the image it builds
    "roles/artifactregistry.reader", # resolve the image digest
    "roles/secretmanager.viewer",    # release.sh validates the secret references
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Deploying a service or job "as" another identity needs actAs on it.
resource "google_service_account_iam_member" "deployer_acts_as" {
  for_each = {
    runtime  = var.runtime_service_account_name
    migrator = google_service_account.migrator.name
  }

  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# The migration job reads the direct URL and the Django key; it never gets the
# pooled app URL or the evidence bucket.
resource "google_secret_manager_secret_iam_member" "migrator_reads" {
  for_each = toset(var.migrator_secret_ids)

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.migrator.email}"
}
