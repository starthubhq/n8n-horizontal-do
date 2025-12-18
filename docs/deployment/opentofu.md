# OpenTofu Deployment

This page covers the OpenTofu deployment process in detail.

## Initialization

```bash
tofu init
```

This downloads the required providers (DigitalOcean, etc.).

## Planning

Before applying, always review the plan:

```bash
tofu plan
```

This shows what resources will be created, modified, or destroyed.

## Applying

Deploy the infrastructure:

```bash
tofu apply
```

This will:
1. Create the VPC
2. Create PostgreSQL database cluster (~10-15 minutes)
3. Create Valkey database cluster (~10-15 minutes)
4. Create main droplet
5. Create worker droplets
6. Configure networking and firewall rules

## Outputs

After deployment, get connection details:

```bash
# Main droplet
tofu output main_public_ip
tofu output main_private_ip

# Workers
tofu output worker_public_ips
tofu output worker_private_ips

# PostgreSQL
tofu output database_host
tofu output database_port

# Valkey
tofu output valkey_host
tofu output valkey_port

# Connection strings (sensitive)
tofu output database_connection_string
tofu output valkey_uri

# n8n URL
tofu output n8n_url
```

## State Management

OpenTofu stores state in `terraform.tfstate`. This file contains sensitive information and should be:

- ✅ Kept secure (not committed to public repos)
- ✅ Backed up regularly
- ✅ Shared with team members securely

## Cleanup

To destroy all resources:

```bash
tofu destroy
```

This will remove all created resources. Be careful!

