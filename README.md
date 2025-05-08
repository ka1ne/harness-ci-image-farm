# Harness CI Image Factory

A solution to manage Harness CI build images in your container registry with security scanning capabilities.

## Overview

This solution enables you to:
- Pull Harness CI images from public registries
- Scan images for vulnerabilities
- Push to your private registry
- Configure Harness to use your registry's images

## Quick Start

### Prerequisites
- Harness Account with CI module
- API key with appropriate permissions
- Container registry
- Harness Delegate with network access

### Configuration

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/harness-ci-factory.git
   cd harness-ci-factory
   ```

2. Configure settings:
   ```bash
   # Use example files as templates
   cp secrets.yaml.example secrets.yaml
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit with your values
   vim secrets.yaml terraform.tfvars
   ```

3. Deploy with Helm:
   ```bash
   # Development deployment
   helm upgrade --install harness-ci-factory ./helm/harness-ci-factory \
     -f values.yaml -f secrets.yaml -f values/dev.yaml
   
   # Production deployment
   helm upgrade --install harness-ci-factory ./helm/harness-ci-factory \
     -f values.yaml -f secrets.yaml -f values/prod.yaml
   ```
   
### Alternative: Terraform Deployment

```bash
terraform init
terraform apply -var-file=terraform.tfvars
```

## Key Features

- **Air-gapped support**: Use in isolated environments
- **Rate-limit mitigation**: Avoid Docker Hub rate limiting
- **Security scanning**: Scan images before deployment
- **Custom registry**: Use your preferred container registry
- **Automated updates**: Monitor for new Harness CI image releases

## Configuration Reference

For detailed configuration options:
- See `helm/harness-ci-factory/VALUES.md` for Helm values documentation
- See `CONFIGURATION_MAPPING.md` for mapping between Helm and Terraform variables

## Troubleshooting

Common issues:
1. **Registry connectivity**: Verify delegate has network access to registries
2. **API permissions**: Ensure API key has sufficient permissions
3. **Registry permissions**: Verify write access to target registry 