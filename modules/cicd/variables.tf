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
  description = "owner/repo for the Cloud Build trigger source. Leave null to skip creating a trigger."
  type        = string
  default     = null
}

variable "trigger_branch" {
  description = "Git branch that triggers a build for this environment (dev, preprod, or main)."
  type        = string
}
