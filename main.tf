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

# Encryption key is provided via variable n8n_encryption_key
# If not provided, it will be generated in the init script
# All instances (main + workers) must use the same key

# VPC for private networking between droplets and databases
resource "digitalocean_vpc" "n8n_vpc" {
  name     = "n8n-vpc"
  region   = var.region
}

# PostgreSQL Database Cluster
resource "digitalocean_database_cluster" "postgres" {
  name       = var.cluster_name
  engine     = "pg"
  version    = var.postgres_version
  size       = var.db_size
  region     = var.region
  node_count = var.node_count

  # Add databases to the VPC for private networking
  private_network_uuid = digitalocean_vpc.n8n_vpc.id

  tags = var.tags

  depends_on = [digitalocean_vpc.n8n_vpc]
}

# Database User
resource "digitalocean_database_user" "postgres_user" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = var.database_user
}

# Firewall rule to allow connections from specific sources and VPC
resource "digitalocean_database_firewall" "postgres_firewall" {
  cluster_id = digitalocean_database_cluster.postgres.id

  # Allow connections from the VPC (for main and worker droplets)
  rule {
    type  = "tag"
    value = "n8n"
  }

  # Allow additional custom sources if specified
  dynamic "rule" {
    for_each = var.allowed_sources
    content {
      type  = rule.value.type
      value = rule.value.value
    }
  }

  depends_on = [digitalocean_vpc.n8n_vpc]
}

# Valkey (Redis-compatible) Database Cluster
resource "digitalocean_database_cluster" "valkey" {
  name       = var.valkey_cluster_name
  engine     = "valkey"
  version    = var.valkey_version
  size       = var.valkey_size
  region     = var.valkey_region
  node_count = var.valkey_node_count

  # Add databases to the VPC for private networking
  private_network_uuid = digitalocean_vpc.n8n_vpc.id

  tags = var.valkey_tags

  depends_on = [digitalocean_vpc.n8n_vpc]
}

# Firewall rule to allow connections from specific sources and VPC for Valkey
resource "digitalocean_database_firewall" "valkey_firewall" {
  cluster_id = digitalocean_database_cluster.valkey.id

  # Allow connections from the VPC (for main and worker droplets)
  rule {
    type  = "tag"
    value = "n8n"
  }

  # Allow additional custom sources if specified
  dynamic "rule" {
    for_each = var.valkey_allowed_sources
    content {
      type  = rule.value.type
      value = rule.value.value
    }
  }

  depends_on = [digitalocean_vpc.n8n_vpc]
}

# CA Certificate for PostgreSQL
data "digitalocean_database_ca" "postgres_ca" {
  cluster_id = digitalocean_database_cluster.postgres.id
}

# CA Certificate for Valkey
data "digitalocean_database_ca" "valkey_ca" {
  cluster_id = digitalocean_database_cluster.valkey.id
}

# Main Droplet
resource "digitalocean_droplet" "main" {
  name   = var.main_name
  size   = var.main_size
  image  = var.main_image
  region = var.main_region
  tags   = var.main_tags

  ssh_keys = var.ssh_keys
  # Use custom user_data if provided, otherwise use the init script with database credentials
  user_data = var.main_user_data != "" ? var.main_user_data : templatefile("${path.module}/main-init.sh", {
    db_host         = digitalocean_database_cluster.postgres.private_host
    db_port         = digitalocean_database_cluster.postgres.port
    db_name         = digitalocean_database_cluster.postgres.database
    db_user         = digitalocean_database_cluster.postgres.user
    db_password     = digitalocean_database_cluster.postgres.password
    valkey_host     = digitalocean_database_cluster.valkey.private_host
    valkey_port     = digitalocean_database_cluster.valkey.port
    valkey_password = digitalocean_database_cluster.valkey.password
    timezone        = var.n8n_timezone
    encryption_key  = var.n8n_encryption_key
  })

  # Enable monitoring
  monitoring = true
  
  # Enable private networking
  vpc_uuid = digitalocean_vpc.n8n_vpc.id

  # Wait for databases to be ready before creating droplet
  depends_on = [
    digitalocean_database_cluster.postgres,
    digitalocean_database_cluster.valkey,
    digitalocean_vpc.n8n_vpc
  ]
}

# Worker Droplets
resource "digitalocean_droplet" "workers" {
  count  = var.worker_count
  name   = "${var.worker_name_prefix}-${count.index + 1}"
  size   = var.worker_size
  image  = var.worker_image
  region = var.worker_region
  tags   = var.worker_tags

  ssh_keys = var.ssh_keys
  # Use custom user_data if provided, otherwise use the worker init script with database credentials
  user_data = var.worker_user_data != "" ? var.worker_user_data : templatefile("${path.module}/worker-init.sh", {
    db_host         = digitalocean_database_cluster.postgres.private_host
    db_port         = digitalocean_database_cluster.postgres.port
    db_name         = digitalocean_database_cluster.postgres.database
    db_user         = digitalocean_database_cluster.postgres.user
    db_password     = digitalocean_database_cluster.postgres.password
    valkey_host     = digitalocean_database_cluster.valkey.private_host
    valkey_port     = digitalocean_database_cluster.valkey.port
    valkey_password = digitalocean_database_cluster.valkey.password
    timezone        = var.n8n_timezone
    encryption_key  = var.n8n_encryption_key
  })

  # Enable monitoring and backups (optional)
  monitoring = true
  
  # Enable private networking
  vpc_uuid = digitalocean_vpc.n8n_vpc.id

  # Wait for databases to be ready before creating droplets
  depends_on = [
    digitalocean_database_cluster.postgres,
    digitalocean_database_cluster.valkey,
    digitalocean_vpc.n8n_vpc
  ]
}
