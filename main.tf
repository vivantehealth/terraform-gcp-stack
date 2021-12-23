# Provisioning a "stack" means provisioning the prerequisites for a stack to
# run it's own tf pipeline. It involves setting up the github repo's
# environments and repo-environment 'secrets' (which aren't really secret) for
# the terraform plan and terraform apply steps. It also creates the repo's
# terraform service accounts, which can be assumed by the repo's github actions
# workflows using workload identity

# Create repo environments for the service-account-email secrets
resource "github_repository_environment" "repo_ci_environment" {
  repository  = var.repo
  environment = "${var.env_id}-ci"
}
resource "github_repository_environment" "repo_infra_environment" {
  repository  = var.repo
  environment = "${var.env_id}-infra"
  reviewers {
    teams = [var.infra_reviewers]
    users = []
  }
  deployment_branch_policy {
    protected_branches = var.require_protected_branches
    #https://github.com/integrations/terraform-provider-github/issues/922#issuecomment-998957627
    custom_branch_policies = false
  }
}
resource "github_repository_environment" "repo_cd_environment" {
  repository  = var.repo
  environment = "${var.env_id}-cd"
  reviewers {
    teams = [(var.cd_reviewers != "" ? var.cd_reviewers : var.infra_reviewers)]
    users = []
  }
}

# Store some repo secrets for easier access during github actions workflows
# Base64 encoded so the decoded values aren't masked in the logs
resource "github_actions_secret" "base64_domain_project_id" {
  repository      = var.repo
  secret_name     = "BASE64_DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id)
}
# Store the terraform state project id for auto terraform backend configuration and env config access
resource "github_actions_secret" "base64_terraform_project_id" {
  repository      = var.repo
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id)
}
# Store the docker registry (if variable set for this stack)
resource "github_actions_secret" "base64_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  repository      = var.repo
  secret_name     = "BASE64_DOCKER_REGISTRY" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.docker_registry)
}

# Set parameters needed for workload identity. Provider id set at the org level
resource "github_actions_environment_secret" "ci_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_ci.email)
}
resource "github_actions_environment_secret" "cd_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_cd.email)
}
resource "github_actions_environment_secret" "infra_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_infra_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_infra.email)
}

# SA id's are limited to 30 chars, so we probably can't include the repo name
resource "random_id" "suffix" {
  byte_length = 2
}

# Create stack's infrastructure-provisioning service account
resource "google_service_account" "gha_infra" {
  account_id   = "sa-gha-infra-${random_id.suffix.hex}"
  description  = "Infrastructure SA for ${var.repo}"
  display_name = "${var.repo} Infra"
  project      = var.domain_project_id
}

# Create stack's application-updating service account
resource "google_service_account" "gha_cd" {
  account_id   = "sa-gha-cd-${random_id.suffix.hex}"
  description  = "CD SA for ${var.repo}"
  display_name = "${var.repo} CD"
  project      = var.domain_project_id
}

# Create stack's release planning service account
resource "google_service_account" "gha_ci" {
  account_id   = "sa-gha-ci-${random_id.suffix.hex}"
  description  = "CI SA for ${var.repo}"
  display_name = "${var.repo} CI"
  project      = var.domain_project_id
}

locals {
  # Extract pool id from provider id
  workload_identity_pool_id = replace(var.workload_identity_provider, "/\\/providers\\/.*/", "")
}
# Add workload identity permissions to the service accounts
# This ensures that only the specified repo and environment can act as the service account
resource "google_service_account_iam_member" "workload_identity_ci" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_ci_environment.environment}"
  service_account_id = google_service_account.gha_ci.name
}
resource "google_service_account_iam_member" "workload_identity_cd" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_cd_environment.environment}"
  service_account_id = google_service_account.gha_cd.name
}
resource "google_service_account_iam_member" "workload_identity_infra" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_infra_environment.environment}"
  service_account_id = google_service_account.gha_infra.name
}

# Give the roles above generous base privileges on their domain's project as
# they'll need to do terraform planning and applying, which covers a broad
# range of capabilities
resource "google_project_iam_member" "infra_owner" {
  project = var.domain_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.gha_infra.email}"
}
resource "google_project_iam_member" "cd_viewer" {
  project = var.domain_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.gha_cd.email}"
}
resource "google_project_iam_member" "ci_viewer" {
  project = var.domain_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.gha_ci.email}"
}

