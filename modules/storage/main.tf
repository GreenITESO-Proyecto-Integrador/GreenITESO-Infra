# Cloud Storage: private object storage (proposal P1, still pending
# integration per neon-db/docs — nothing here implies P1 is decided).
# Photo evidence and other objects stay out of Postgres; this bucket is where
# they would land once P1 is approved.

resource "google_storage_bucket" "objects" {
  name                        = "${var.app_name}-${var.environment}-objects"
  project                     = var.project_id
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}
