output "deployer_service_account_email" {
  description = "Value for the GCP_SERVICE_ACCOUNT secret in the Frontend repo's production environment."
  value       = google_service_account.deployer.email
}
