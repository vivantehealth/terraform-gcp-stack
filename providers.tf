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

# Get outputs from the environment terraform process
data "terraform_remote_state" "environment_config" {
  backend = "gcs"
  config = {
    bucket = "${local.env_config.env_terraform_project_id}-state"
    prefix = "environment"
  }
}
