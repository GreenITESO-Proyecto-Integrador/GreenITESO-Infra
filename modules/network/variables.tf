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

variable "cloud_run_service_name" {
  type = string
}

variable "domain" {
  description = "Public domain for the managed SSL cert and forwarding rule. Leave null until a domain is owned and delegated."
  type        = string
  default     = null
}

variable "labels" {
  type    = map(string)
  default = {}
}
