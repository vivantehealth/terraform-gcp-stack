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
  description = "Build-artifacts docker registry. If not set, corresponding repo environment secret will not be set"
  type        = string
  default     = ""
}

variable "registry_readers_google_group_id" {
  description = "Google group id to place artifact registry readers in. Group membership will not be added if this variable is not set"
  type        = string
  default     = ""
}

variable "infra_reviewers" {
  description = "GitHub teams required to review the job for infrastructure changes. This team must have some access to this repo at https://github.com/<owner>/<repo>/settings/access"
  type        = string
}

variable "cd_reviewers" {
  description = "GitHub teams required to review the job for application updates. This team must have some access to this repo at https://github.com/<owner>/<repo>/settings/access. If not set, will be the same as infra_reviewers"
  type        = string
  default     = ""
}

variable "iac_readers_google_group_id" {
  description = "Google group ID to place the CI service account in"
  type        = string
}

variable "iac_limited_google_group_id" {
  description = "Google group ID to place the limited CD service account in"
  type        = string
}

variable "iac_admins_google_group_id" {
  description = "Google group ID to place the infrastructure-provisioning service account in"
  type        = string
}

variable "group_roles" {
  description = "Roles to assign the service account for the iac-admins and iac-limited Google group. This is normally just 'MEMBER', but in the case of gcp-org-terraform, both 'MEMBER' and 'MANAGER' are needed"
  type        = list(string)
  default     = ["MEMBER"]
}

variable "workload_identity_provider" {
  description = "GCP Workload Identity provider id (for setting repo environment secrets) for gcloud setup step"
  type        = string
}

variable "require_protected_branches" {
  description = "Whether to restrict the apply environment to deploying from protected branches. Not recommended when GitHub releases used for deployments"
  type        = bool
  default     = false
}
