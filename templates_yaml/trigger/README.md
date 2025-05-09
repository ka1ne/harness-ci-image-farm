# Trigger Templates

This directory contains standardized YAML templates for Harness triggers.

## Usage with Terraform

These templates can be used with the Harness Terraform provider:

```hcl
resource "harness_platform_triggers" "example_trigger" {
  identifier = "example_trigger"
  org_id     = var.org_id
  project_id = var.project_id
  name       = "Example Trigger"
  
  # Use file() for static triggers
  yaml = file("${path.module}/templates_yaml/trigger/harness-ecr-polling-trigger.yaml")
  
  # Use templatefile() for dynamic interpolation
  # yaml = templatefile(
  #   "${path.module}/templates_yaml/trigger/harness-ecr-polling-trigger.yaml", 
  #   {
  #     SCHEDULE     = "0 */6 * * *",
  #     PIPELINE_ID  = "harness_ci_image_factory",
  #     REGISTRY_NAME = "ecr-public", 
  #     MODIFY_DEFAULT = "true"
  #   }
  # )
}
```

## Template Structure

All trigger templates follow the standard Harness structure with a `trigger:` root element:

```yaml
trigger:
  name: Example Trigger
  identifier: example_trigger
  description: "Description of the trigger purpose"
  enabled: true
  tags:
    created_by: Terraform
    
  # Source definition (scheduled, webhook, etc.)
  source:
    type: Scheduled
    spec:
      type: Cron
      spec:
        expression: ${SCHEDULE}
        timeZone: UTC
  
  # Pipeline inputs
  inputYaml: |
    pipeline:
      identifier: ${PIPELINE_ID}
      variables:
        - name: example_var
          type: String
          value: "example_value"
```

## Available Templates

- **harness-ecr-polling-trigger.yaml**: Polls ECR registry for new Harness images
- **harness-image-update-trigger.yaml**: Monitors for Harness CI image updates via webhook
- **retrieve-and-build-images.yaml**: Scheduled trigger for image retrieval and building
- **harness-image-factory-trigger.yaml**: Main trigger for the CI image factory pipeline

## Template Variables

Common variables used in these templates:

| Variable | Description | Default |
|----------|-------------|---------|
| SCHEDULE | Cron expression for scheduled triggers | "0 */6 * * *" (every 6 hours) |
| PIPELINE_ID | Target pipeline identifier | "harness_ci_image_factory" |
| REGISTRY_NAME | Registry to query for images | "ecr-public" |
| MODIFY_DEFAULT | Whether to modify default images | "true" | 