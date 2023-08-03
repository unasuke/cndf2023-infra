# https://cloud.google.com/load-balancing/docs/https/setup-global-ext-https-serverless

provider "google" {
  project = "cndf2023-http3"
}

provider "google-beta" {
  project = "cndf2023-http3"
}

locals {
  project = "cndf2023-http3"
}

# tf/gcp_load_balancing_storage
data "google_compute_ssl_certificate" "wildcard_cndf2023_unasuke_dev" {
  name = "wildcard-cndf2023-unasuke-dev"
}

resource "google_artifact_registry_repository" "cndf2023_cloudrun" {
  location      = "asia-northeast1"
  repository_id = "cndf2023-lb-cloudrun"
  description   = "HTTP/3 enabled web server images for Cloud Run"
  format        = "DOCKER"
}

resource "google_cloud_run_v2_service" "cndf2023_cloudrun_nginx" {
  name     = "cndf2023-load-balancing-cloudrun-nginx"
  location = "asia-northeast1"
  ingress  = "INGRESS_TRAFFIC_ALL"


  template {
    containers {
      name  = "h2o"
      image = "asia-northeast1-docker.pkg.dev/${local.project}/${google_artifact_registry_repository.cndf2023_cloudrun.name}/nginx:latest"
      ports {
        container_port = 80
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_policy" "nginx_public_access" {
  project     = google_cloud_run_v2_service.cndf2023_cloudrun_nginx.project
  location    = google_cloud_run_v2_service.cndf2023_cloudrun_nginx.location
  name        = google_cloud_run_v2_service.cndf2023_cloudrun_nginx.name
  policy_data = data.google_iam_policy.public_access.policy_data
}

resource "google_compute_global_address" "global_ipaddr_nginx_lb" {
  name = "cndf2023-load-balancing-cloudrun-nginx"
}

resource "google_compute_region_network_endpoint_group" "cndf2023_cloudrun_nginx_neg" {
  provider              = google-beta
  name                  = "cndf2023-cloudrun-nginx-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"
  cloud_run {
    service = google_cloud_run_v2_service.cndf2023_cloudrun_nginx.name
  }
}

resource "google_compute_backend_service" "cndf2023_cloudrun_nginx_backend" {
  name = "cndf2023-cloudrun-nginx-backend"

  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.cndf2023_cloudrun_nginx_neg.id
  }
}

resource "google_compute_url_map" "cndf2023_clourdun_nginx" {
  name            = "cndf2023-cloudrun-nginx-urlmap"
  default_service = google_compute_backend_service.cndf2023_cloudrun_nginx_backend.id
}

resource "google_compute_target_https_proxy" "cndf2023_cloudrun_nginx_proxy" {
  name = "cndf2023-cloudrun-nginx-https-proxy"

  url_map = google_compute_url_map.cndf2023_clourdun_nginx.id
  ssl_certificates = [
    data.google_compute_ssl_certificate.wildcard_cndf2023_unasuke_dev.id
  ]
}

resource "google_compute_global_forwarding_rule" "cndf2023_lb_cloudrun_nginx" {
  name = "cndf2023-lb-cloudrun-nginx-lb"

  target     = google_compute_target_https_proxy.cndf2023_cloudrun_nginx_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.global_ipaddr_nginx_lb.address
}

resource "google_cloud_run_v2_service" "cndf2023_cloudrun_h2o" {
  name     = "cndf2023-load-balancing-cloudrun-h2o"
  location = "asia-northeast1"
  ingress  = "INGRESS_TRAFFIC_ALL"


  template {
    containers {
      name  = "h2o"
      image = "asia-northeast1-docker.pkg.dev/${local.project}/${google_artifact_registry_repository.cndf2023_cloudrun.name}/h2o:latest"
      ports {
        container_port = 80
      }
    }
  }
}

data "google_iam_policy" "public_access" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "h2o_public_access" {
  project     = google_cloud_run_v2_service.cndf2023_cloudrun_h2o.project
  location    = google_cloud_run_v2_service.cndf2023_cloudrun_h2o.location
  name        = google_cloud_run_v2_service.cndf2023_cloudrun_h2o.name
  policy_data = data.google_iam_policy.public_access.policy_data
}

resource "google_compute_global_address" "global_ipaddr_h2o_lb" {
  name = "cndf2023-load-balancing-cloudrun-h2o"
}

resource "google_compute_region_network_endpoint_group" "cndf2023_cloudrun_h2o_neg" {
  provider              = google-beta
  name                  = "cndf2023-cloudrun-h2o-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"
  cloud_run {
    service = google_cloud_run_v2_service.cndf2023_cloudrun_h2o.name
  }
}

resource "google_compute_backend_service" "cndf2023_cloudrun_h2o_backend" {
  name = "cndf2023-cloudrun-h2o-backend"

  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.cndf2023_cloudrun_h2o_neg.id
  }
}

resource "google_compute_url_map" "cndf2023_clourdun_h2o" {
  name            = "cndf2023-cloudrun-h2o-urlmap"
  default_service = google_compute_backend_service.cndf2023_cloudrun_h2o_backend.id
}

resource "google_compute_target_https_proxy" "cndf2023_cloudrun_h2o_proxy" {
  name = "cndf2023-cloudrun-h2o-https-proxy"

  url_map = google_compute_url_map.cndf2023_clourdun_h2o.id
  ssl_certificates = [
    data.google_compute_ssl_certificate.wildcard_cndf2023_unasuke_dev.id
  ]
}

resource "google_compute_global_forwarding_rule" "cndf2023_lb_cloudrun_h2o" {
  name = "cndf2023-lb-cloudrun-h2o-lb"

  target     = google_compute_target_https_proxy.cndf2023_cloudrun_h2o_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.global_ipaddr_h2o_lb.address
}
