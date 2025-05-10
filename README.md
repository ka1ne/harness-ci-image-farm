# Harness CI Image Farm

A Terraform module for implementing a Harness CI Farm Pipeline to manage Harness CI Container Images in your own registry.

> *I yoinked the code from [harness-community's ci factory](https://github.com/harness-community/solutions-architecture/tree/main/harness-ci-factory) and updated it to use the [harness terraform provider](https://registry.terraform.io/providers/harness/harness/latest/docs)*

## Usage

This module requires proper Harness provider configuration in your root module. First, set up the provider:

```terraform
terraform {
  required_providers {
    harness = {
      source  = "harness/harness"
      version = ">= 0.14"
    }
  }
  required_version = ">= 1.2.0"
}

provider "harness" {
  endpoint         = "https://app.harness.io/gateway"
  account_id       = var.harness_account_id  # Your Harness account ID
  platform_api_key = var.harness_api_key     # Your Harness platform API key
}
```

Then use the module:

```terraform
module "harness-ci-farm" {
  source = "git::https://github.com/ka1ne/harness-ci-image-farm.git"

  # Required Harness authentication parameters
  harness_platform_url      = "https://app.harness.io/gateway"
  harness_platform_account  = var.harness_account_id
  harness_platform_key      = var.harness_api_key
  harness_api_key_secret    = "account.harness_api_token"

  # Organization and project settings
  organization_name         = "harness-ci-farm"
  create_organization       = true
  project_name              = "harness-ci-farm"
  create_project            = true
  
  # Registry settings
  container_registry              = "registry.example.com"
  container_registry_type         = "docker"  # Supported: "docker" or "azure"
  container_registry_connector_ref = "account.registry_example_com"
  
  # Kubernetes settings for build environment
  kubernetes_connector_ref  = "account.example_cluster"
  kubernetes_namespace      = "harnessciimages"
  
  # Optional settings with defaults
  max_build_concurrency     = 2
  schedule                  = "0 2 * * *"
  modify_default_image_config = true
}
```

After the pipeline runs, you will need to edit the `harnessImage` docker connector in your Harness account to point to your registry (specified by the `container_registry` input).

If you do not want to edit this default connector, set `modify_default_image_config` to false. Then in your CI stage under `infrastructure`>`advanced`>`override image connector` select the image connector where you saved the Harness images.

## Authentication

### Environment Variables

You can set authentication via environment variables:
```
HARNESS_ACCOUNT_ID=your_account_id
HARNESS_PLATFORM_API_KEY=your_api_key
```

## Requirements

- Harness Service Account with an API Key
- Kubernetes Connector with a chosen namespace
- Container Registry Connector (Docker or Azure)

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| harness_platform_url | Harness Platform URL | string | "https://app.harness.io/gateway" | No |
| harness_platform_account | Harness Platform Account Number | string | | Yes |
| harness_platform_key | Harness Platform API Key | string | | Yes |
| harness_api_key_secret | Harness secret that holds an API key | string | | Yes |
| organization_name | Organization name (2+ characters) | string | | Yes |
| create_organization | Create a new Organization | bool | false | No |
| project_name | Project name (2+ characters) | string | | Yes |
| create_project | Create a new Project | bool | false | No |
| container_registry | Registry for storing images | string | | Yes |
| container_registry_type | Registry type (azure or docker) | string | | Yes |
| container_registry_connector_ref | Container Registry Connector Reference¹ | string | | Yes |
| kubernetes_connector_ref | Kubernetes Connector Reference¹ | string | | Yes |
| kubernetes_namespace | Kubernetes Namespace for CI builds | string | | Yes |
| max_build_concurrency | Max simultaneous builds | string | 5 | No |
| schedule | Cron schedule format | string | "0 2 * * *" | No |
| modify_default_image_config | Update Harness default images | bool | true | No |

¹ _When providing `_ref` values, prefix with location details (org. or account.) for connectors at those levels. Project connectors need only the reference ID._

## Outputs

| Name | Description |
|------|-------------|
| pipeline | Details of the created Harness pipeline |

## License

MIT License. See LICENSE for full details.
