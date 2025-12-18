# Architecture Overview

This document describes the architecture of the n8n horizontal scaling deployment on DigitalOcean.

## High-Level Architecture

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

## Components

### Main Droplet

- **Purpose**: n8n coordinator/web UI
- **Default Size**: `s-1vcpu-2gb` (1 vCPU, 2GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)
- **Public IP**: Yes (for web UI access)
- **Ports**: 5678 (n8n web interface)
- **Role**: 
  - Serves the web UI
  - Coordinates workflow execution
  - Runs database migrations
  - Manages the queue system

### Worker Droplets

- **Purpose**: Execute n8n workflows
- **Default Count**: 3
- **Default Size**: `s-1vcpu-1gb` (1 vCPU, 1GB RAM)
- **Image**: `docker-20-04` (Docker pre-installed)
- **Public IP**: Optional (can be private only)
- **Role**:
  - Pull jobs from the queue
  - Execute workflows
  - Report results back

### PostgreSQL Database

- **Purpose**: Store workflows, credentials, execution history
- **Type**: DigitalOcean Managed Database
- **Default Size**: `db-s-1vcpu-1gb`
- **Access**: Private (VPC only)
- **SSL**: Required (enforced by DigitalOcean)

### Valkey (Redis) Database

- **Purpose**: Queue management, caching, session storage
- **Type**: DigitalOcean Managed Database
- **Default Size**: `db-s-1vcpu-1gb`
- **Access**: Private (VPC only)
- **TLS**: Required (enforced by DigitalOcean)

### VPC (Virtual Private Cloud)

- **Purpose**: Secure private networking
- **IP Range**: `10.10.10.0/24` (configurable)
- **Benefits**:
  - All resources communicate privately
  - Databases not exposed to public internet
  - Encrypted traffic within VPC

## Network Security

- ✅ **VPC Isolation**: All resources in a single private network
- ✅ **Private Database Access**: PostgreSQL & Valkey only accessible within VPC
- ✅ **Tag-based Firewall**: Only droplets with `n8n` tag can access databases
- ✅ **Encrypted Traffic**: All VPC traffic is encrypted by default
- ✅ **Public Access**: Only main droplet port 5678 is exposed externally

## Data Flow

1. **User Access**: Browser → Main Droplet (port 5678)
2. **Workflow Creation**: Main Droplet → PostgreSQL (stores workflow)
3. **Execution Trigger**: Main Droplet → Valkey Queue (adds job)
4. **Worker Processing**: Worker → Valkey Queue (pulls job) → Executes → Reports back
5. **Result Storage**: Worker → PostgreSQL (stores execution history)

## Scaling

### Horizontal Scaling

Add or remove worker droplets based on workload:

```hcl
worker_count = 5  # Scale to 5 workers
```

### Vertical Scaling

Upgrade droplet sizes for more CPU/RAM:

```hcl
worker_size = "s-2vcpu-4gb"  # Upgrade workers
main_size = "s-2vcpu-4gb"    # Upgrade main
```

See [Infrastructure Details](infrastructure.md) for more information.

