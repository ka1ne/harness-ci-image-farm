terraform {
  required_providers {
    harness = {
      source  = "harness/harness"
      version = ">= 0.37.0"
    }
  }
  backend "s3" {
    bucket         = "harness-terraform-state"
    key            = "harness-ci/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "harness" {
  endpoint         = var.harness_platform_url
  account_id       = var.harness_platform_account
  platform_api_key = var.harness_platform_key
}

locals {
  build_push_target = {
    "ecr"        = "ecr-build-push.yaml"
    "docker-hub" = "docker-hub-build-push.yaml"
    "gcp"        = "gcr-build-push.yaml"
    "azure"      = "acr-build-push.yaml"
  }
}

# Organization and Project setup - using native resources
resource "harness_platform_organization" "organization" {
  identifier = var.organization_name
  name       = var.organization_name
  # Only create if not existing
  count      = var.create_organization ? 1 : 0
}

resource "harness_platform_project" "project" {
  identifier  = var.project_name
  name        = var.project_name
  org_id      = var.create_organization ? harness_platform_organization.organization[0].identifier : var.organization_name
  # Only create if not existing
  count       = var.create_project ? 1 : 0
}

# Example pipeline template
resource "harness_platform_template" "example_pipeline_template" {
  identifier = "tf_example_pipeline_template"
  name       = "Terraform Example Pipeline Template"
  org_id     = local.org_id
  project_id = local.project_id
  comments   = "This is an example pipeline template managed by Terraform."
  version    = "v0.1.0"
  is_stable  = true
  
  template_yaml = templatefile("${path.module}/templates_yaml/pipeline/pipeline_template.yaml.tftpl", {
    project_id = local.project_id,
    org_id     = local.org_id
  })
}

# Step Templates
resource "harness_platform_template" "image_scan_step_template" {
  identifier    = "harness_image_security_scan"
  name          = "Harness Image Security Scan"
  version       = "1.0.0"
  is_stable     = true
  org_id        = local.org_id
  project_id    = local.project_id
  
  comments = "Terraform managed template for image security scanning step."

  template_yaml = templatefile("${path.module}/templates_yaml/step/image-ingestion-scan-template.yaml", {
    PROJECT_ID = local.project_id,
    ORG_ID     = local.org_id
  })
}

# resource "harness_platform_template" "gather_harness_ci_images" {
#   identifier    = "gather_harness_ci_images"
#   name          = "Gather Harness CI Images"
#   version       = "1.0.0"
#   is_stable     = true
#   org_id        = local.org_id
#   project_id    = local.project_id
  
#   comments = "Template for gathering Harness CI images"

#   template_yaml = templatefile(
#     "${path.module}/templates_yaml/step/gather-harness-ci-image-list.yaml",
#     {
#       HARNESS_URL = var.harness_platform_url
#       HARNESS_API_KEY_SECRET = var.harness_api_key_secret
#       PROJECT_ID = local.project_id
#       ORG_ID = local.org_id
#     }
#   )
# }

# # Pipeline Templates
# resource "harness_platform_template" "build_push_templates" {
#   identifier    = "build_and_push_harness_ci_standard_images"
#   name          = "Build and Push Harness CI Standard Images"
#   version       = "1.0.0"
#   is_stable     = true
#   org_id        = local.org_id
#   project_id    = local.project_id
  
#   comments = "Template for building Harness CI images"

#   template_yaml = templatefile(
#     "${path.module}/templates_yaml/pipeline/${lookup(local.build_push_target, var.container_registry_type, "MISSING-REGISTRY-TEMPLATE")}",
#     {
#       PROJECT_ID = local.project_id
#       ORG_ID = local.org_id
#       REGISTRY_NAME = var.container_registry
#       MAX_CONCURRENCY = var.max_build_concurrency
#       CONTAINER_REGISTRY_CONNECTOR = var.container_registry_connector_ref
#       KUBERNETES_CONNECTOR_REF = var.kubernetes_connector_ref
#       KUBERNETES_NAMESPACE = var.kubernetes_namespace
#     }
#   )
# }

resource "harness_platform_template" "ecr_ingestion_pipeline_template" {
  identifier    = "harness_ecr_image_ingestion"
  name          = "Harness ECR Image Ingestion with Scanning"
  version       = "1.0.0"
  is_stable     = true
  org_id        = local.org_id
  project_id    = local.project_id
  
  comments = "Terraform managed template for ECR image ingestion pipeline with scanning."

  template_yaml = templatefile("${path.module}/templates_yaml/pipeline/harness-ecr-ingestion-template.yaml", {
    PROJECT_ID = local.project_id,
    ORG_ID     = local.org_id
  })
}

# Trigger Templates
resource "harness_platform_template" "ecr_trigger_template" {
  identifier    = "harness_ecr_image_ingestion_trigger"
  name          = "Harness ECR Image Ingestion Trigger"
  version       = "1.0.0"
  is_stable     = true
  org_id        = local.org_id
  project_id    = local.project_id
  
  comments = "Terraform managed template for ECR image ingestion trigger."

  template_yaml = templatefile("${path.module}/templates_yaml/trigger/harness-ecr-trigger-template.yaml.tftpl", {
    PROJECT_ID = local.project_id,
    ORG_ID     = local.org_id
  })
}

resource "harness_platform_template" "image_factory_trigger_template" {
  identifier    = "harness_ci_image_factory_trigger"
  name          = "Harness CI Image Factory Trigger"
  version       = "1.0.0"
  is_stable     = true
  org_id        = local.org_id
  project_id    = local.project_id
  
  comments = "Terraform managed template for CI image factory trigger."

  template_yaml = templatefile("${path.module}/templates_yaml/trigger/harness-image-factory-trigger.yaml", {
    PROJECT_ID = local.project_id,
    ORG_ID     = local.org_id
  })
}

# Pipelines
resource "harness_platform_pipeline" "harness_ci_image_factory" {
  identifier  = "harness_ci_image_factory"
  name        = "Harness CI Image Factory"
  description = "This pipeline will find, build, push, and configure Harness Platform to retrieve CI build images from a custom registry"
  org_id      = local.org_id
  project_id  = local.project_id
  
  yaml = templatefile(
    "${path.module}/templates_yaml/pipeline/harness-ci-image-factory.yaml",
    {
      HARNESS_URL = var.harness_platform_url
      HARNESS_API_KEY_SECRET = var.harness_api_key_secret
      # GATHER_SCAN_TEMPLATE = harness_platform_template.gather_harness_ci_images.identifier
      # BUILD_PUSH_TEMPLATE = harness_platform_template.build_push_templates.identifier
      REGISTRY_NAME = var.container_registry
      MAX_CONCURRENCY = var.max_build_concurrency
      CONTAINER_REGISTRY_CONNECTOR = var.container_registry_connector_ref
      KUBERNETES_CONNECTOR_REF = var.kubernetes_connector_ref
      KUBERNETES_NAMESPACE = var.kubernetes_namespace
      MODIFY_DEFAULT = tostring(var.modify_default_image_config)
    }
  )
}

resource "harness_platform_pipeline" "harness_ci_image_factory_cleanup" {
  identifier  = "harness_ci_image_factory_reset"
  name        = "Harness CI Image Factory - Reset Images to Harness"
  description = "This pipeline will reset the custom images back to the default Harness Platform values"
  org_id      = local.org_id
  project_id  = local.project_id
  
  yaml = templatefile(
    "${path.module}/templates_yaml/pipeline/harness-ci-image-reset.yaml",
    {
      HARNESS_URL = var.harness_platform_url
      HARNESS_API_KEY_SECRET = var.harness_api_key_secret
      GATHER_SCAN_TEMPLATE = harness_platform_template.gather_harness_ci_images.identifier
    }
  )
}

# Input Sets
resource "harness_platform_input_set" "image_factory_dev_inputs" {
  identifier  = "image_factory_dev_inputs"
  name        = "Image Factory Dev Environment Inputs"
  org_id      = local.org_id
  project_id  = local.project_id
  pipeline_id = harness_platform_pipeline.harness_ci_image_factory.id
  
  yaml = templatefile("${path.module}/templates_yaml/input_set/image-factory-dev-inputs.yaml", {
    PIPELINE_ID = harness_platform_pipeline.harness_ci_image_factory.id
    REGISTRY_NAME = var.container_registry
    MODIFY_DEFAULT = tostring(var.modify_default_image_config)
  })
}

resource "harness_platform_input_set" "image_factory_prod_inputs" {
  identifier  = "image_factory_prod_inputs"
  name        = "Image Factory Production Environment Inputs"
  org_id      = local.org_id
  project_id  = local.project_id
  pipeline_id = harness_platform_pipeline.harness_ci_image_factory.id
  
  yaml = templatefile("${path.module}/templates_yaml/input_set/image-factory-prod-inputs.yaml", {
    PIPELINE_ID = harness_platform_pipeline.harness_ci_image_factory.id
    REGISTRY_NAME = var.container_registry
    MODIFY_DEFAULT = tostring(var.modify_default_image_config)
  })
}

# Triggers
resource "harness_platform_triggers" "pipeline_execution_schedule" {
  identifier  = "retrieve_and_build_images"
  name        = "Retrieve and Build Images"
  description = "Scheduled execution of the CI Image Factory pipeline"
  org_id      = local.org_id
  project_id  = local.project_id
  target_id   = harness_platform_pipeline.harness_ci_image_factory.id
  
  yaml = templatefile(
    "${path.module}/templates_yaml/trigger/retrieve-and-build-images.yaml",
    {
      SCHEDULE = var.schedule
      REGISTRY_NAME = var.container_registry
    }
  )
}

resource "harness_platform_triggers" "ecr_polling_trigger" {
  identifier  = "poll_ecr_registry_for_new_harness_images"
  name        = "Poll ECR Registry for New Harness Images"
  description = "Automatically poll ECR for new Harness images"
  org_id      = local.org_id
  project_id  = local.project_id
  target_id   = harness_platform_pipeline.harness_ci_image_factory.id
  
  yaml = templatefile(
    "${path.module}/templates_yaml/trigger/harness-ecr-polling-trigger.yaml",
    {
      SCHEDULE = "0 */6 * * *" # Poll every 6 hours by default
      PIPELINE_ID = harness_platform_pipeline.harness_ci_image_factory.id
      REGISTRY_NAME = var.container_registry
      MODIFY_DEFAULT = tostring(var.modify_default_image_config)
    }
  )
}

resource "harness_platform_triggers" "rss_webhook_trigger" {
  identifier  = "harness_ci_rss_feed_monitor"
  name        = "Harness CI RSS Feed Monitor"
  description = "Monitor Harness CI updates via RSS feed"
  org_id      = local.org_id
  project_id  = local.project_id
  target_id   = harness_platform_pipeline.harness_ci_image_factory.id
  
  yaml = templatefile(
    "${path.module}/templates_yaml/trigger/harness-image-update-trigger.yaml",
    {
      PIPELINE_ID = harness_platform_pipeline.harness_ci_image_factory.id
      REGISTRY_NAME = var.container_registry
      MODIFY_DEFAULT = tostring(var.modify_default_image_config)
    }
  )
}

# CI Addon Image Management via Execution Config API
resource "null_resource" "ci_execution_config" {
  triggers = {
    addon_tag = var.ci_addon_image_tag
    lite_engine_tag = var.ci_lite_engine_tag
    time = timestamp() # Force update on each apply to check current config
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get current customer config
      CONFIG=$(curl -s -X GET \
        "${var.harness_platform_url}/gateway/ci/execution-config/get-customer-config?accountIdentifier=${var.harness_platform_account}" \
        -H "X-API-KEY: ${var.harness_platform_key}" \
        -H "Content-Type: application/json")
      
      # Update config if needed
      if [ $(echo "$CONFIG" | grep -c "${var.ci_addon_image_tag}") -eq 0 ] || [ $(echo "$CONFIG" | grep -c "${var.ci_lite_engine_tag}") -eq 0 ]; then
        curl -s -X POST \
          "${var.harness_platform_url}/gateway/ci/execution-config/update-config?accountIdentifier=${var.harness_platform_account}" \
          -H "X-API-KEY: ${var.harness_platform_key}" \
          -H "Content-Type: application/json" \
          -d '{
            "fields": [
              {
                "name": "addonTag",
                "value": "harness/ci-addon:${var.ci_addon_image_tag}"
              },
              {
                "name": "liteEngineTag",
                "value": "harness/ci-lite-engine:${var.ci_lite_engine_tag}"
              }
            ]
          }'
      fi
    EOT
  }
} 