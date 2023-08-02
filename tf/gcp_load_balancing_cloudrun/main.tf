provider "google" {
  project = "cndf2023-http3"
}

provider "google-beta" {
  project = "cndf2023-http3"
}

locals {
  project = "cndf2023-http3"
}

resource "google_artifact_registry_repository" "cndf2023_cloudrun_nginx" {
  location      = "asia-northeast1"
  repository_id = "cndf2023-lb-cloudrun-nginx"
  description   = "HTTP/3 enabled nginx image for Cloud Run"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "cndf2023_cloudrun_h2o" {
  location      = "asia-northeast1"
  repository_id = "cndf2023-lb-cloudrun-h2o"
  description   = "HTTP/3 enabled h2o image for Cloud Run"
  format        = "DOCKER"
}

