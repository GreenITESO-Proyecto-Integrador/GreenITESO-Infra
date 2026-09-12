output "service_name" {
  value = google_cloud_run_v2_service.app.name
}

output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "runtime_service_account_email" {
  value = google_service_account.runtime.email
}
