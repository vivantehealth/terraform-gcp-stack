# Provisioning a "stack" means provisioning the prerequisites for a stack to
# run it's own tf pipeline. It involves setting up the github repo's
# environments and repo-environment 'secrets' (which aren't really secret) for
# the terraform plan and terraform apply steps. It also creates the repo's
# terraform service accounts. It usually goes along with the
# instantiation of the key-rotation module, which rotates the service account
# keys

# Create repo environments for the service account key secrets
resource "github_repository_environment" "repo_plan_environment" {
  repository  = var.repo
  environment = "${var.env_id}-plan"
}
resource "github_repository_environment" "repo_apply_environment" {
  repository  = var.repo
  environment = "${var.env_id}-apply"
  reviewers {
    teams = var.terraform_apply_reviewers
    users = []
  }
}

# Store the domain's project id for easier access during github actions workflows
resource "github_actions_environment_secret" "plan_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = var.domain_project_id
}
resource "github_actions_environment_secret" "apply_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = var.domain_project_id
}
# Store the terraform state project id for auto terraform backend configuration
resource "github_actions_environment_secret" "plan_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = var.terraform_project_id
}
resource "github_actions_environment_secret" "apply_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = var.terraform_project_id
}

# SA id's are limited to 30 chars, so we probably can't include the repo name
resource "random_id" "suffix" {
  byte_length = 2
}

# Create stack's terraforming service account
resource "google_service_account" "terraformer" {
  account_id   = "sa-tf-admin-${random_id.suffix.hex}"
  description  = "Terraform SA for ${var.repo}"
  display_name = "${var.repo} Terraformer"
  project      = var.domain_project_id
}

resource "google_service_account" "terraform_planner" {
  account_id   = "sa-tf-read-${random_id.suffix.hex}"
  description  = "Terraform read-only SA for ${var.repo}"
  display_name = "${var.repo} Terraform Planner"
  project      = var.domain_project_id
}

resource "null_resource" "terraformer_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -exo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H 'Authorization: Bearer $bearer' -X POST -d '{"roles": $members, "preferredMemberKey": { "id": "${google_service_account.terraformer.email}" } }' https://cloudidentity.googleapis.com/v1beta1/${var.terraformers_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

resource "null_resource" "terraform_planner_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -exo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      curl --fail -H 'Authorization: Bearer $(gcloud auth application-default print-access-token)' -X POST -d '{"roles": $members, "preferredMemberKey": { "id": "${google_service_account.terraform_planner.email}" } }' https://cloudidentity.googleapis.com/v1beta1/${var.terraform_planners_google_group_id}/memberships
    EOT
  }
}

