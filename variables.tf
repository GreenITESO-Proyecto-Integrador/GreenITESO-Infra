variable "project_id" {
  description = "GCP project ID. No project exists yet; this has no default on purpose."
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

variable "container_image" {
  description = "Fully qualified container image for the Cloud Run service. No image is built or pushed by this scaffold."
  type        = string
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

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances."
  type        = number
  default     = 4
}

variable "gcs_bucket_location" {
  description = "Location for the Cloud Storage bucket (object/evidence storage per proposal P1)."
  type        = string
  default     = "US"
}

variable "domain" {
  description = "Public domain served through the load balancer/CDN. Leave null until a domain is owned and DNS is delegated."
  type        = string
  default     = null
}

variable "github_repository" {
  description = "owner/repo for the Cloud Build trigger source (e.g. GreenITESO-Proyecto-Integrador/GreenITESO-Backend)."
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
