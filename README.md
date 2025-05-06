# Harness CI Image Factory

This repository contains a modern Harness CI pipeline configuration for managing, rebuilding, and updating Harness CI execution images. The pipeline automates the process of pulling official Harness CI images, rebuilding them with added metadata, pushing them to a private registry, and updating the Harness platform to use these custom images.

## Architecture

The pipeline is composed of the following components:

1. **Main Pipeline** (`harness-image-factory.yaml`) - Orchestrates the entire process
2. **Gather & Scan Template** (`gather-scan-template.yaml`) - Fetches official Harness images and scans them for vulnerabilities
3. **Build & Push Template** (`build-push-template.yaml`) - Builds and pushes images to a private registry

## Features

- **Dynamic Image Discovery**: Automatically discovers official Harness CI images via API
- **Parallel Processing**: Processes multiple images concurrently with configurable concurrency limit
- **Vulnerability Scanning**: Scans images with Trivy before processing
- **Image Verification**: Verifies successful image pushes
- **Compliance Reporting**: Generates compliance reports for all processed images
- **Harness Platform Integration**: Updates Harness platform to use the new images

## Prerequisites

- Harness Account with API key
- Docker registry with push access
- AWS S3 bucket for reports (optional)
- Docker connector configured in Harness
- S3 connector configured in Harness (for reporting)

## Configuration

The pipeline uses the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `registry` | Container registry to push images to | Required |
| `modify_default` | Whether to update Harness default image configuration | `false` |
| `registry_connector` | Connector ID for registry authentication | Required |
| `MAX_CONCURRENCY` | Maximum number of concurrent operations | `5` |
| `HARNESS_URL` | Harness platform URL | `https://app.harness.io/gateway/api/graphql` |
| `HARNESS_API_KEY_SECRET` | Secret identifier for Harness API key | Required |
| `GATHER_SCAN_TEMPLATE` | Template reference for gathering images | Required |
| `BUILD_PUSH_TEMPLATE` | Template reference for building and pushing images | Required |

## Usage

1. Configure the pipeline variables in the Harness UI
2. Create the required secrets:
   - `REGISTRY_USER` - Registry username
   - `REGISTRY_PASSWORD` - Registry password
   - `HARNESS_API_KEY_SECRET` - Harness API key
3. Run the pipeline

## Pipeline Stages

### 1. Gather Harness Images

This stage queries the Harness API to get a list of official Harness CI images used for pipeline execution. It then scans these images for vulnerabilities using Trivy.

### 2. Build and Push Images

For each discovered image, this stage:
- Creates a Dockerfile that adds metadata labels
- Builds the image using BuildKit
- Pushes the image to the specified registry
- Verifies the push was successful

### 3. Update Harness CI Image Configuration

If `modify_default` is enabled, this stage updates the Harness platform to use the newly pushed images as the default versions when running CI pipelines.

### 4. Generate Compliance Report

Creates a compliance report of all processed images and uploads it to S3 for audit purposes.

## Security Considerations

- All images are scanned for vulnerabilities before processing
- Registry credentials are stored as secrets
- Harness API key is stored as a secret
- All built images use the same base as official Harness images

## Customization

To customize the pipeline:

1. Modify the templates to add additional processing steps
2. Add additional security scanning tools
3. Customize the image labels in the Dockerfile
4. Add notifications for completed builds

## Troubleshooting

Common issues:

- **API Connection Failures**: Verify the Harness API key and URL
- **Registry Access Issues**: Check registry credentials and permissions
- **Image Build Failures**: Check for disk space issues or BuildKit daemon failures

## License

Copyright © Harness Inc. All rights reserved. 