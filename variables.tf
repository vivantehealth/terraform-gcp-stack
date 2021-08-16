variable "repo" {
  description = "GitHub repository. Owner is automatically prefixed where needed"
  type        = string
}

variable "env_id" {
  description = "Environment's \"short name\""
  type        = string
}

variable "domain_project_id" {
  description = "Domain's GCP Project ID"
  type        = string
}

variable "folder_terraformer_gcp_key" {
  description = "Service account key for the folder terraformer. This will be stored as repo environment secrets for each stack so they can do their own infrastructure terraforming"
  type        = string
  sensitive   = true
}
