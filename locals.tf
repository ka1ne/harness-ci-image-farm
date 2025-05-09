locals {
  build_push_target = {
    azure  = "harness-ci-build-images-azure.yaml"
    docker = "harness-ci-build-images-docker.yaml"
  }
  
  # Common organization and project IDs
  org_id     = var.create_organization ? harness_platform_organization.organization[0].identifier : var.organization_name
  project_id = var.create_project ? harness_platform_project.project[0].identifier : var.project_name
} 