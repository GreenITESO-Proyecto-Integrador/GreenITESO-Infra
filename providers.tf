# Remote state lives in a GCS bucket created by hand (Terraform can't hold its
# own state before the bucket exists). Pick the environment at init time:
#   terraform init -backend-config="prefix=production"
terraform {
  backend "gcs" {
    bucket = "greeniteso-510118-tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
