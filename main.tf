# Provisioning a "stack" means provisioning the prerequisites for a stack to
# run it's own tf pipeline. It involves setting up the github repo's
# environments and repo-environment 'secrets' (which aren't really secret) for
# the terraform plan and terraform apply steps. It also creates the repo's
# terraform service accounts, which can be assumed by the repo's github actions
# workflows using workload identity

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
resource "github_actions_environment_secret" "base64_plan_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id)
}
resource "github_actions_environment_secret" "base64_apply_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id)
}
# Store the terraform state project id for auto terraform backend configuration and env config access
resource "github_actions_environment_secret" "base64_plan_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id)
}
resource "github_actions_environment_secret" "base64_apply_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id)
}
# Store the docker registry (if variable set for this stack)
resource "github_actions_environment_secret" "base64_plan_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "BASE64_DOCKER_REGISTRY" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.docker_registry)
}
resource "github_actions_environment_secret" "base64_apply_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "BASE64_DOCKER_REGISTRY" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.docker_registry)
}
# Set parameters needed for workload identity
resource "github_actions_environment_secret" "plan_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_plan_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.terraform_planner.email)
}
resource "github_actions_environment_secret" "apply_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_apply_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.terraform_planner.email)
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

locals {
  workload_identity_pool_id = replace(var.workload_identity_provider, "/\\/providers\\/.*/", "")
}
# Add workload identity permissions to the service accounts
resource "google_service_account_iam_member" "workload_identity_planner" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_plan_environment.environment}"
  service_account_id = google_service_account.terraform_planner.name
}
resource "google_service_account_iam_member" "workload_identity_applier" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_apply_environment.environment}"
  service_account_id = google_service_account.terraformer.name
}

# Give the roles above generous privileges on their domain's project as they'll need to do terraform planning and applying, which covers a broad range of capabilities
resource "google_project_iam_member" "terraformer_owner" {
  project = var.domain_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraformer.email}"
}

resource "google_project_iam_member" "terraform_planner_viewer" {
  project = var.domain_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.terraform_planner.email}"
}

// Allow stack's terraformer to manage all docker repo artifacts and versions
// Terraform planner already has read permissions by its group membership status
resource "google_artifact_registry_repository_iam_member" "member" {
  // Extract project id from docker registry. Assumes the format `<registry>/<project>[/etc]`
  // This will not work if docker_registry var is not set.
  project    = one(regex("^[^/]+/([^/]+).*$", var.docker_registry))
  count      = length(var.docker_registry) > 0 ? 1 : 0
  provider   = google-beta
  location   = "us"
  repository = "projects/${one(regex("^[^/]+/([^/]+).*$", var.docker_registry))}/locations/us/repositories/${var.repo}"
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.terraformer.email}"
}

// Custom provisioners are usually frowned upon, and should only be used as a
// last resort. That was the case when this was implemented. To enable separate
// service accounts for plan and apply, where the planner only had read
// permissions within GCP (so that `terraform plan` doesn't require GHA manual
// approval for that repo environment), we can't use
// google_cloud_identity_group_membership because the planner doesn't have any
// way to read group membership, so it fails. By switching to the local-exec
// provisioner, we're working around terraform's inability to make an effective
// plan when it doesn't have the read permission it needs, while still allowing
// the applier to create the membership.
//
// This script transforms the group_roles tfvar into the json structure needed
// by the API call, then gets the current service account's credentials.
// Finally, it makes the API call, printing the output to stderr if the call
// failed or to stdout if it succeeded
//
// TODO maybe add a destroy condition provisioner
resource "null_resource" "terraformer_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": $members, \"preferredMemberKey\": { \"id\": \"${google_service_account.terraformer.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.terraformers_google_group_id}/memberships)
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
      set -eo pipefail
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": [{\"name\": \"MEMBER\"}], \"preferredMemberKey\": { \"id\": \"${google_service_account.terraform_planner.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.terraform_planners_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

# Add the terraformer to the terraform-planners group so that it can manage
# group membership when var.group_roles includes MANAGER
resource "null_resource" "terraformer_planner_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": $members, \"preferredMemberKey\": { \"id\": \"${google_service_account.terraformer.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.terraform_planners_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

// Allow terraformer to manage membership of the registry readers security group
// Terraform planners should already be members of this group
resource "google_cloud_identity_group_membership" "terraformer_registry_readers_group_membership" {
  count = length(var.registry_readers_google_group_id) > 0 ? 1 : 0
  group = var.registry_readers_google_group_id
  preferred_member_key {
    id = google_service_account.terraformer.email
  }
  roles {
    name = "MEMBER"
  }
  roles {
    name = "MANAGER"
  }
}
