variable "credentials_file" { }

locals {
  data_lake_bucket = "airflow_football"
}

variable "project" {
  description = "Your GCP Project ID"
}

variable project_services {
    default = ["compute.googleapis.com"]
}

variable machine_type {
    default = "e2-standard-4"
}

variable "region_instance" {
  description = "Region for GCP resources. Choose as per your location: https://cloud.google.com/about/locations"
  default = "europe-west6-a"
  type = string
}

variable "region" {
  description = "Region for GCP resources: Google Cloud Storage and Big Query Dataset"
  default = "europe-west6"
  type = string
}

variable "storage_class" {
  description = "Storage class type for your bucket. Check official docs for more info."
  default = "STANDARD"
}

variable "BQ_DATASET" {
  description = "BigQuery Dataset that raw data (from GCS) will be written to"
  type = string
}

variable "BQ_DATASET_DBT" {
  description = "BigQuery Dataset used when run dbt build in dev."
  type = string
}

variable "BQ_DATASET_PROD" {
  description = "BigQuery Dataset used when run dbt build with target prod."
  type = string
}