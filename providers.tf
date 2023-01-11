terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

data "google_storage_bucket_object_content" "env_config" {
  name   = "config.v2.json"
  bucket = "${var.terraform_project_id}-env-config"
}

# Get outputs from the environment terraform process
data "terraform_remote_state" "environment_config" {
  backend = "gcs"
  config = {
    bucket = "${var.terraform_project_id}-state"
    prefix = "environment"
  }
}
