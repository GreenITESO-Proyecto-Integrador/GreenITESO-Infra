output "bucket_name" {
  value = google_storage_bucket.objects.name
}

output "bucket_url" {
  value = google_storage_bucket.objects.url
}
