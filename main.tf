# Root wiring for one environment (dev, staging, or production). Run this
# scaffold once per environment with a different var.environment / tfvars
# file / state backend — it does not fan out to all three itself.
#
# Persistence: the database is Neon Postgres (external to GCP), reached from
# Cloud Run via Secret Manager references — see modules/compute and
# neon-db/docs/neon-operations.md. There is deliberately no Cloud SQL module:
# Git dev/preprod/main maps to Neon dev/staging/production.
#
# Auth: Microsoft Entra ID is the provider implemented by the Backend. It is
# external to this Terraform scaffold and is not provisioned here.

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  app_name    = var.app_name
  environment = var.environment
  location    = var.gcs_bucket_location
  labels      = var.labels
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

  project_id            = var.project_id
  region                = var.region
  app_name              = var.app_name
  environment           = var.environment
  github_repository     = var.github_repository
  github_trigger_enabled = var.github_trigger_enabled
  # var.environment (dev/staging/production) names the Neon branch and this
  # GCP environment; the legacy Git branch prod is intentionally not a target.
  trigger_branch = var.environment == "production" ? "main" : var.environment == "staging" ? "preprod" : "dev"
}

module "monitoring" {
  source = "./modules/monitoring"

  project_id         = var.project_id
  app_name           = var.app_name
  environment        = var.environment
  check_host         = coalesce(var.domain, module.compute.service_url)
  notification_email = var.monitoring_notification_email
}
