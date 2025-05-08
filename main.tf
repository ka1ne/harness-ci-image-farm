provider "harness" {
  endpoint         = var.harness_platform_url
  account_id       = var.harness_platform_account
  platform_api_key = var.harness_platform_key
}

resource "harness_platform_template" "example_pipeline_template" {
  identifier = "tf_example_pipeline_template"
  name       = "Terraform Example Pipeline Template"
  
  # Set org_id and project_id if you want this template at org or project scope
  # If var.harness_org_id is null, it will be an account-level template (if project_id is also null)
  # If var.harness_project_id is null but org_id is set, it will be an org-level template
  org_id     = var.harness_org_id 
  project_id = var.harness_project_id

  comments   = "This is an example pipeline template managed by Terraform."
  version     = "v0.1.0" # Initial version
  tags        = ["terraform-managed", "example"]

  template_yaml = templatefile("${path.module}/pipeline_template.yaml.tftpl", {
    project_id = var.harness_project_id,
    org_id     = var.harness_org_id
  })

  lifecycle {
    # If you change the template_yaml and want to force a new version to be created in Harness,
    # you'll need to update the 'version' attribute above.
    # Alternatively, for some advanced scenarios, create_before_destroy can be useful.
    # create_before_destroy = true
  }
}

// Additional Templates from YAML files

resource "harness_platform_template" "ecr_trigger_template" {
  identifier    = "harness_ecr_image_ingestion_trigger"
  name          = "Harness ECR Image Ingestion Trigger"
  version       = "1.0.0"
  org_id        = module.organization.details.id
  project_id    = module.project.details.id
  tags          = ["terraform-managed", "ecr-ingestion", "trigger"]
  comments      = "Terraform managed template for ECR image ingestion trigger."

  template_yaml = templatefile("${path.module}/templates/trigger/harness-ecr-trigger-template.yaml.tftpl", {
    PROJECT_ID = module.project.details.id,
    ORG_ID     = module.organization.details.id
  })
}

resource "harness_platform_template" "ecr_ingestion_pipeline_template" {
  identifier    = "harness_ecr_image_ingestion"
  name          = "Harness ECR Image Ingestion with Scanning"
  version       = "1.0.0"
  org_id        = module.organization.details.id
  project_id    = module.project.details.id
  tags          = ["terraform-managed", "ecr-ingestion", "pipeline"]
  comments      = "Terraform managed template for ECR image ingestion pipeline with scanning."

  template_yaml = templatefile("${path.module}/templates/pipeline/harness-ecr-ingestion-template.yaml", {
    PROJECT_ID = module.project.details.id,
    ORG_ID     = module.organization.details.id
  })
}

resource "harness_platform_template" "image_scan_step_template" {
  identifier    = "harness_image_security_scan"
  name          = "Harness Image Security Scan"
  version       = "1.0.0"
  org_id        = module.organization.details.id
  project_id    = module.project.details.id
  tags          = ["terraform-managed", "security-scan", "step"]
  comments      = "Terraform managed template for image security scanning step."

  template_yaml = templatefile("${path.module}/templates/step/image-ingestion-scan-template.yaml", {
    PROJECT_ID = module.project.details.id,
    ORG_ID     = module.organization.details.id
  })
}

resource "harness_platform_template" "image_factory_trigger_template" {
  identifier    = "harness_ci_image_factory_trigger"
  name          = "Harness CI Image Factory Trigger"
  version       = "1.0.0"
  org_id        = module.organization.details.id
  project_id    = module.project.details.id
  tags          = ["terraform-managed", "image-factory", "trigger"]
  comments      = "Terraform managed template for CI image factory trigger."

  template_yaml = templatefile("${path.module}/triggers/harness-image-factory-trigger.yaml", {
    PROJECT_ID = module.project.details.id,
    ORG_ID     = module.organization.details.id
  })
}

module "organization" {
  source  = "harness-community/structure/harness//modules/organizations"
  version = "0.1.2"

  name     = var.organization_name
  existing = var.create_organization ? false : true
}

module "project" {
  source  = "harness-community/structure/harness//modules/projects"
  version = "0.1.2"

  name            = var.project_name
  organization_id = module.organization.details.id
  existing        = var.create_project ? false : true
}

module "gather-harness-ci-images-template" {
  source  = "harness-community/content/harness//modules/templates"
  version = "0.1.1"

  name             = "Gather Harness CI Images"
  organization_id  = module.organization.details.id
  project_id       = module.project.details.id
  template_version = "v1.0.0"
  type             = "Stage"
  yaml_data = templatefile(
    "${path.module}/templates/templates/gather-harness-ci-image-list.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
    }
  )
  tags = {
    role = "harness-ci-image-factory"
  }
}

