variable "repo" {
  description = "GitHub repository. Owner is automatically prefixed where needed"
  type        = string
}

variable "env_id" {
  description = "Environment's \"short name\""
  type        = string
}

variable "folder_roles" {
  description = "Roles to give the IaC accounts at the folder level"
  default     = []
  type        = list(string)
}

variable "env_folder_id" {
  description = "Environment folder's id. Required when folder_roles is set"
  type        = string
  default     = ""
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

variable "owners" {
  description = "GitHub team ids required to review the job for application updates. This team must have some access to this repo at https://github.com/<owner>/<repo>/settings/access. Obtain id with `gh api https://api.github.com/orgs/<org>/teams/<slug> | jq '.id'`"
  type        = list(number)
}

variable "skip_cd_approval" {
  description = "Whether to require manual approval for the cd repo environment. This is only used for reducing the number of manual approvals needed when the uat and prd deployments are combined, and should only be set to true for prd"
  type        = bool
  default     = false
}

variable "restrict_environment_branches" {
  description = "Whether to restrict deployment using <env>-ci and <env>-cd environments to protected branches"
  type        = bool
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

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace"
  default     = ""
}

variable "group_memberships" {
  description = "List of group memberships to add the IaC service account to"
  type = list(object({
    group_name   = string
    group_role   = string
    is_env_group = bool
  }))
  default = []
}
