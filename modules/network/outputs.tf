output "load_balancer_ip" {
  value = var.domain != null ? google_compute_global_address.app[0].address : null
}

output "backend_service_id" {
  value = google_compute_backend_service.app.id
}

output "security_policy_id" {
  value = google_compute_security_policy.armor.id
}
