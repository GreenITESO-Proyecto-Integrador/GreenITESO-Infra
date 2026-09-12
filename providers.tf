# No GCP account exists yet for this project. This file intentionally has no
# backend block (remote state) and no credentials wiring — both are decisions
# for whoever provisions the real GCP project, not something to assume here.

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