// Allow stack's cd SA to update k8s resources
resource "google_project_iam_member" "cd_k8s_dev" {
  project = var.domain_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.gha_cd.email}"
}
// Allow stack's cd SA to update cloud function code
resource "google_project_iam_member" "cd_cf_dev" {
  project = var.domain_project_id
  role    = "roles/cloudfunctions.developer"
  member  = "serviceAccount:${google_service_account.gha_cd.email}"
}

// Custom provisioners are usually frowned upon, and should only be used as a
// last resort. That was the case when this was implemented. To enable separate
// service accounts for tf plan and apply, where gha-ci only had read
// permissions within GCP (so that `terraform plan` doesn't require GHA manual
// approval for that repo environment), we can't use
// google_cloud_identity_group_membership because gha-ci doesn't have any
// way to read group membership, so it fails. By switching to the local-exec
// provisioner, we're working around terraform's inability to make an effective
// plan when it doesn't have the read permission it needs, while still allowing
// the applier to create the membership.
//
// This script uses jq to transform the group_roles tfvar into the json
// structure needed by the API call, then gets the current service account's
// credentials.
// Finally, it makes the API call, printing the output to stderr if the call
// failed or to stdout if it succeeded
//
// TODO maybe add a destroy condition provisioner
// Add gha-infra as iac-admins member or manager/member
resource "null_resource" "infra_iac_admins_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": $members, \"preferredMemberKey\": { \"id\": \"${google_service_account.gha_infra.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.iac_admins_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

// Add gha-ci as iac-readers member
resource "null_resource" "ci_iac_readers_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eo pipefail
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": [{\"name\": \"MEMBER\"}], \"preferredMemberKey\": { \"id\": \"${google_service_account.gha_ci.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.iac_readers_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

# Add the gha-infra SA to the iac-readers group so that it can manage
# group membership when var.group_roles includes MANAGER
resource "null_resource" "infra_iac_readers_membership" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eo pipefail
      members=$(echo '${jsonencode(var.group_roles)}' | jq -c '[.[] | {name: .}]')
      bearer=$(gcloud auth print-access-token)
      output_file=$(mktemp)
      HTTP_CODE=$(curl --silent --output $output_file --write-out "%%{http_code}" -H "Authorization: Bearer $bearer" -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"roles\": $members, \"preferredMemberKey\": { \"id\": \"${google_service_account.gha_infra.email}\" } }" https://cloudidentity.googleapis.com/v1beta1/${var.iac_readers_google_group_id}/memberships)
      if [[ $HTTP_CODE -lt 200 || $HTTP_CODE -gt 299 ]] ; then
        >&2 cat $output_file
        exit 22
      fi
      cat $output_file
    EOT
  }
}

// Allow gha-infra SA to manage membership of the registry readers security group
// CI/CD SAs should already be members of this group
resource "google_cloud_identity_group_membership" "infra_registry_readers_group_membership" {
  // This will not be created if registry_readers_google_group_id var is not set.
  count = length(var.registry_readers_google_group_id) > 0 ? 1 : 0
  group = var.registry_readers_google_group_id
  preferred_member_key {
    id = google_service_account.gha_infra.email
  }
  roles {
    name = "MEMBER"
  }
  roles {
    name = "MANAGER"
  }
}

// Allow stack's infra SA to manage all docker repo artifacts and versions in
// the tools environment's docker registry
// CI/CD SAs already has read permissions by its group membership status
resource "google_artifact_registry_repository_iam_member" "member" {
  // This will not be created if docker_registry var is not set.
  count = length(var.docker_registry) > 0 ? 1 : 0

  // Extract project id from docker registry. Assumes the format `<registry>/<project>[/etc]`
  project    = one(regex("^[^/]+/([^/]+).*$", var.docker_registry))
  provider   = google-beta
  location   = "us"
  repository = "projects/${one(regex("^[^/]+/([^/]+).*$", var.docker_registry))}/locations/us/repositories/${var.repo}"
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.gha_infra.email}"
}

