variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "apis" {
  description = "Google APIs to enable."
  type        = list(string)
}

variable "secret_ids" {
  description = "Secret Manager secret IDs to create empty (values are added out of band)."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
