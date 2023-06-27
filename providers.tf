terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

