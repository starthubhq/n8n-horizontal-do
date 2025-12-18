# Quick Start

Get your production grade horizontal n8n deployment up and running in minutes.

## Prerequisites

Before you begin, ensure you have:

1. **DigitalOcean API token**: [Create one here](https://cloud.digitalocean.com/account/api/tokens)
2. **SSH key added to DigitalOcean**: [Add it here](https://cloud.digitalocean.com/account/security)
3. **Terraform installed**: [Download here](https://www.terraform.io/downloads)

## Step 1: Configure Variables

```bash
# Copy example configuration
cp .tfvars.example variables.tfvars

# Edit variables.tfvars with your settings
nano variables.tfvars
```

## Step 2: Initialize Terraform

```bash
# Initialize Terraform
terraform init
```

## Step 3: Review the Plan

```bash
# Review what will be created
terraform plan
```

## Step 4: Deploy

```bash
# Deploy the infrastructure
terraform apply
```

This will create:
- PostgreSQL database cluster
- Valkey (Redis) database cluster
- Main droplet (n8n coordinator/web UI)
- Worker droplets (scalable n8n workers)
- VPC for secure private networking

## Step 5: Access n8n

After deployment completes (~10-15 minutes), get your n8n URL:

```bash
terraform output n8n_url
```

Then:
1. Open the URL in your browser
2. Complete the n8n setup wizard
3. Start creating workflows!

## Next Steps

- Review the [Architecture Overview](../architecture/overview.md) to understand the infrastructure
- Check [Configuration](../configuration/variables.md) for customization options
- See [Troubleshooting](../troubleshooting.md) if you encounter issues

