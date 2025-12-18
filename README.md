# n8n Horizontal Scaling on DigitalOcean

This Terraform configuration deploys n8n with horizontal scaling on DigitalOcean, including:
- PostgreSQL database cluster
- Valkey (Redis) database cluster
- Main droplet (n8n coordinator/web UI)
- Worker droplets (scalable n8n workers)
- VPC for secure private networking

## Prerequisites

1. DigitalOcean API token: https://cloud.digitalocean.com/account/api/tokens
2. SSH key added to DigitalOcean: https://cloud.digitalocean.com/account/security
3. Terraform installed: https://www.terraform.io/downloads

## Quick Start


```bash
# Copy example configuration
cp .tfvars.example variables.tfvars

# Edit variables.tfvars with your settings
nano variables.tfvars

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

## Docker & Docker Compose

All droplets use the `docker-20-04` marketplace image which comes with:
- ✅ **Docker Engine** pre-installed
- ✅ **Docker Compose** pre-installed
- ✅ **Ubuntu 20.04 LTS** base system

This means Docker and Docker Compose are **ready to use immediately** after deployment.

## Initialization Scripts

### Main Instance (`main-init.sh`)

The main droplet automatically runs `main-init.sh` on first boot, which:
- Sets `EXECUTIONS_MODE=queue` (enables n8n queue mode for horizontal scaling)
- Creates Docker volume for n8n data persistence
- Starts n8n container with Docker
- Connects to PostgreSQL database (for workflows, credentials, execution history)
- Connects to Valkey/Redis (for queue management)
- Exposes n8n on port 5678
- Configures timezone (default: America/New_York)
- Makes environment variables persistent across reboots

The script uses Terraform's `templatefile()` to automatically inject:
- PostgreSQL connection details (host, port, database, user, password)
- PostgreSQL SSL configuration (required for DigitalOcean managed databases)
- Valkey connection details (host, port, password)
- Valkey TLS configuration (secure connections)
- Timezone configuration

### Database Security

DigitalOcean managed databases require SSL/TLS connections:
- **PostgreSQL**: Uses SSL with `DB_POSTGRESDB_SSL_ENABLED=true`
- **Valkey/Redis**: Uses TLS with `QUEUE_BULL_REDIS_TLS=true`
- **Certificate Validation**: Set to permissive mode (`SSL_REJECT_UNAUTHORIZED=false`) to accept DigitalOcean's certificates

### Queue Mode Configuration

The main instance is configured for optimal horizontal scaling:
- **EXECUTIONS_MODE=queue**: Uses queue system for distributing work
- **OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true**: Routes manual executions to workers
- **N8N_RUNNERS_ENABLED=true**: Enables task runners (JavaScript only by default)
- **N8N_ENCRYPTION_KEY**: Shared encryption key (same across all instances)
- **SKIP_MIGRATIONS**: Only main runs migrations, workers skip them
- **N8N_METRICS=false**: Disables metrics collection
- **N8N_DIAGNOSTICS_ENABLED=false**: Disables diagnostics

**Note**: `EXECUTIONS_PROCESS` is deprecated in newer n8n versions and has been removed. n8n automatically detects the role based on `EXECUTIONS_MODE=queue` and other settings.

### Encryption Key

**Critical**: All n8n instances (main + workers) **must use the same encryption key** to decrypt shared data.

- **Auto-generated**: If `n8n_encryption_key` is not set, Terraform generates a secure 32-character hex key
- **Manual**: You can set `n8n_encryption_key` in `variables.tfvars` (must be 32 hex characters)
- **Shared**: The same key is automatically injected into all instances
- **View**: Get the key with `terraform output -raw n8n_encryption_key` (sensitive)

### Database Migrations

- **Main instance**: Runs database migrations automatically on startup
- **Workers**: Skip migrations (`SKIP_MIGRATIONS=true`) to avoid conflicts
- **Why**: Only one instance should run migrations to prevent race conditions

### Task Runners

n8n uses task runners for executing workflows:
- **JavaScript Runner**: Built-in, works out of the box ✅
- **Python Runner**: Optional, requires Python 3 (warning can be safely ignored for production)

The Python task runner warning is informational only and doesn't affect functionality unless you're using Python nodes in your workflows.

You can customize this script or provide your own via the `main_user_data` variable.

### Worker Instances (`worker-init.sh`)

Each worker droplet automatically runs `worker-init.sh` on first boot, which:
- Sets `EXECUTIONS_MODE=queue` (connects workers to the queue system)
- Creates Docker volume for n8n data persistence
- Starts n8n container with Docker in worker mode
- Connects to PostgreSQL database (for reading workflow definitions)
- Connects to Valkey/Redis (for pulling jobs from queue)
- Configures timezone (default: America/New_York)
- Makes environment variables persistent across reboots

**Key differences from main instance:**
- `N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true` (disables web UI, runs as worker only)
- No web UI port exposed (workers don't need port 5678)
- No health check endpoint (workers are headless)
- Automatically connects to queue and processes jobs
- Redis connection verification included in init script

**Note**: `EXECUTIONS_PROCESS` is deprecated and has been removed. Workers are automatically detected when `N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true` is set.

The script uses Terraform's `templatefile()` to automatically inject:
- PostgreSQL connection details (host, port, database, user, password)
- PostgreSQL SSL configuration (required for DigitalOcean managed databases)
- Valkey connection details (host, port, password)
- Valkey TLS configuration (secure connections)
- Timezone configuration

You can customize this script or provide your own via the `worker_user_data` variable.

### Verify Docker Installation

After deployment, SSH into any droplet:

```bash
# SSH into main droplet
ssh root@$(terraform output -raw main_public_ip)

