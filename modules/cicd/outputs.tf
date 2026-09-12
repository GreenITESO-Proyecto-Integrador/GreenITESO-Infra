output "delivery_pipeline_id" {
  value = google_clouddeploy_delivery_pipeline.app.id
}

output "target_id" {
  value = google_clouddeploy_target.cloud_run.id
}
