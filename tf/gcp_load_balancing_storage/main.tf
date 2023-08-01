# https://cloud.google.com/blog/ja/products/serverless/serverless-load-balancing-terraform-hard-way
# https://cloud.google.com/load-balancing/docs/https/ext-load-balancer-backend-buckets

provider "google" {
  project = "cndf2023-http3"
}

provider "google-beta" {
  project = "cndf2023-http3"
}

locals {
  project = "cndf2023-http3"
}

resource "google_storage_bucket" "static_site" {
  name     = "unasuke-cndf2023-website"
  location = "ASIA-NORTHEAST1"
  website {
    main_page_suffix = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "public_access" {
  bucket = google_storage_bucket.static_site.id
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_global_address" "global_ipaddr" {
  name = "cndf2023-website-address"
}

resource "google_compute_ssl_certificate" "wildcard_cndf2023_unasuke_dev" {
  name        = "wildcard-cndf2023-unasuke-dev"
  description = "a wildcard cert for *.cndf2023.unasuke.dev"
  private_key = file("../../certificate/cndf2023.unasuke.dev.key")
  certificate = file("../../certificate/cndf2023.unasuke.dev.chained.crt")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_backend_bucket" "static_site_backend" {
  name        = "static-site-bucket-backend"
  description = "backend for unasuke-cndf2023-website bucket"
  bucket_name = google_storage_bucket.static_site.name
  # enable_cdn  = true
}

resource "google_compute_url_map" "urlmap" {
  name            = "urlmap"
  default_service = google_compute_backend_bucket.static_site_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "path-matcher"
  }
  path_matcher {
    name            = "path-matcher"
    default_service = google_compute_backend_bucket.static_site_backend.id
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-lb-proxy"
  url_map          = google_compute_url_map.urlmap.id
  ssl_certificates = [google_compute_ssl_certificate.wildcard_cndf2023_unasuke_dev.id]
}

resource "google_compute_global_forwarding_rule" "forward_rule" {
  name                  = "http-lb-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = 443
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.https_proxy.id
  ip_address            = google_compute_global_address.global_ipaddr.id
}
