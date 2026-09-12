output "cloud_run_service_url" {
  description = "Direct Cloud Run URL (not the public entry point; traffic should go through the load balancer once a domain is configured)."
  value       = module.compute.service_url
}

output "load_balancer_ip" {
  description = "Public IP of the HTTPS load balancer. Null until var.domain is set."
  value       = module.network.load_balancer_ip
}

output "storage_bucket_name" {
  value = module.storage.bucket_name
}

output "runtime_service_account_email" {
  value = module.compute.runtime_service_account_email
}

output "email_sender_service_account_email" {
  value = google_service_account.email_sender.email
}

output "cloud_sql_connection_name" {
  description = "Null unless var.enable_cloud_sql is true (the project's actual database is Neon, see neon-db/)."
  value       = module.database.connection_name
}

output "delivery_pipeline_id" {
  value = module.cicd.delivery_pipeline_id
}

output "uptime_check_id" {
  value = module.monitoring.uptime_check_id
}
