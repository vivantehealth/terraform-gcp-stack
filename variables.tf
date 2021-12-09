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
  description = "Build artifacts docker registry"
  type        = string
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
  description = "Google group id for artifact registry readers"
  type        = string
}

variable "group_roles" {
  description = "Roles to assign the service account for the terraformers Google group"
  type        = list(string)
  default     = ["MEMBER"]
}

variable "workload_identity_pool_id" {
  description = "GCP Workload Identity Pool ID for assuming roles to act as terraformer service accounts"
  type        = string
  default     = "principalSet://iam.googleapis.com/projects/504619716518/locations/global/workloadIdentityPools/vh-pool"
}
