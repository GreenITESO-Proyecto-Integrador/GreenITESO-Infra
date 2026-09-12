variable "project_id" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "check_host" {
  description = "Hostname or IP the uptime check pings (the load balancer's address/domain)."
  type        = string
}

variable "notification_email" {
  description = "Email address for alert notifications. Leave null to skip creating a channel (the alert policy will then have no destination)."
  type        = string
  default     = null
}
