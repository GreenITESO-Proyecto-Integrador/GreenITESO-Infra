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
  description = "owner/repo for the Cloud Build trigger source. Requires github_trigger_enabled=true to create a trigger."
  type        = string
  default     = null
}

variable "github_trigger_enabled" {
  description = "Keep false until Cloud Build invokes the same reviewed database migration gate as the canonical release path."
  type        = bool
  default     = false
}

variable "trigger_branch" {
  description = "Scaffold branch mapping (dev, preprod, or main); keep the trigger disabled until migration gating is integrated."
  type        = string
}
