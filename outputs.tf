output "repo" {
  value = var.repo
}

output "repo_plan_sa_email" {
  value = google_service_account.terraform_planner.email
}

output "repo_plan_sa_id" {
  value = google_service_account.terraform_planner.id
}

output "repo_plan_environment" {
  value = github_repository_environment.repo_plan_environment.environment
}

output "repo_apply_sa_email" {
  value = google_service_account.terraformer.email
}

output "repo_apply_sa_id" {
  value = google_service_account.terraformer.id
}

output "repo_apply_environment" {
  value = github_repository_environment.repo_apply_environment.environment
}
