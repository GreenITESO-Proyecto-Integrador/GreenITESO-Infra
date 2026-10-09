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
  secret_ids = values(local.secret_ids)
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
      DJANGO_ALLOWED_HOSTS   = join(",", compact([local.backend_host, var.domain]))
      MICROSOFT_AUTH_MODE    = "entra"
      MICROSOFT_TENANT_ID    = var.microsoft_tenant_id
      MICROSOFT_CLIENT_ID    = var.microsoft_client_id
      WEB_CONCURRENCY        = "1"
    },
    var.backend_extra_env,
  )

  secret_env = local.secret_ids
  labels     = var.labels

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
  memory          = "256Mi"
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
