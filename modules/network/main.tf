# Optional edge layer, created only when a domain is set (the root module
# instantiates it with count). External HTTPS load balancer with Cloud Armor,
# Cloud CDN on the frontend, and path routing: /api/* goes to the backend
# service, everything else to the frontend service.
#
# Not yet exercised against a real project: validate with `terraform plan`
# and a real domain before relying on it.

locals {
  services = {
    frontend = var.frontend_service_name
    backend  = var.backend_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "neg" {
  for_each = local.services

  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-${each.key}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = each.value
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

resource "google_compute_backend_service" "svc" {
  for_each = local.services

  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-${each.key}-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.armor.id

  backend {
    group = google_compute_region_network_endpoint_group.neg[each.key].id
  }

  # CDN only for the frontend's static assets; API responses are never cached.
  enable_cdn = each.key == "frontend"

  dynamic "cdn_policy" {
    for_each = each.key == "frontend" ? [1] : []
    content {
      cache_mode                   = "CACHE_ALL_STATIC"
      client_ttl                   = 3600
      default_ttl                  = 3600
      max_ttl                      = 86400
      signed_url_cache_max_age_sec = 0
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "app" {
  project         = var.project_id
  name            = "${var.app_name}-${var.environment}-urlmap"
  default_service = google_compute_backend_service.svc["frontend"].id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "app"
  }

  path_matcher {
    name            = "app"
    default_service = google_compute_backend_service.svc["frontend"].id

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.svc["backend"].id
    }
  }
}

resource "google_compute_managed_ssl_certificate" "app" {
  project = var.project_id
  name    = "${var.app_name}-${var.environment}-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "app" {
  project          = var.project_id
  name             = "${var.app_name}-${var.environment}-https-proxy"
  url_map          = google_compute_url_map.app.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app.id]
}

resource "google_compute_global_address" "app" {
  project = var.project_id
  name    = "${var.app_name}-${var.environment}-ip"
}

resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project_id
  name                  = "${var.app_name}-${var.environment}-fr-https"
  ip_address            = google_compute_global_address.app.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.app.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
