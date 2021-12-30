output "repo" {
  value = var.repo
}

output "repo_cd_sa_email" {
  value = google_service_account.gha_iac.email
}

output "repo_cd_sa_id" {
  value = google_service_account.gha_iac.id
}

output "repo_cd_environment" {
  value = github_repository_environment.repo_cd_environment.environment
}
