# Root wiring for one environment (dev, staging, or production). Run this
# once per environment with its own tfvars and state prefix; it does not fan
# out to all three itself.
#
# Persistence: the database is Neon Postgres (external to GCP), reached from
# Cloud Run via a Secret Manager secret holding the pooled app URL. There is
# deliberately no Cloud SQL. Git dev/preprod/prod maps to Neon dev/staging/
# production.
#
# Auth: Microsoft Entra ID is implemented by the Backend and is external to
# this Terraform.
#
# Two Cloud Run services (backend, frontend) share one origin from the
# browser's point of view: the frontend's nginx proxies /api/ to the backend,
# or the load balancer does the same when a domain is set. Production Backend
# has CORS disabled, so a shared origin is required.

locals {
  name_prefix = "${var.app_name}-${var.environment}"

  # Cloud Run's deterministic service hostnames. Computing them here avoids a
  # dependency cycle (the backend needs its own host in ALLOWED_HOSTS).
  backend_host  = "${local.name_prefix}-backend-${var.project_number}.${var.region}.run.app"
  frontend_host = "${local.name_prefix}-frontend-${var.project_number}.${var.region}.run.app"

  secret_ids = {
    DJANGO_SECRET_KEY = "${local.name_prefix}-django-secret-key"
    DATABASE_URL      = "${local.name_prefix}-database-url"
  }

  # Direct (unpooled) migrator URL: only the release pipeline's migration job
  # reads it. Created empty here; the value is added by hand, like the others.
  database_url_unpooled_secret = "${local.name_prefix}-database-url-unpooled"

  apis = concat(
    [
      "run.googleapis.com",
      "artifactregistry.googleapis.com",
      "secretmanager.googleapis.com",
      "iam.googleapis.com",
      "monitoring.googleapis.com",
      "storage.googleapis.com",
    ],
    var.domain != null ? ["compute.googleapis.com"] : [],
  )
}

module "platform" {
  source = "./modules/platform"

  project_id = var.project_id
  region     = var.region
  app_name   = var.app_name
  apis       = local.apis
  secret_ids = concat(values(local.secret_ids), var.enable_release_pipeline ? [local.database_url_unpooled_secret] : [])
  labels     = var.labels
}

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  app_name    = var.app_name
  environment = var.environment
  location    = var.gcs_bucket_location
  labels      = var.labels

  depends_on = [module.platform]
}

module "backend" {
  source = "./modules/compute"

  project_id      = var.project_id
  region          = var.region
  app_name        = var.app_name
  environment     = var.environment
  service_name    = "backend"
  container_image = var.backend_image
  container_port  = 8000
  cpu             = var.cloud_run_cpu
  memory          = var.cloud_run_memory
  min_instances   = var.cloud_run_min_instances
  # Pinned to 1: notifications use an in-memory channel layer, so a second
  # instance would silently drop real-time events. See Backend docs/deployment.md.
  max_instances = 1

  env = merge(
    {
      DJANGO_ENV             = var.environment
      DJANGO_DEPLOYED        = "true"
      DJANGO_CONNECTION_ROLE = "app"
      # The frontend host is needed too: the notifications WebSocket validates
      # the browser's Origin (the frontend) against ALLOWED_HOSTS.
      DJANGO_ALLOWED_HOSTS = join(",", compact([local.backend_host, local.frontend_host, var.domain]))
      MICROSOFT_AUTH_MODE  = "entra"
      MICROSOFT_TENANT_ID  = var.microsoft_tenant_id
      MICROSOFT_CLIENT_ID  = var.microsoft_client_id
      WEB_CONCURRENCY      = "1"
      # Private bucket for action-evidence photos (created by modules/storage).
      GCS_EVIDENCE_BUCKET = module.storage.bucket_name
    },
    var.backend_extra_env,
  )

  secret_env          = local.secret_ids
  release_managed     = var.enable_release_pipeline
  bucket_object_admin = { evidence = module.storage.bucket_name }
  labels              = var.labels

  depends_on = [module.platform]
}

module "frontend" {
  source = "./modules/compute"

  project_id      = var.project_id
  region          = var.region
  app_name        = var.app_name
  environment     = var.environment
  service_name    = "frontend"
  container_image = var.frontend_image
  container_port  = 8080
  cpu             = "1"
  memory          = "512Mi"
  min_instances   = var.cloud_run_min_instances
  max_instances   = var.frontend_max_instances

  # Read by the frontend image's nginx template to proxy /api/ to the backend.
  env = {
    BACKEND_URL  = "https://${local.backend_host}"
    BACKEND_HOST = local.backend_host
  }

  labels = var.labels

  depends_on = [module.platform]
}

# Edge layer: only when a domain is set.
module "network" {
  count  = var.domain != null ? 1 : 0
  source = "./modules/network"

  project_id            = var.project_id
  region                = var.region
  app_name              = var.app_name
  environment           = var.environment
  frontend_service_name = module.frontend.service_name
  backend_service_name  = module.backend.service_name
  domain                = var.domain
}

module "monitoring" {
  source = "./modules/monitoring"

  project_id         = var.project_id
  app_name           = var.app_name
  environment        = var.environment
  check_host         = coalesce(var.domain, local.frontend_host)
  notification_email = var.monitoring_notification_email

  depends_on = [module.platform]
}

# GitHub release pipeline identities (optional). The pipeline then builds the
# image, runs the migration and smoke jobs, and deploys the Backend itself.
module "release" {
  count  = var.enable_release_pipeline ? 1 : 0
  source = "./modules/release"

  project_id                   = var.project_id
  app_name                     = var.app_name
  environment                  = var.environment
  github_repository            = var.github_repository
  runtime_service_account_name = module.backend.runtime_service_account_name
  migrator_secret_ids = [
    module.platform.secret_ids[local.database_url_unpooled_secret],
    module.platform.secret_ids[local.secret_ids.DJANGO_SECRET_KEY],
  ]

  depends_on = [module.platform]
}
