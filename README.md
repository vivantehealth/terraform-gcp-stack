# terraform-gcp-stack

Provisions the prerequisites for a stack to run it's own tf pipeline.

Sets up the github repo's environments and repo-environment 'secrets' (which aren't really secret) for the terraform plan and terraform apply steps. Also creates the repo's terraform service accounts. It usually goes along with the instantiation of the terraform-gcp-gha-secret-rotation module, which rotates the service account keys.

## Development
During development, the module can be referenced with the following syntax

```
  source = "github.com/vivantehealth/terraform-gcp-stack?ref=<commit-sha>"
```

When merging a PR, a release is created, bumping the patch version by default. To bump the minor or major version, ensure that the head commit of the PR contains the text `#minor` or `#major`.
