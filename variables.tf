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

variable "terraform_apply_reviewers" {
  description = "GitHub teams required to review the workflow for terraform apply. These teams must have access to this repo at https://github.com/<owner>/<repo>/settings/access"
  type        = list(string)
}

variable "terraform_planners_group_id" {
  description = "Google group ID for the terraform planner service account"
  type        = string
}

variable "terraformers_group_id" {
  description = "Google group ID for the terraformer service account"
  type        = string
}

variable "group_roles" {
  description = "Roles to assign the service account for the Google group"
  type        = list(string)
  default     = ["MEMBER"]
}
