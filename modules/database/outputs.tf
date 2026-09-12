output "connection_name" {
  value = var.enable_cloud_sql ? google_sql_database_instance.this[0].connection_name : null
}

output "instance_name" {
  value = var.enable_cloud_sql ? google_sql_database_instance.this[0].name : null
}
