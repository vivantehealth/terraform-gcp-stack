mock_provider "google" {}
mock_provider "github" {}
mock_provider "random" {}

# test {
#   parallel = true
# }

variables {
  repo                          = "test-repo"
  domain_project_id             = "test-domain-project"
  terraform_project_id          = "test-terraform-project"
  iac_admins_google_group_id    = "group@domain.com"
  workload_identity_provider    = "projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider"
  owners                        = [1234]
  restrict_environment_branches = false
  additional_registries         = ["python"]
  docker_registry               = "us-docker.pkg.dev/project-id/repo-name"
}

run "dev_environment_creates_registry" {
  command = plan

  variables {
    env_id = "dev"
  }

  assert {
    condition     = length(resource.google_artifact_registry_repository.additional_registry) == 1
    error_message = "The additional_registry should be created in the dev environment."
  }

  assert {
    condition     = length(resource.google_artifact_registry_repository_iam_member.additional_registry_iac_admin) == 1
    error_message = "The additional_registry_iac_admin should be created in the dev environment."
  }
}

run "prd_environment_does_not_create_registry" {
  command = plan

  variables {
    env_id = "prd"
  }

  assert {
    condition     = length(resource.google_artifact_registry_repository.additional_registry) == 0
    error_message = "The additional_registry should NOT be created in the prd environment."
  }

  assert {
    condition     = length(resource.google_artifact_registry_repository_iam_member.additional_registry_iac_admin) == 1
    error_message = "The additional_registry_iac_admin should be created in the prd environment."
  }
}
