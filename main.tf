# TODO provision a secrets manager that publishes a rotation message to the
# folder's rotater cloud function on a schedule

# Create a repo environment for the service account key secret
# TODO: important, if prod, set repo environment to have protections so a team has to review
resource "github_repository_environment" "repo_environment" {
  repository  = var.repo
  environment = var.env_id
}
# Place the service account key in the repo's environment secrets for use in GitHub Actions
# Note: this key is stored in plain text in the state file, so treat that as sensitive
resource "github_actions_environment_secret" "folder_terraformer_key" {
  repository      = var.repo
  environment     = github_repository_environment.repo_environment.environment
  secret_name     = "TERRAFORMER_GCP_KEY" #tfsec:ignore:GEN003 TODO might be a valid security concern, look into this
  plaintext_value = var.folder_terraformer_gcp_key
}
# Store the domain's project id for easier access during github actions workflows
resource "github_actions_environment_secret" "project_id" {
  repository      = var.repo
  environment     = github_repository_environment.repo_environment.environment
  secret_name     = "PROJECT_ID" #tfsec:ignore:GEN003 this isn't sensitive
  plaintext_value = var.domain_project_id
}
