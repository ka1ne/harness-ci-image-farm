resource "harness_platform_organization" "organization" {
  identifier  = var.organization_name
  name        = var.organization_name
  description = "Harness CI Image Factory Organization"
  count       = var.create_organization ? 1 : 0
}

data "harness_platform_organization" "existing_organization" {
  identifier = var.organization_name
  count      = var.create_organization ? 0 : 1
}

locals {
  organization_id = var.create_organization ? harness_platform_organization.organization[0].id : data.harness_platform_organization.existing_organization[0].id
}

resource "harness_platform_project" "project" {
  identifier  = var.project_name
  name        = var.project_name
  org_id      = local.organization_id
  description = "Harness CI Image Factory Project"
  count       = var.create_project ? 1 : 0
}

data "harness_platform_project" "existing_project" {
  identifier = var.project_name
  org_id     = local.organization_id
  count      = var.create_project ? 0 : 1
}

locals {
  project_id       = var.create_project ? harness_platform_project.project[0].id : data.harness_platform_project.existing_project[0].id
  template_version = "v1.1.4"
}

resource "harness_platform_template" "gather_harness_ci_images_template" {
  identifier = "gather_harness_ci_images"
  name       = "Gather Harness CI Images"
  org_id     = local.organization_id
  project_id = local.project_id
  version    = local.template_version
  is_stable  = true
  template_yaml = templatefile(
    "${path.module}/templates/templates/gather-harness-ci-image-list.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
      PROJECT_IDENTIFIER : var.project_name
      ORG_IDENTIFIER : var.organization_name
      VERSION : local.template_version
    }
  )
}

resource "harness_platform_template" "build_push_template" {
  identifier = "build_push_harness_ci_images"
  name       = "Build and Push Harness CI Standard Images"
  org_id     = local.organization_id
  project_id = local.project_id
  version    = local.template_version
  is_stable  = true
  template_yaml = templatefile(
    "${path.module}/templates/templates/${lookup(local.build_push_target, var.container_registry_type, "MISSING-REGISTRY-TEMPLATE")}",
    {
      REGISTRY_NAME : var.container_registry
      MAX_CONCURRENCY : var.max_build_concurrency
      CONTAINER_REGISTRY_CONNECTOR : var.container_registry_connector_ref
      KUBERNETES_CONNECTOR_REF : var.kubernetes_connector_ref
      KUBERNETES_NAMESPACE : var.kubernetes_namespace
      PROJECT_IDENTIFIER : var.project_name
      ORG_IDENTIFIER : var.organization_name
      VERSION : local.template_version
    }
  )
}

resource "harness_platform_pipeline" "harness_ci_image_factory" {
  identifier  = "harness_ci_image_factory"
  name        = "Harness CI Image Factory"
  org_id      = local.organization_id
  project_id  = local.project_id
  description = "This pipeline will find, build, push, and configure Harness Platform to retrieve CI build images from a custom registry"
  yaml = templatefile(
    "${path.module}/templates/pipelines/harness-ci-image-factory.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
      GATHER_SCAN_TEMPLATE : harness_platform_template.gather_harness_ci_images_template.identifier
      BUILD_PUSH_TEMPLATE : harness_platform_template.build_push_template.identifier
      REGISTRY_NAME : var.container_registry
      MAX_CONCURRENCY : var.max_build_concurrency
      CONTAINER_REGISTRY_CONNECTOR : var.container_registry_connector_ref
      KUBERNETES_CONNECTOR_REF : var.kubernetes_connector_ref
      KUBERNETES_NAMESPACE : var.kubernetes_namespace
      MODIFY_DEFAULT : tostring(var.modify_default_image_config)
      PROJECT_IDENTIFIER : var.project_name
      ORG_IDENTIFIER : var.organization_name
    }
  )
}

resource "harness_platform_pipeline" "harness_ci_image_factory_cleanup" {
  identifier  = "harness_ci_image_factory_cleanup"
  name        = "Harness CI Image Factory - Reset Images to Harness"
  org_id      = local.organization_id
  project_id  = local.project_id
  description = "This pipeline will reset the custom images back to the default Harness Platform values"
  yaml = templatefile(
    "${path.module}/templates/pipelines/harness-ci-image-reset.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
      GATHER_SCAN_TEMPLATE : harness_platform_template.gather_harness_ci_images_template.identifier
      PROJECT_IDENTIFIER : var.project_name
      ORG_IDENTIFIER : var.organization_name
      MAX_CONCURRENCY : var.max_build_concurrency
    }
  )
}

resource "harness_platform_triggers" "pipeline_execution_schedule" {
  identifier = "retrieve_and_build_images"
  name       = "Retrieve and Build Images"
  org_id     = local.organization_id
  project_id = local.project_id
  target_id  = harness_platform_pipeline.harness_ci_image_factory.id
  yaml = templatefile(
    "${path.module}/templates/triggers/retrieve-and-build-images.yaml",
    {
      SCHEDULE : var.schedule
      REGISTRY_NAME : var.container_registry
      PROJECT_IDENTIFIER : var.project_name
      ORG_IDENTIFIER : var.organization_name
    }
  )
}
