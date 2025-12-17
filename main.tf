terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# PostgreSQL Database Cluster
resource "digitalocean_database_cluster" "postgres" {
  name       = var.cluster_name
  engine     = "pg"
  version    = var.postgres_version
  size       = var.db_size
  region     = var.region
  node_count = var.node_count

  tags = var.tags
}

# Database User
resource "digitalocean_database_user" "postgres_user" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = var.database_user
}

# Firewall rule to allow connections from specific sources
# Only create firewall resource if there are rules to add
resource "digitalocean_database_firewall" "postgres_firewall" {
  count      = length(var.allowed_sources) > 0 ? 1 : 0
  cluster_id = digitalocean_database_cluster.postgres.id

  dynamic "rule" {
    for_each = var.allowed_sources
    content {
      type  = rule.value.type
      value = rule.value.value
    }
  }
}

# Valkey (Redis-compatible) Database Cluster
resource "digitalocean_database_cluster" "valkey" {
  name       = var.valkey_cluster_name
  engine     = "valkey"
  version    = var.valkey_version
  size       = var.valkey_size
  region     = var.valkey_region
  node_count = var.valkey_node_count

  tags = var.valkey_tags
}

# Firewall rule to allow connections from specific sources for Valkey
# Only create firewall resource if there are rules to add
resource "digitalocean_database_firewall" "valkey_firewall" {
  count      = length(var.valkey_allowed_sources) > 0 ? 1 : 0
  cluster_id = digitalocean_database_cluster.valkey.id

  dynamic "rule" {
    for_each = var.valkey_allowed_sources
    content {
      type  = rule.value.type
      value = rule.value.value
    }
  }
}

# CA Certificate for PostgreSQL
data "digitalocean_database_ca" "postgres_ca" {
  cluster_id = digitalocean_database_cluster.postgres.id
}

# CA Certificate for Valkey
data "digitalocean_database_ca" "valkey_ca" {
  cluster_id = digitalocean_database_cluster.valkey.id
}

# VPC for private networking between workers and databases
resource "digitalocean_vpc" "n8n_vpc" {
  name     = "n8n-vpc"
  region   = var.region
}

# Worker Droplets
resource "digitalocean_droplet" "workers" {
  count  = var.worker_count
  name   = "${var.worker_name_prefix}-${count.index + 1}"
  size   = var.worker_size
  image  = var.worker_image
  region = var.worker_region
  tags   = var.worker_tags

  ssh_keys  = var.ssh_keys
  user_data = var.worker_user_data != "" ? var.worker_user_data : null

  # Enable monitoring and backups (optional)
  monitoring = true
  
  # Enable private networking
  vpc_uuid = digitalocean_vpc.n8n_vpc.id
}
