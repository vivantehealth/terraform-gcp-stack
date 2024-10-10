# Provisioning a "stack" means provisioning the prerequisites for a stack to
# run it's own tf pipeline. It involves setting up the github repo's
# environments and repo-environment 'secrets' (which aren't really secret) for
# the terraform plan and terraform apply steps. It also creates the repo's
# terraform service accounts, which can be assumed by the repo's github actions
# workflows using workload identity

# Create repo environments for the secrets and workload identity linking
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
  dynamic "reviewers" {
    for_each = var.skip_cd_approval == true ? [] : [1]
    content {
      teams = var.owners
      users = []
    }
  }
  deployment_branch_policy {
    protected_branches     = var.restrict_environment_branches
    custom_branch_policies = !var.restrict_environment_branches
  }
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

// Give the iac accounts permission overrides at the folder level (if specified)
// Used for things like the log-archive stack to set folder audit configs
resource "google_folder_iam_member" "iac_folder_permissions" {
  folder   = var.env_folder_id
  for_each = toset(var.folder_roles)
  role     = each.value
  member   = "serviceAccount:${google_service_account.gha_iac.email}"
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
// This allows it to add registry permissions to runtime service accounts, allowing things like cloud run to pull from the registry
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
// FIXME This resource causes all kinds of problems, find a way to decouple these permissions so that stacks can be deleted or renamed without huge issues
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

// Look up the group id for each var.group_memberships
data "google_cloud_identity_group_lookup" "group_lookup" {
  for_each = toset(var.group_memberships)
  group_key {
    id = each.value
  }
}

// Add the iac SA to any custom groups specified
resource "google_cloud_identity_group_membership" "custom_group_membership" {
  for_each = data.google_cloud_identity_group_lookup.group_lookup
  group    = each.value.name
  preferred_member_key {
    id = google_service_account.gha_iac.email
  }
  // For the initial use case, only MEMBER is needed, but in the future, if the IaC SA needs to add a runtime SA to a group, MANAGER would be needed. This could be either hard-coded or configurable (would require updates to the structure of the group_memberships variable and associated stack yaml schema in gcp-env-terraform)
  roles {
    name = "MEMBER"
  }
}
