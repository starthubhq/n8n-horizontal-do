# Terraform Deployment

This page covers the Terraform deployment process in detail.

## Initialization

```bash
terraform init
```

This downloads the required providers (DigitalOcean, etc.).

## Planning

Before applying, always review the plan:

```bash
terraform plan
```

This shows what resources will be created, modified, or destroyed.

## Applying

Deploy the infrastructure:

```bash
terraform apply
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
terraform output main_public_ip
terraform output main_private_ip

# Workers
terraform output worker_public_ips
terraform output worker_private_ips

# PostgreSQL
terraform output database_host
terraform output database_port

# Valkey
terraform output valkey_host
terraform output valkey_port

# Connection strings (sensitive)
terraform output database_connection_string
terraform output valkey_uri

# n8n URL
terraform output n8n_url
```

## State Management

Terraform stores state in `terraform.tfstate`. This file contains sensitive information and should be:

- ✅ Kept secure (not committed to public repos)
- ✅ Backed up regularly
- ✅ Shared with team members securely

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

This will remove all created resources. Be careful!

