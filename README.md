# 🤖 Production Grade Horizontal n8n on DigitalOcean

Deploys production grade horizontal n8n on DigitalOcean using OpenTofu. Creates PostgreSQL and Valkey database clusters, main droplet, worker droplets, VPC, and optionally a load balancer with DNS.

![Architecture Diagram](https://raw.githubusercontent.com/starthubhq/n8n-horizontal-do/8fadd85e2c7c01181b7a7d4c82693c691d9b1dfe/diagram/ee.png)

## Usage

The module expects a JSON array of values in the following order:

```json
[
  "your-digitalocean-api-token",
  "nyc1",
  "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99",
  "3",
  "n8n.example.com",
  "your-32-char-hex-encryption-key"
]
```

### Parameters (in order)

1. `do_token` (string, required): DigitalOcean API token
2. `region` (string, optional): DigitalOcean region (e.g., "nyc1", "sfo3", "ams3"). Defaults to "nyc1" if not provided
3. `ssh_keys` (string, optional): Comma-separated list of SSH key fingerprints to add to droplets. Defaults to empty string if not provided
4. `worker_count` (string, optional): Number of worker droplets to create. Defaults to "3" if not provided
5. `domain_name` (string, optional): Domain name for n8n (e.g., "n8n.example.com"). Leave empty to skip DNS and load balancer setup. Defaults to empty string if not provided
6. `n8n_encryption_key` (string, optional): Encryption key for n8n (must be 32 hex characters). If not provided, will be auto-generated

### Additional Variables via Environment

All variables from `variables.tf` can also be provided via environment variables. The Docker container will automatically detect and use any environment variables that match variable names.

**Example:**
```bash
export CLUSTER_NAME="my-cluster"
export POSTGRES_VERSION="16"
export WORKER_COUNT="5"
export TAGS='["production", "n8n"]'

echo '["token", "nyc1", "", "3", "", ""]' | docker run -i -e CLUSTER_NAME -e POSTGRES_VERSION -e WORKER_COUNT -e TAGS n8n-horizontal-do
```

**Supported environment variable formats:**
- Original name: `cluster_name`, `postgres_version`, etc.
- Uppercase: `CLUSTER_NAME`, `POSTGRES_VERSION`, etc.
- Uppercase with underscores: `CLUSTER_NAME` (for `cluster-name`)

**All variables from `variables.tf` are supported.** See `variables.tfvars` or `.tfvars.example` for the complete list of available variables.

## Output

The module outputs the OpenTofu state file as a JSON array to stdout after the infrastructure is deployed. The state file contains all the information about the created DigitalOcean resources.

Example output:
```json
[{
  "version": 4,
  "terraform_version": "1.8.2",
  "serial": 1,
  "lineage": "...",
  "outputs": {
    "n8n_url": {
      "value": "http://123.45.67.89:5678",
      "type": "string"
    },
    "main_public_ip": {
      "value": "123.45.67.89",
      "type": "string"
    },
    "database_host": {
      "value": "db-postgres-cluster-do-user-123456-0.db.ondigitalocean.com",
      "type": "string"
    },
    "valkey_host": {
      "value": "db-valkey-cluster-do-user-123456-0.db.ondigitalocean.com",
      "type": "string"
    },
    "worker_public_ips": {
      "value": ["123.45.67.90", "123.45.67.91", "123.45.67.92"],
      "type": "list(string)"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "digitalocean_database_cluster",
      "name": "postgres",
      "provider": "provider[\"registry.terraform.io/digitalocean/digitalocean\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "id": "...",
            "name": "postgres-cluster",
            "region": "nyc1",
            ...
          }
        }
      ]
    }
  ]
}]
```

## Deployment Process

The module will:
1. Create a VPC for secure private networking
2. Create PostgreSQL database cluster (managed database)
3. Create Valkey (Redis-compatible) database cluster (managed database)
4. Create main droplet with n8n coordinator/web UI
5. Create worker droplets for production grade horizontal n8n
6. Configure private networking between all resources
7. Optionally create load balancer and DNS records (if domain_name is provided)
8. Initialize n8n on all droplets with Docker
9. Refresh the OpenTofu state to ensure it's up to date
10. Output the complete state file to stdout

## Build

```bash
# Build the Docker image
docker build -t n8n-horizontal-do .

# Save and package
docker save -o n8n-horizontal-do.tar n8n-horizontal-do
zip -9 artifact.zip n8n-horizontal-do.tar
rm n8n-horizontal-do.tar
```

## Test

```bash
# Full example with all variables:
echo '[
  "your-token",
  "nyc1",
  "aa:bb:cc:dd:ee:ff",
  "3",
  "n8n.example.com",
  "",
  "my-cluster",
  "16",
  "db-s-1vcpu-1gb",
  "1",
  "doadmin",
  "[\"production\", \"n8n\"]",
  "sunday",
  "02",
  "[{\"type\": \"tag\", \"value\": \"n8n\"}]",
  "valkey-cluster",
  "8",
  "db-s-1vcpu-1gb",
  "nyc1",
  "1",
  "doadmin",
  "[\"production\", \"valkey\"]",
  "[]",
  "n8n-worker",
  "s-1vcpu-1gb",
  "docker-20-04",
  "nyc1",
  "[\"n8n\", \"worker\"]",
  "",
  "n8n-main",
  "s-1vcpu-2gb",
  "docker-20-04",
  "nyc1",
  "[\"n8n\", \"main\"]",
  "",
  "America/New_York",
  "n8n-lb",
  "lb-small",
  "nyc1",
  "",
  "",
  "true"
]' | docker run -i n8n-horizontal-do
```

## Features

- ✅ Uses OpenTofu for infrastructure provisioning
- ✅ Creates managed PostgreSQL and Valkey database clusters
- ✅ Deploys production grade horizontal n8n
- ✅ Configures VPC for secure private networking
- ✅ Automatically initializes n8n on all droplets with Docker
- ✅ Supports optional load balancer and DNS setup
- ✅ Auto-generates encryption keys if not provided
- ✅ Outputs complete state file to stdout
- ✅ Idempotent operations (can be run multiple times safely)
- ✅ Handles errors and deployment scenarios

## 📦 Tech Stack

- **DigitalOcean** for cloud infrastructure
- **OpenTofu** for infrastructure provisioning
- **PostgreSQL** (managed database) for n8n data storage
- **Valkey** (Redis-compatible, managed database) for queue management
- **Docker** for containerized n8n deployment
- **n8n** workflow automation platform