output "image_repository" {
  description = "Docker repository path; images are <this>/<name>:<tag>."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "secret_ids" {
  value = { for k, s in google_secret_manager_secret.secrets : k => s.secret_id }
}
