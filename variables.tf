variable "project_id" {
  description = "GCP project ID. No project ID has been configured or verified; this has no default on purpose."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "northamerica-south1"
}

variable "environment" {
  description = "Environment name (dev, staging, production). Must match the Neon branch and Cloud Run service naming convention documented in neon-db/docs/neon-operations.md."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "app_name" {
  description = "Base name used to derive resource names (Cloud Run service, buckets, etc.)."
  type        = string
  default     = "greeniteso"
}

variable "project_number" {
  description = "GCP project number (digits, not the ID). Used to compute Cloud Run's deterministic hostnames."
  type        = string
}

variable "backend_image" {
  description = "Backend image, e.g. <region>-docker.pkg.dev/<project>/greeniteso/backend@sha256:... (push after the first targeted apply creates the registry)."
  type        = string
}

variable "frontend_image" {
  description = "Frontend image, same registry as the backend."
  type        = string
}

variable "microsoft_client_id" {
  description = "Entra application (client) ID. Not a secret; the same value goes in the frontend build as VITE_MICROSOFT_CLIENT_ID."
  type        = string
}

variable "microsoft_tenant_id" {
  description = "Entra tenant the Backend validates tokens against (ITESO's tenant, per Backend docs/auth-microsoft-entra.md)."
  type        = string
  default     = "6f0348f2-e498-45c9-84f4-c6d81dcffdfe"
}

variable "backend_extra_env" {
  description = "Extra plain env vars for the backend (e.g. STAFF_EMAILS)."
  type        = map(string)
  default     = {}
}

variable "cloud_run_cpu" {
  description = "CPU allocation per Cloud Run instance."
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory allocation per Cloud Run instance."
  type        = string
  default     = "512Mi"
}

variable "cloud_run_min_instances" {
  description = "Minimum Cloud Run instances (0 allows scale-to-zero)."
  type        = number
  default     = 0
}

variable "frontend_max_instances" {
  description = "Maximum frontend instances. The backend is fixed at 1 (see main.tf)."
  type        = number
  default     = 2
}

variable "gcs_bucket_location" {
  description = "Location for the Cloud Storage bucket (object/evidence storage per proposal P1)."
  type        = string
  default     = "US"
}

variable "domain" {
  description = "Public domain served through the load balancer/CDN. Null skips the whole network module and uses the run.app URLs."
  type        = string
  default     = null
}

variable "monitoring_notification_email" {
  description = "Email address for Cloud Monitoring alert notifications. Leave null to skip creating a notification channel."
  type        = string
  default     = null
}

variable "labels" {
  description = "Common resource labels."
  type        = map(string)
  default = {
    project = "greeniteso"
  }
}
