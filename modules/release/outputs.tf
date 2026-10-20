output "workload_identity_provider" {
  description = "Value for the GCP_WORKLOAD_IDENTITY_PROVIDER GitHub secret."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account_email" {
  description = "Value for the GCP_SERVICE_ACCOUNT GitHub secret."
  value       = google_service_account.deployer.email
}

output "migrator_service_account_email" {
  description = "Value for the MIGRATION_SERVICE_ACCOUNT GitHub secret."
  value       = google_service_account.migrator.email
}
