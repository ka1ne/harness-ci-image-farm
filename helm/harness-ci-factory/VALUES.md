# Helm Values Configuration for Harness CI Factory

This document explains the Helm values configuration approach for the Harness CI Factory.

## Values Files Structure

The chart uses multiple values files to separate different types of configurations:

- `values.yaml`: Default non-sensitive values
- `secrets.yaml`: Sensitive values (not included in the repository)
- `values/` directory: Environment-specific configurations
  - `values/dev.yaml`: Development environment values
  - `values/prod.yaml`: Production environment values

## Handling Secrets

For security reasons, sensitive data such as Harness API keys and account IDs should be stored in a separate `secrets.yaml` file that is **not committed to version control**.

1. Copy the `secrets.yaml.example` from the repository root to create your own `secrets.yaml`
2. Fill in your actual secrets
3. Ensure `secrets.yaml` is listed in `.gitignore`

Example secrets.yaml structure:

```yaml
global:
  harness:
    secrets:
      accountId: "your-account-id"
      apiKey: "your-api-key"
      apiKeySecret: "harness.apikey"
```

## Deploying with Multiple Values Files

To deploy the Helm chart with multiple values files, use:

```bash
# Development deployment
helm upgrade --install harness-ci-factory ./helm/harness-ci-factory \
  -f values.yaml \
  -f secrets.yaml \
  -f values/dev.yaml

# Production deployment
helm upgrade --install harness-ci-factory ./helm/harness-ci-factory \
  -f values.yaml \
  -f secrets.yaml \
  -f values/prod.yaml
```

## Values Precedence

When using multiple values files, later files override earlier ones. The precedence order for the above commands is:

1. Default values from `values.yaml`
2. Secrets from `secrets.yaml`
3. Environment-specific values from `values/dev.yaml` or `values/prod.yaml`

## Configuration Reference

For detailed information about all available configuration parameters, see the comments in `values.yaml` and `values-sample.yaml`. 