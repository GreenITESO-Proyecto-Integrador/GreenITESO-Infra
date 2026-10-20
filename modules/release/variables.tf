variable "project_id" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repository" {
  description = "owner/repo whose Actions may authenticate (the Backend repo)."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment allowed to impersonate the deployer (carries the reviewers)."
  type        = string
  default     = "production"
}

variable "runtime_service_account_name" {
  description = "Resource name of the Backend runtime service account the release deploys as."
  type        = string
}

variable "migrator_secret_ids" {
  description = "Secret IDs the migration service account may read (direct DB URL, Django key)."
  type        = list(string)
}
