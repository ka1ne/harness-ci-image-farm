# Harness CI Image Factory

A solution to manage Harness CI build images in your container registry with security scanning capabilities, built with native Harness Terraform provider resources.

## Overview

This solution enables you to:
- Pull Harness CI images from public registries
- Scan images for vulnerabilities
- Push to your private registry
- Configure Harness to use your registry's images

## Architecture

This solution uses native Harness Terraform provider resources rather than community modules, providing:
- Better control and versioning
- Direct provider support
- Git integration for templates
- Simplified resource management

See [NATIVE_APPROACH.md](./NATIVE_APPROACH.md) for more details on the benefits of this approach.

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

3. Deploy with Terraform:
   ```bash
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

## Key Features

- **Air-gapped support**: Use in isolated environments
- **Rate-limit mitigation**: Avoid Docker Hub rate limiting
- **Security scanning**: Scan images before deployment
- **Custom registry**: Use your preferred container registry
- **Automated updates**: Monitor for new Harness CI image releases
- **Git integration**: Store templates in Git repositories (see `git_template_example.tf`)
- **Resource tagging**: Comprehensive tagging for easy resource management

## Advanced Usage

### Git-based Templates

For enterprise environments, we support Git-based templates:

```bash
# Enable Git-based templates
terraform apply -var-file=terraform.tfvars -var="use_git_templates=true"
```

See `git_template_example.tf` for a detailed example.

### Migration from Community Modules

If you're migrating from community modules to native resources, follow our migration guide:

- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)

## Configuration Reference

For detailed configuration options, see:
- [variables.tf](./variables.tf) for all available variables
- [terraform.tfvars.example](./terraform.tfvars.example) for example configuration

## Troubleshooting

Common issues:
1. **Registry connectivity**: Verify delegate has network access to registries
2. **API permissions**: Ensure API key has sufficient permissions
3. **Registry permissions**: Verify write access to target registry 