output "service_name" {
  value = local.service_name
}

output "service_url" {
  value = local.service_uri
}

output "runtime_service_account_email" {
  value = google_service_account.runtime.email
}

output "runtime_service_account_name" {
  description = "Resource name (projects/.../serviceAccounts/...) used for actAs bindings."
  value       = google_service_account.runtime.name
}
