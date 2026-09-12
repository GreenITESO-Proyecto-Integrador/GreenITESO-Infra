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

variable "enable_cloud_sql" {
  type    = bool
  default = false
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "labels" {
  type    = map(string)
  default = {}
}