# Verify Docker
docker --version
# Output: Docker version 24.x.x, build...

# Verify Docker Compose
docker compose version
# Output: Docker Compose version v2.x.x
```

## Alternative: Custom Docker Installation

If you prefer a different Ubuntu version or want to control the Docker installation, you can use cloud-init. Update your `variables.tfvars`:

```hcl
# Use standard Ubuntu 22.04
main_image = "ubuntu-22-04-x64"
worker_image = "ubuntu-22-04-x64"

# Install Docker & Docker Compose via cloud-init
main_user_data = <<-EOF
  #!/bin/bash
  set -e
  
  # Update system
  apt-get update
  apt-get upgrade -y
  
  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  
  # Install Docker Compose plugin
  apt-get install -y docker-compose-plugin
  
  # Enable Docker
  systemctl enable docker
  systemctl start docker
  
  # Verify installation
  docker --version
  docker compose version
EOF

worker_user_data = <<-EOF
  #!/bin/bash
  set -e
  
  # Update system
  apt-get update
  apt-get upgrade -y
  
  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  
  # Install Docker Compose plugin
  apt-get install -y docker-compose-plugin
  
  # Enable Docker
  systemctl enable docker
  systemctl start docker
  
  # Verify installation
  docker --version
  docker compose version
EOF
```

## Configuration

### Main Droplet
- **Purpose**: n8n main instance (web UI, coordinator)
- **Default Size**: `s-1vcpu-2gb` (1 vCPU, 2GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)

### Worker Droplets
- **Purpose**: n8n workers (execute workflows)
- **Default Count**: 3
- **Default Size**: `s-1vcpu-1gb` (1 vCPU, 1GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)

### Databases
- **PostgreSQL**: Stores workflows, credentials, executions
- **Valkey (Redis)**: Queue management, caching, session storage

## Available Images

Common DigitalOcean image slugs:

| Image Slug | Description |
|------------|-------------|
| `docker-20-04` | Ubuntu 20.04 + Docker + Docker Compose ✅ **Recommended** |
| `ubuntu-22-04-x64` | Ubuntu 22.04 LTS (plain) |
| `ubuntu-24-04-x64` | Ubuntu 24.04 LTS (plain) |
| `docker-24-04` | Ubuntu 24.04 + Docker + Docker Compose |

You can list all available images:

```bash
doctl compute image list --public | grep -i docker
```

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
```

## Architecture

All resources are deployed within a **single DigitalOcean VPC** for secure private networking:

```
┌──────────────────────────────────────────────────────┐
│           DigitalOcean VPC (10.10.10.0/24)          │
│              Secure Private Network                  │
│                                                       │
│  ┌──────────────────┐                                │
│  │    n8n-main      │  ← Public IP + Private IP      │
│  │   (Coordinator)  │    Docker + Docker Compose     │
│  │   Port: 5678     │                                │
│  └─────────┬────────┘                                │
│            │ (private network)                       │
│  ┌─────────┴──────────────────────┐                  │
│  │                                 │                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │Worker 1  │  │Worker 2  │  │Worker 3  │           │
│  │(Private) │  │(Private) │  │(Private) │           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
│       │             │             │                  │
│       └─────────────┼─────────────┘                  │
│                     │ (private network)              │
│          ┌──────────┴──────────┐                     │
│          │                     │                     │
│     ┌────▼──────┐       ┌──────▼─────┐              │
│     │PostgreSQL │       │   Valkey   │              │
│     │ (Private) │       │ (Private)  │              │
│     │  Managed  │       │  Managed   │              │
│     └───────────┘       └────────────┘              │
│                                                       │
│  All communication within VPC is encrypted & private │
└──────────────────────────────────────────────────────┘
```

