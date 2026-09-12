# Edge network layer: external HTTPS load balancer -> Cloud Armor -> Cloud CDN
# -> Cloud Run (via a serverless NEG). This is the public entry point; Cloud
# Run itself is only invocable by the load balancer (see modules/compute).

resource "google_compute_region_network_endpoint_group" "cloud_run" {
  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_security_policy" "armor" {
  project     = var.project_id
  name        = "${var.app_name}-${var.environment}-armor"
  description = "Cloud Armor policy for ${var.environment}. Starts default-allow; add deny/rate-limit rules deliberately once traffic patterns are known."

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule: allow all (placeholder until real WAF rules are defined)."
  }
}

resource "google_compute_backend_service" "app" {
  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-backend"
  protocol              = "HTTPS"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.armor.id

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run.id
  }

  enable_cdn = true
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    client_ttl                   = 3600
    default_ttl                  = 3600
    max_ttl                      = 86400
    signed_url_cache_max_age_sec = 0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "app" {
  project         = var.project_id
  name            = "${var.app_name}-${var.environment}-urlmap"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_managed_ssl_certificate" "app" {
  count   = var.domain != null ? 1 : 0
  project = var.project_id
  name    = "${var.app_name}-${var.environment}-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "app" {
  count            = var.domain != null ? 1 : 0
  project          = var.project_id
  name             = "${var.app_name}-${var.environment}-https-proxy"
  url_map          = google_compute_url_map.app.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app[0].id]
}

resource "google_compute_global_address" "app" {
  count   = var.domain != null ? 1 : 0
  project = var.project_id
  name    = "${var.app_name}-${var.environment}-ip"
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.domain != null ? 1 : 0
  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-fr-https"
  ip_address            = google_compute_global_address.app[0].address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.app[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
