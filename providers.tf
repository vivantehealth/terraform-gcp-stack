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
