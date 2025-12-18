# Infrastructure Details

Detailed information about the infrastructure components.

## Droplets

### Main Droplet

- **Purpose**: n8n coordinator/web UI
- **Default Size**: `s-1vcpu-2gb` (1 vCPU, 2GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)
- **Public IP**: Yes (for web UI access)
- **Ports**: 5678 (n8n web interface)

### Worker Droplets

- **Purpose**: Execute n8n workflows
- **Default Count**: 3
- **Default Size**: `s-1vcpu-1gb` (1 vCPU, 1GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)
- **Public IP**: Optional (can be private only)

## Databases

### PostgreSQL

- **Type**: DigitalOcean Managed Database
- **Default Size**: `db-s-1vcpu-1gb`
- **Access**: Private (VPC only)
- **SSL**: Required (enforced by DigitalOcean)

### Valkey (Redis)

- **Type**: DigitalOcean Managed Database
- **Default Size**: `db-s-1vcpu-1gb`
- **Access**: Private (VPC only)
- **TLS**: Required (enforced by DigitalOcean)

## Networking

### VPC

- **IP Range**: `10.10.10.0/24` (configurable)
- **Purpose**: Secure private networking
- **Benefits**:
  - All resources communicate privately
  - Databases not exposed to public internet
  - Encrypted traffic within VPC

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

