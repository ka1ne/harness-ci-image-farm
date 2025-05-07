# Harness CI Image Factory

A solution to manage Harness CI build images in a customer-maintained container registry.

## Overview

Harness CI Image Factory provides pipelines to:

1. Pull official Harness CI images from public registries (Docker Hub, GAR, ECR)
2. Push them to your private registry
3. Configure Harness to use your registry's images
4. Verify the configuration and reset to defaults if needed

## Why Use This Solution?

- **Air-gapped environments**: Organizations that operate in air-gapped environments can pre-load Harness CI images to internal registries.
- **Docker Hub rate limiting**: Avoid Docker Hub rate limiting by using your own registry.
- **Image scanning**: Implement security scanning of images before deployment.
- **Versioning control**: Maintain specific versions of Harness CI images in your environment.
- **Bandwidth optimization**: Reduce external bandwidth usage by caching images locally.

## Getting Started

### Prerequisites

- Harness Account with CI module enabled
- API key with appropriate permissions
- Container registry (Docker Registry, ECR, ACR, GCR, etc.)
- Harness Delegate with access to both Harness API and your container registry

### Configuration Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ORG_ID` | Harness organization identifier | Yes | - |
| `PROJECT_ID` | Harness project identifier | Yes | - |
| `HARNESS_URL` | Harness platform URL (e.g., https://app.harness.io) | Yes | - |
| `HARNESS_API_KEY_SECRET` | Secret identifier for Harness API key | Yes | - |
| `REGISTRY_NAME` | Container registry name where images will be stored | Yes | - |
| `CONTAINER_REGISTRY_CONNECTOR` | Harness connector ID for container registry | Yes | - |
| `MODIFY_DEFAULT` | Flag to update Harness platform to use pushed images | No | true |
| `MAX_CONCURRENCY` | Maximum concurrent operations | No | 5 |
| `GATHER_SCAN_TEMPLATE` | Template ID for gathering/scanning stage | Required if using templates | - |
| `BUILD_PUSH_TEMPLATE` | Template ID for build/push stage | Required if using templates | - |

### Pipelines

The solution includes two main pipelines:

1. **Harness CI Image Factory** (`harness_ci_image_factory`): 
   - Pulls Harness CI images
   - Pushes them to your private registry
   - Configures Harness to use your registry

2. **Harness CI Image Factory - Reset Images to Harness** (`harness_ci_image_factory_reset`):
   - Resets custom image configurations back to Harness defaults

### New Features (2024)

- **Multi-Registry Support**: Works with Docker Hub, Google Artifact Registry (GAR), or ECR
- **Infrastructure Type Selection**: Support for both Kubernetes (`K8`) and VM infrastructure types
- **Windows Rootless Support**: Option to include Windows rootless images
- **Updated API Endpoints**: Uses the latest Harness API gateway paths

## Usage Examples

### Pushing Harness CI Images to Your Registry

1. Run the `harness_ci_image_factory` pipeline with parameters:
   - registry: Your registry URL (e.g., `mycompany.jfrog.io/harness-ci`)
   - infrastructure_type: `K8` (for Kubernetes) or `VM`
   - include_windows_rootless: `true` or `false`

2. The pipeline will:
   - Query Harness for the latest CI image tags
   - Pull each image, retag it to your registry
   - Push to your registry
   - Update Harness CI configuration to use your images

### Resetting to Harness Default Images

1. Run the `harness_ci_image_factory_reset` pipeline with parameters:
   - infrastructure_type: `K8` (for Kubernetes) or `VM`
   - include_windows_rootless: `true` or `false` (match your environment)

2. The pipeline will reset all custom image configurations back to Harness defaults.

## Architecture

```
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│                   │     │                   │     │                   │
│  Harness         │     │  Harness          │     │  Your Container   │
│  Public Registry  │────►│  Image Factory    │────►│  Registry         │
│                   │     │  Pipeline         │     │                   │
└───────────────────┘     └───────────────────┘     └───────────────────┘
                                    │
                                    ▼
                          ┌───────────────────┐
                          │                   │
                          │  Harness CI       │
                          │  Config API       │
                          │                   │
                          └───────────────────┘
```

## Troubleshooting

Common issues and resolutions:

1. **Rate Limiting**: If experiencing Docker Hub rate limiting, use the API key authentication for Docker Hub or switch to GAR/ECR source.

2. **Permission Issues**: Ensure your Harness API key has sufficient permissions for CI execution configuration.

3. **Missing Images**: Check the Container Registry connector has appropriate write permissions.

4. **Reset Failure**: If reset operation fails, check for custom configurations that may be locked or protected.

## References

- [Harness CI Images Documentation](https://developer.harness.io/docs/continuous-integration/use-ci/set-up-build-infrastructure/harness-ci/)
- [Connect to Harness Container Registry](https://developer.harness.io/docs/platform/connectors/connect-to-harness-container-image-registry/) 