### Network Security

- ✅ **VPC Isolation**: All resources in a single private network
- ✅ **Private Database Access**: PostgreSQL & Valkey only accessible within VPC
- ✅ **Tag-based Firewall**: Only droplets with `n8n` tag can access databases
- ✅ **Encrypted Traffic**: All VPC traffic is encrypted by default
- ✅ **Public Access**: Only main droplet port 5678 is exposed externally

## Scaling

### Scale Workers Horizontally

```hcl
# Edit variables.tfvars
worker_count = 5  # Increase from 3 to 5

# Apply changes
terraform apply
```

### Scale Workers Vertically

```hcl
# Edit variables.tfvars
worker_size = "s-2vcpu-4gb"  # Upgrade to 2 vCPU, 4GB RAM

# Recreate workers
terraform apply
```

### Scale Main Instance

```hcl
# Edit variables.tfvars
main_size = "s-2vcpu-4gb"  # Upgrade to 2 vCPU, 4GB RAM

# Recreate main instance
terraform apply
```

## Estimated Costs

Based on DigitalOcean pricing (as of 2025):

| Resource | Size | Monthly Cost |
|----------|------|--------------|
| PostgreSQL | db-s-1vcpu-1gb | $15 |
| Valkey | db-s-1vcpu-1gb | $15 |
| Main Droplet | s-1vcpu-2gb | $12 |
| Worker (x3) | s-1vcpu-1gb | $6 × 3 = $18 |
| **Total** | | **~$60/month** |

## SSH Access

Add your SSH key fingerprint to `variables.tfvars`:

```hcl
ssh_keys = ["your:ssh:key:fingerprint:here"]
```

Get your SSH key fingerprint:
```bash
ssh-keygen -lf ~/.ssh/id_rsa.pub -E md5 | awk '{print $2}' | sed 's/MD5://g'
```

Or from DigitalOcean dashboard: https://cloud.digitalocean.com/account/security

## Viewing Initialization Logs

All initialization scripts save their output to log files for troubleshooting:

### Main Instance Logs

```bash
# SSH into main instance
ssh root@$(terraform output -raw main_public_ip)

# View initialization logs
cat /var/log/n8n-main-init.log

# Follow logs in real-time (if still initializing)
tail -f /var/log/n8n-main-init.log

# View n8n container logs
docker logs n8n -f
```

### Worker Instance Logs

```bash
# SSH into any worker
ssh root@<worker-ip>

# View initialization logs
cat /var/log/n8n-worker-init.log

# Follow logs in real-time (if still initializing)
tail -f /var/log/n8n-worker-init.log
```

### What the Logs Contain

- Script start/completion timestamps
- Docker readiness checks
- Volume creation
- n8n container startup
- Database connection details (host/port only, not passwords)
- Health check results
- Any errors encountered during setup

## Next Steps

1. Deploy the infrastructure with `terraform apply`
2. Wait for deployment to complete (~10-15 minutes for databases)
3. Access n8n at the URL shown: `terraform output n8n_url`
4. Check initialization logs if you encounter issues: `/var/log/n8n-main-init.log`
5. Complete the n8n setup wizard in your browser

## DNS Record Management

### If Domain Already Exists

If your domain already exists in DigitalOcean (like `yapago.app`):

1. **Set `domain_already_exists = true`** in `variables.tfvars`
2. **Clean up duplicate A records** manually in DigitalOcean dashboard:
   - Go to Networking → Domains → `yapago.app`
   - Delete duplicate A records pointing to old IPs
   - Keep only the A record pointing to your load balancer IP

3. **Import existing domain into Terraform** (optional):
   ```bash
   terraform import digitalocean_domain.n8n_domain[0] yapago.app
   ```

### DNS Record Behavior

- **Root domain** (`yapago.app`): Creates/updates A record with name `@`
- **Subdomain** (`n8n.yapago.app`): Creates/updates A record with name `n8n`
- Terraform will manage the A record pointing to the load balancer IP

## Cleanup

```bash
terraform destroy
```

## Support

For issues or questions:
- DigitalOcean Documentation: https://docs.digitalocean.com
- n8n Documentation: https://docs.n8n.io
- Terraform DigitalOcean Provider: https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs
