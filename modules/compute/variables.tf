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

variable "container_image" {
  type = string
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
  default = 4
}

variable "db_app_pooled_secret_id" {
  description = "Secret Manager secret ID holding the Neon app-role pooled connection string (DB_APP_POOLED_URL in neon-db/docs/neon-operations.md). Not created by this module."
  type        = string
}

variable "extra_env_secrets" {
  description = "Additional env var name -> Secret Manager secret ID pairs (e.g. Microsoft Entra ID config, email service credentials)."
  type        = map(string)
  default     = {}
}

variable "invoker_member" {
  description = "IAM member allowed to invoke the Cloud Run service (roles/run.invoker). Defaults to no public access; set to the load balancer's service agent or \"allUsers\" deliberately."
  type        = string
  default     = "serviceAccount:PLACEHOLDER-set-to-load-balancer-service-agent"
}

variable "labels" {
  type    = map(string)
  default = {}
}