module "build-push-template" {
  source  = "harness-community/content/harness//modules/templates"
  version = "0.1.1"

  name             = "Build and Push Harness CI Standard Images"
  organization_id  = module.organization.details.id
  project_id       = module.project.details.id
  template_version = "v1.0.0"
  type             = "Stage"
  yaml_data = templatefile(
    "${path.module}/templates/templates/${lookup(local.build_push_target, var.container_registry_type, "MISSING-REGISTRY-TEMPLATE")}",
    {
      REGISTRY_NAME : var.container_registry
      MAX_CONCURRENCY : var.max_build_concurrency
      CONTAINER_REGISTRY_CONNECTOR : var.container_registry_connector_ref
      KUBERNETES_CONNECTOR_REF : var.kubernetes_connector_ref
      KUBERNETES_NAMESPACE : var.kubernetes_namespace
    }
  )
  tags = {
    role = "harness-ci-image-factory"
  }
}

module "harness-ci-image-factory" {
  source  = "harness-community/content/harness//modules/pipelines"
  version = "0.1.1"

  name            = "Harness CI Image Factory"
  description     = "This pipeline will find, build, push, and configure Harness Platform to retrieve CI build images from a custom registry"
  organization_id = module.organization.details.id
  project_id      = module.project.details.id
  yaml_data = templatefile(
    "${path.module}/templates/pipelines/harness-ci-image-factory.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
      GATHER_SCAN_TEMPLATE : module.gather-harness-ci-images-template.details.id
      BUILD_PUSH_TEMPLATE : module.build-push-template.details.id
      REGISTRY_NAME : var.container_registry
      MAX_CONCURRENCY : var.max_build_concurrency
      CONTAINER_REGISTRY_CONNECTOR : var.container_registry_connector_ref
      KUBERNETES_CONNECTOR_REF : var.kubernetes_connector_ref
      KUBERNETES_NAMESPACE : var.kubernetes_namespace
      MODIFY_DEFAULT : tostring(var.modify_default_image_config)
    }
  )
  tags = {
    role = "harness-ci-image-factory"
  }
}

module "harness-ci-image-factory-cleanup" {
  source  = "harness-community/content/harness//modules/pipelines"
  version = "0.1.1"

  name            = "Harness CI Image Factory - Reset Images to Harness"
  description     = "This pipeline will reset the custom images back to the default Harness Platform values"
  organization_id = module.organization.details.id
  project_id      = module.project.details.id
  yaml_data = templatefile(
    "${path.module}/templates/pipelines/harness-ci-image-reset.yaml",
    {
      HARNESS_URL : var.harness_platform_url
      HARNESS_API_KEY_SECRET : var.harness_api_key_secret
      GATHER_SCAN_TEMPLATE : module.gather-harness-ci-images-template.details.id
    }
  )
  tags = {
    role = "harness-ci-image-factory"
  }
}

module "pipeline-execution-schedule" {
  source  = "harness-community/content/harness//modules/triggers"
  version = "0.1.1"

  name            = "Retrieve and Build Images"
  organization_id = module.organization.details.id
  project_id      = module.project.details.id
  pipeline_id     = module.harness-ci-image-factory.details.id
  trigger_enabled = var.enable_schedule
  yaml_data = templatefile(
    "${path.module}/templates/triggers/retrieve-and-build-images.yaml",
    {
      SCHEDULE : var.schedule
      REGISTRY_NAME : var.container_registry
    }
  )
  tags = {
    role = "harness-ci-image-factory"
  }
}

module "ecr-polling-trigger" {
  source  = "harness-community/content/harness//modules/triggers"
  version = "0.1.1"

  name            = "Poll ECR Registry for New Harness Images"
  organization_id = module.organization.details.id
  project_id      = module.project.details.id
  pipeline_id     = module.harness-ci-image-factory.details.id
  trigger_enabled = true
  yaml_data = templatefile(
    "${path.module}/templates/triggers/harness-ecr-polling-trigger.yaml",
    {
      SCHEDULE : "0 */6 * * *",  # Poll every 6 hours by default
      PIPELINE_ID : module.harness-ci-image-factory.details.id,
      REGISTRY_NAME : var.container_registry,
      MODIFY_DEFAULT : tostring(var.modify_default_image_config)
    }
  )
  tags = {
    role = "harness-ci-image-factory"
    source = "ecr-public"
  }
} 