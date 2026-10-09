output "load_balancer_ip" {
  description = "Point the domain's DNS A record at this address."
  value       = google_compute_global_address.app.address
}

output "security_policy_id" {
  value = google_compute_security_policy.armor.id
}
