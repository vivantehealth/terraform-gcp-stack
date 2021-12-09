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

variable "terraform_project_id" {
  description = "Folder Terraform GCP Project ID"
  type        = string
}

variable "docker_registry" {
  description = "Build-artifacts docker registry. If not set, repo environment secret will not be set"
  type        = string
  default     = ""
}

variable "terraform_apply_reviewers" {
  description = "GitHub teams required to review the workflow for terraform apply. These teams must have access to this repo at https://github.com/<owner>/<repo>/settings/access"
  type        = list(string)
}

variable "terraform_planners_google_group_id" {
  description = "Google group ID for the terraform planner service account"
  type        = string
}

variable "terraformers_google_group_id" {
  description = "Google group ID for the terraformer service account"
  type        = string
}

variable "registry_readers_google_group_id" {
  description = "Google group id for artifact registry readers. Group membership will not be added if this variable is not set"
  type        = string
  default     = ""
}

variable "group_roles" {
  description = "Roles to assign the service account for the terraformers Google group"
  type        = list(string)
  default     = ["MEMBER"]
}

variable "workload_identity_provider" {
  description = "GCP Workload Identity provider id for setting repo environment secrets for gcloud setup step"
  type        = string
}
