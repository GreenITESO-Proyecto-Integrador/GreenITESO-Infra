variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repository" {
  description = "owner/repo of the Frontend whose Actions may deploy."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment (in the Frontend repo) allowed to impersonate the deployer."
  type        = string
  default     = "production"
}

variable "workload_identity_pool_name" {
  description = "Full name of the shared GitHub Workload Identity pool (from modules/release)."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service this deployer may update."
  type        = string
}

variable "runtime_service_account_name" {
  description = "Resource name of the Frontend runtime service account the release deploys as."
  type        = string
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository the deployer may push to."
  type        = string
}
