output "repo" {
  value = var.repo
}

output "repo_ci_sa_email" {
  value = google_service_account.gha_ci.email
}

output "repo_ci_sa_id" {
  value = google_service_account.gha_ci.id
}

output "repo_ci_environment" {
  value = github_repository_environment.repo_ci_environment.environment
}

output "repo_cd_sa_email" {
  value = google_service_account.gha_cd.email
}

output "repo_cd_sa_id" {
  value = google_service_account.gha_cd.id
}

output "repo_cd_environment" {
  value = github_repository_environment.repo_cd_environment.environment
}

output "repo_infra_sa_email" {
  value = google_service_account.gha_infra.email
}

output "repo_infra_sa_id" {
  value = google_service_account.gha_infra.id
}

output "repo_infra_environment" {
  value = github_repository_environment.repo_infra_environment.environment
}
