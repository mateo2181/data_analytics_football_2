terraform {
  required_version = ">= 1.0"
  backend "local" {}  # Can change from "local" to "gcs" (for google) or "s3" (for aws), if you would like to preserve your tf-state online
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.project
  region = var.region
  credentials = file(var.credentials_file)  # Use this if you do not want to set env-var GOOGLE_APPLICATION_CREDENTIALS
}

# resource "google_project" "project" {
#   name            = random_id.project_random.hex
#   project_id      = random_id.project_random.hex
#   org_id          = var.organization_id
#   billing_account = var.billing_id
#   skip_delete     = "true"
# }

# resource "google_project_service" "service" {
#   count   = length(var.project_services)
#   project = var.project
#   service = element(var.project_services, count.index)

#   # Do not disable the service on destroy. On destroy, we are going to
#   # destroy the project, but we need the APIs available to destroy the
#   # underlying resources.
#   disable_on_destroy = false
# }

resource "google_compute_instance" "airflow" {
  project      = var.project
  name         = "airflow-server"
  machine_type = var.machine_type
  zone         = var.region_instance

  tags = ["airflow-server","http-server","https-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-bionic-v20200414"
      size  = "20"
    }
    device_name = "airflow-server"
  }

  network_interface {
    network = "default"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata_startup_script = templatefile("startup.sh", {
    PROJECT = var.project,
    BUCKET = "${local.data_lake_bucket}_${var.project}",
    BG_DATASET = var.BQ_DATASET,
    BG_DATASET_DBT = var.BQ_DATASET_DBT,
    BG_DATASET_PROD = var.BQ_DATASET_PROD
  })

  service_account {
    scopes = ["logging-write","monitoring-write"]
  }
  allow_stopping_for_update = true
}

# resource "google_compute_firewall" "default" {
#   name        = "open-airflow-server-to-world"
#   project     = var.project
#   network     = "default"
#   target_tags = ["airflow-server"]
#   source_ranges = ["0.0.0.0/0"]

#   allow {
#     protocol = "tcp"
#     ports    = ["80"]
#   }
# }

# Data Lake Bucket
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "data-lake-bucket" {
  name          = "${local.data_lake_bucket}_${var.project}" # Concatenating DL bucket & Project name for unique naming
  location      = var.region

  # Optional, but recommended settings:
  storage_class = var.storage_class
  uniform_bucket_level_access = true

  versioning {
    enabled     = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30  // days
    }
  }

  force_destroy = true
}

# DWH
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset
resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.BQ_DATASET
  project    = var.project
  location   = var.region
}

output server-ip {
    value = google_compute_instance.airflow.network_interface.0.access_config.0.nat_ip
}

output project-name {
    value = var.project
}

output bucket {
    value = "${local.data_lake_bucket}_${var.project}"
}

output dataset {
    value = var.BQ_DATASET
}
