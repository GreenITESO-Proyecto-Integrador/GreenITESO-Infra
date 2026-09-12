# Root wiring for one environment (dev, staging, or production). Run this
# scaffold once per environment with a different var.environment / tfvars
# file / state backend — it does not fan out to all three itself.
#
# Persistence: the database is Neon Postgres (external to GCP), reached from
# Cloud Run via Secret Manager references — see modules/compute and
# neon-db/docs/neon-operations.md. modules/database (Cloud SQL) exists only
# for parity with the reference architecture diagram and stays off
# (var.enable_cloud_sql = false) unless the team deliberately decides to
# move off Neon.
#
# Auth: Firebase Authentication (OIDC/JWT) is the agreed provider per
# neon-db/AGENTS.md. It is not provisioned by this Terraform — Firebase
# project setup happens in the Firebase console/CLI, out of this scaffold's
# scope.

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  app_name    = var.app_name
  environment = var.environment
  location    = var.gcs_bucket_location
  labels      = var.labels
}

module "database" {
  source = "./modules/database"

  project_id       = var.project_id
  region           = var.region
  app_name         = var.app_name
  environment      = var.environment
  enable_cloud_sql = var.enable_cloud_sql
  labels           = var.labels
}

# Service account used only to send transactional email (the "Email Service
# Account" box in the reference diagram). Whether that's Gmail API, an SMTP
# relay, or a third-party provider's API key is a decision this scaffold
# doesn't make — the key/credential itself belongs in Secret Manager, not
# Terraform state, and isn't created here.
resource "google_service_account" "email_sender" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}-email"
  display_name = "${var.app_name} ${var.environment} email sender"
}

module "compute" {
  source = "./modules/compute"

  project_id              = var.project_id
  region                  = var.region
  app_name                = var.app_name
  environment             = var.environment
  container_image         = var.container_image
  cpu                     = var.cloud_run_cpu
  memory                  = var.cloud_run_memory
  min_instances           = var.cloud_run_min_instances
  max_instances           = var.cloud_run_max_instances
  db_app_pooled_secret_id = "DB_APP_POOLED_URL"
  labels                  = var.labels
}

module "network" {
  source = "./modules/network"

  project_id             = var.project_id
  region                 = var.region
  app_name               = var.app_name
  environment            = var.environment
  cloud_run_service_name = module.compute.service_name
  domain                 = var.domain
  labels                 = var.labels
}

module "cicd" {
  source = "./modules/cicd"

  project_id        = var.project_id
  region            = var.region
  app_name          = var.app_name
  environment       = var.environment
  github_repository = var.github_repository
  # var.environment (dev/staging/production) names the Neon branch and this
  # GCP environment; the app repos' Git/promote branches are dev/preprod/prod
  # (see GreenITESO-Backend & GreenITESO-Frontend .github/workflows/promote.yml).
  # This is the one place that naming mismatch gets bridged.
  trigger_branch = var.environment == "production" ? "prod" : var.environment == "staging" ? "preprod" : "dev"
}

module "monitoring" {
  source = "./modules/monitoring"

  project_id         = var.project_id
  app_name           = var.app_name
  environment        = var.environment
  check_host         = coalesce(var.domain, module.compute.service_url)
  notification_email = var.monitoring_notification_email
}
