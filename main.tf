# Provisioning a "stack" means provisioning the prerequisites for a stack to
# run it's own tf pipeline. It involves setting up the github repo's
# environments and repo-environment 'secrets' (which aren't really secret) for
# the terraform plan and terraform apply steps. It also creates the repo's
# terraform service accounts, which can be assumed by the repo's github actions
# workflows using workload identity

data "github_team" "owner" {
  slug = var.owner
}
# Create repo environments for the service-account-email secrets
resource "github_repository_environment" "repo_ci_environment" {
  repository  = var.repo
  environment = "${var.env_id}-ci"
  # There appears to be no way to set the branch pattern through the API. See https://github.com/integrations/terraform-provider-github/issues/922#issuecomment-998957627
  deployment_branch_policy {
    protected_branches     = var.restrict_environment_branches
    custom_branch_policies = !var.restrict_environment_branches
  }
}
resource "github_repository_environment" "repo_cd_environment" {
  repository  = var.repo
  environment = "${var.env_id}-cd"
  reviewers {
    teams = var.skip_cd_approval == "true" ? [] : [data.github_team.owner.id]
    users = []
  }
  deployment_branch_policy {
    protected_branches     = var.restrict_environment_branches
    custom_branch_policies = !var.restrict_environment_branches
  }
}

# Store some secrets for easier access during github actions workflows
# Base64 encoded so the decoded values aren't masked in the logs
# Store the docker registry (if variable set for this stack)
# Even though this is the same for all environments, we're doing this as an
# environment secret rather than a repo secret so that the terraform state is
# always up to date
resource "github_actions_environment_secret" "ci_base64_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_ci_environment.environment
  repository      = var.repo
  secret_name     = "BASE64_DOCKER_REGISTRY" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.docker_registry)
}
resource "github_actions_environment_secret" "cd_base64_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_cd_environment.environment
  repository      = var.repo
  secret_name     = "BASE64_DOCKER_REGISTRY" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.docker_registry)
}

# Store the stack's domain project id
resource "github_actions_environment_secret" "ci_base64_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id)
}
resource "github_actions_environment_secret" "cd_base64_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id)
}

# Store the terraform state project id for auto terraform backend configuration and env config access
resource "github_actions_environment_secret" "ci_base64_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id)
}
resource "github_actions_environment_secret" "cd_base64_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id)
}

# Set parameters needed for workload identity. Provider id set at the org level
resource "github_actions_environment_secret" "ci_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_iac.email)
}
resource "github_actions_environment_secret" "cd_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_iac.email)
}

# SA id's are limited to 30 chars, so we probably can't include the repo name
resource "random_id" "suffix" {
  byte_length = 2
}

# Create stack's infrastructure-provisioning service account
resource "google_service_account" "gha_iac" {
  account_id   = "sa-gha-iac-${random_id.suffix.hex}"
  description  = "IaC SA for ${var.repo}"
  display_name = "${var.repo} IaC"
  project      = var.domain_project_id
}

locals {
  # Extract pool id from provider id
  workload_identity_pool_id = replace(var.workload_identity_provider, "/\\/providers\\/.*/", "")
}
# Add workload identity permissions to the service accounts
# This ensures that only the specified repo and environment can act as the
# service account
resource "google_service_account_iam_member" "workload_identity_iac_ci" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_ci_environment.environment}"
  service_account_id = google_service_account.gha_iac.name
}
resource "google_service_account_iam_member" "workload_identity_iac_cd" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_id}/attribute.repo_env/repo:vivantehealth/${var.repo}:environment:${github_repository_environment.repo_cd_environment.environment}"
  service_account_id = google_service_account.gha_iac.name
}

# Give the iac role above generous base privileges on its domain's project as
# it'll need to do terraform planning and applying, which covers a broad
# range of capabilities
resource "google_project_iam_member" "iac_owner" {
  project = var.domain_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.gha_iac.email}"
}

// Allow gha-iac SA to view or manage membership of the iac admins security group, depending on the value of var.group_roles
// Usually only the folder terraformer needs to be a manager.
resource "google_cloud_identity_group_membership" "iac_admins_membership" {
  group = var.iac_admins_google_group_id
  preferred_member_key {
    id = google_service_account.gha_iac.email
  }
  dynamic "roles" {
    for_each = var.group_roles
    content {
      name = roles.value
    }
  }
}

// Allow gha-iac SA to manage membership of the registry readers security group
resource "google_cloud_identity_group_membership" "iac_registry_readers_group_membership" {
  // This will not be created if registry_readers_google_group_id var is not set.
  count = length(var.registry_readers_google_group_id) > 0 ? 1 : 0
  group = var.registry_readers_google_group_id
  preferred_member_key {
    id = google_service_account.gha_iac.email
  }
  roles {
    name = "MEMBER"
  }
  roles {
    name = "MANAGER"
  }
}

// Allow stack's iac SA to manage all docker repo artifacts and versions in
// the tools environment's docker registry
resource "google_artifact_registry_repository_iam_member" "iac_admin" {
  // This will not be created if docker_registry var is not set.
  count = length(var.docker_registry) > 0 ? 1 : 0

  // Extract project id from docker registry. Assumes the format `<registry>/<project>[/etc]`
  project    = one(regex("^[^/]+/([^/]+).*$", var.docker_registry)) #can't be a "local" as written
  provider   = google-beta
  location   = "us"
  repository = "projects/${one(regex("^[^/]+/([^/]+).*$", var.docker_registry))}/locations/us/repositories/${var.repo}"
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.gha_iac.email}"
}
