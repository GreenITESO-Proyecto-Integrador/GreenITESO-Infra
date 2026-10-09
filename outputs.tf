output "frontend_url" {
  description = "Public URL users open. Also the base for the Entra redirect URI (<url>/login)."
  value       = "https://${coalesce(var.domain, local.frontend_host)}"
}

output "backend_url" {
  description = "Direct Backend URL (the frontend proxies /api/ to it)."
  value       = module.backend.service_url
}

output "image_repository" {
  description = "Push images to <this>/backend:<tag> and <this>/frontend:<tag>."
  value       = module.platform.image_repository
}

output "secret_ids" {
  description = "Add values with: gcloud secrets versions add <id> --data-file=-"
  value       = module.platform.secret_ids
}

output "load_balancer_ip" {
  description = "Point the domain's A record here. Null when no domain is set."
  value       = one(module.network[*].load_balancer_ip)
}

output "storage_bucket_name" {
  value = module.storage.bucket_name
}

output "backend_service_account_email" {
  value = module.backend.runtime_service_account_email
}

output "uptime_check_id" {
  value = module.monitoring.uptime_check_id
}
