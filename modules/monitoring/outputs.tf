output "uptime_check_id" {
  value = google_monitoring_uptime_check_config.http.uptime_check_id
}

output "alert_policy_id" {
  value = google_monitoring_alert_policy.uptime_failure.id
}
