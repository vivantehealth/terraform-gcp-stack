// Only create python package registry if a registry is specified

// Provision the stack's artifact registry repo, but only once (i.e. in dev and tools-dev), and if a docker registry is set (i.e. not for stacks created by gcp-org-terraform)
resource "google_artifact_registry_repository" "additional_registry" {
  count = length(var.additional_registries) > 0 && (var.env_id == "dev" || var.env_id == "tools-dev") ? 1 : 0
  //project      = replace(var.docker_registry, "us-docker.pkg.dev/", "")
  // Extract project id from docker registry. Assumes the format `<registry>/<project>[/etc]`
  project       = one(regex("^[^/]+/([^/]+).*$", var.docker_registry)) #can't be a "local" as written
  location      = "us"
  repository_id = "${var.repo}-python-packages"
  format        = "PYTHON"
  description   = "Python package registry repo for ${var.repo}'s packages"
}

// Allow stack's iac SA to manage all python package repo artifacts and versions in
// the tools environment's python package registry
resource "google_artifact_registry_repository_iam_member" "additional_registry_iac_admin" {
  count = length(var.additional_registries) > 0 ? 1 : 0

  project    = one(regex("^[^/]+/([^/]+).*$", var.docker_registry))
  location   = "us"
  repository = "projects/${one(regex("^[^/]+/([^/]+).*$", var.docker_registry))}/locations/us/repositories/${var.repo}-python-packages"
  role       = "roles/artifactregistry.repoAdmin"
  member     = "serviceAccount:${google_service_account.gha_iac.email}"

  depends_on = [google_artifact_registry_repository.additional_registry]
}
