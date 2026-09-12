# Cloud Monitoring: uptime check against the load balancer every 1 minute,
# plus an alert policy that pages when it fails. This is the T16 "minimum
# monitoring" from neon-db/docs/database-monitoring.md applied to the edge
# layer — it does not replace the Neon-side checklist in that doc, which
# covers the database itself and still has to be done from the Neon console.

resource "google_monitoring_uptime_check_config" "http" {
  project      = var.project_id
  display_name = "${var.app_name}-${var.environment}-uptime"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.check_host
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email != null ? 1 : 0
  project      = var.project_id
  display_name = "${var.app_name}-${var.environment}-email"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_alert_policy" "uptime_failure" {
  project      = var.project_id
  display_name = "${var.app_name}-${var.environment}-uptime-failure"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failing"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.http.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
      }
    }
  }

  notification_channels = var.notification_email != null ? [google_monitoring_notification_channel.email[0].id] : []
}
