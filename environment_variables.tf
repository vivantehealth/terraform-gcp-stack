# Store some variables for easier access during github actions workflows
# Store the docker registry (if variable set for this stack)
# Even though this is the same for all environments, we're doing this as an
# environment variable rather than a repo variable/secret so that the terraform
# state is always up to date (i.e not fighting with another workflow for another env)
resource "github_actions_environment_variable" "ci_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_ci_environment.environment
  repository      = var.repo
  secret_name     = "DOCKER_REGISTRY"
  plaintext_value = var.docker_registry
}
resource "github_actions_environment_variable" "cd_docker_registry" {
  count           = length(var.docker_registry) > 0 ? 1 : 0
  environment     = github_repository_environment.repo_cd_environment.environment
  repository      = var.repo
  secret_name     = "DOCKER_REGISTRY"
  plaintext_value = var.docker_registry
}

# Store the stack's domain project id
resource "github_actions_environment_variable" "ci_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "DOMAIN_PROJECT_ID"
  plaintext_value = var.domain_project_id
}
resource "github_actions_environment_variable" "cd_domain_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "DOMAIN_PROJECT_ID"
  plaintext_value = var.domain_project_id
}

# Store the terraform state project id for auto terraform backend configuration and env config access
resource "github_actions_environment_variable" "ci_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "TERRAFORM_PROJECT_ID"
  plaintext_value = var.terraform_project_id
}
resource "github_actions_environment_variable" "cd_terraform_project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "TERRAFORM_PROJECT_ID"
  plaintext_value = var.terraform_project_id
}

# Set parameters needed for workload identity. Provider id set at the org level
resource "github_actions_environment_variable" "ci_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "GCP_SERVICE_ACCOUNT"
  plaintext_value = google_service_account.gha_iac.email
}
resource "github_actions_environment_variable" "cd_gcp_service_account" {
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "GCP_SERVICE_ACCOUNT"
  plaintext_value = google_service_account.gha_iac.email
}

# Set parameters needed for k8s/helm
resource "github_actions_environment_variable" "ci_k8s_namespace" {
  count           = var.k8s_namespace != null ? (length(var.k8s_namespace) > 0 ? 1 : 0) : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_ci_environment.environment
  secret_name     = "K8S_NAMESPACE"
  plaintext_value = var.k8s_namespace
}
resource "github_actions_environment_variable" "cd_k8s_namespace" {
  count           = var.k8s_namespace != null ? (length(var.k8s_namespace) > 0 ? 1 : 0) : 0
  repository      = var.repo
  environment     = github_repository_environment.repo_cd_environment.environment
  secret_name     = "K8S_NAMESPACE"
  plaintext_value = var.k8s_namespace
}

