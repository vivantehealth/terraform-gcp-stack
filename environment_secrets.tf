# Store some secrets for easier access during github actions workflows
# Base64 encoded so the decoded values aren't masked in the logs
# Store the docker registry (if variable set for this stack)
# Even though this is the same for all environments, we're doing this as an
# environment secret rather than a repo secret so that the terraform state is
# always up to date (i.e not fighting with another workflow for another env)
resource "github_actions_environment_secret" "ci_base64_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_ci_environment.environment
  repository      = var.repo
  secret_name     = "BASE64_DOCKER_REGISTRY"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.docker_registry) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}
resource "github_actions_environment_secret" "cd_base64_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_cd_environment.environment
  repository      = var.repo
  secret_name     = "BASE64_DOCKER_REGISTRY"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.docker_registry) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}

resource "github_actions_environment_variable" "ci_docker_registry" {
  count         = length(var.docker_registry) > 0 ? 1 : 0
  environment   = github_repository_environment.repo_ci_environment.environment
  repository    = var.repo
  variable_name = "DOCKER_REGISTRY"
  value         = var.docker_registry
}
resource "github_actions_environment_variable" "cd_docker_registry" {
  count         = length(var.docker_registry) > 0 ? 1 : 0
  environment   = github_repository_environment.repo_cd_environment.environment
  repository    = var.repo
  variable_name = "DOCKER_REGISTRY"
  value         = var.docker_registry
}

# Store the stack's domain project id
resource "github_actions_environment_secret" "ci_base64_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}
resource "github_actions_environment_secret" "cd_base64_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_DOMAIN_PROJECT_ID"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.domain_project_id) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}

# Store the terraform state project id for auto terraform backend configuration and env config access
resource "github_actions_environment_secret" "ci_base64_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}
resource "github_actions_environment_secret" "cd_base64_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_TERRAFORM_PROJECT_ID"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.terraform_project_id) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}

# Set parameters needed for workload identity. Provider id set at the org level
resource "github_actions_environment_secret" "ci_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT"                       #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_iac.email) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}
resource "github_actions_environment_secret" "cd_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_GCP_SERVICE_ACCOUNT"                       #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(google_service_account.gha_iac.email) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}

# Set parameters needed for k8s/helm
resource "github_actions_environment_secret" "ci_k8s_namespace" {
  count           = var.k8s_namespace == null || length(var.k8s_namespace) > 0 ? 1 : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "BASE64_K8S_NAMESPACE"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.k8s_namespace) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}
resource "github_actions_environment_secret" "cd_k8s_namespace" {
  count           = var.k8s_namespace == null || length(var.k8s_namespace) > 0 ? 1 : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "BASE64_K8S_NAMESPACE"          #tfsec:ignore:general-secrets-no-plaintext-exposure this isn't sensitive
  plaintext_value = base64encode(var.k8s_namespace) #tfsec:ignore:no-plaintext-exposure this isn't sensitive
}

