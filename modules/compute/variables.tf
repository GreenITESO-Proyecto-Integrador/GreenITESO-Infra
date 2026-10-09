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

variable "service_name" {
  description = "Short service name appended to the resource names (backend, frontend)."
  type        = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 1
}

variable "env" {
  description = "Plain (non-secret) environment variables."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Env var name -> Secret Manager secret ID. The runtime service account gets read access to each."
  type        = map(string)
  default     = {}
}

variable "public" {
  description = "Allow unauthenticated invocation (roles/run.invoker for allUsers)."
  type        = bool
  default     = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
