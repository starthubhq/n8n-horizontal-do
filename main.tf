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

# Local values for DNS domain extraction (must be before resources that use them)
locals {
  # Extract base domain from domain_name or use provided dns_domain
  base_domain = var.dns_domain != "" ? var.dns_domain : (
    length(split(".", var.domain_name)) >= 2 ? join(".", slice(split(".", var.domain_name), length(split(".", var.domain_name)) - 2, length(split(".", var.domain_name)))) : var.domain_name
  )
  # Extract subdomain (everything before base domain)
  subdomain = var.dns_domain != "" ? replace(var.domain_name, ".${var.dns_domain}", "") : (
    length(split(".", var.domain_name)) > 2 ? join(".", slice(split(".", var.domain_name), 0, length(split(".", var.domain_name)) - 2)) : "@"
  )
}

# Load Balancer with SSL Termination
resource "digitalocean_loadbalancer" "n8n_lb" {
  count  = var.domain_name != "" ? 1 : 0
  name   = var.load_balancer_name
  region = var.load_balancer_region
  size   = var.load_balancer_size

  # Forward HTTPS (443) to main droplet port 5678
  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"
    target_port    = 5678
    target_protocol = "http"

    # SSL certificate for HTTPS termination
    # Use provided certificate name, or auto-created Let's Encrypt certificate
    certificate_name = var.ssl_certificate_name != "" ? var.ssl_certificate_name : digitalocean_certificate.n8n_cert[0].name
  }

  # Health check
  healthcheck {
    port     = 5678
    protocol = "http"
    path     = "/healthz"
    check_interval_seconds = 10
    response_timeout_seconds = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }

  # Sticky sessions for n8n
  sticky_sessions {
    type = "cookies"
    cookie_name = "DO_LB"
    cookie_ttl_seconds = 300
  }

  # Attach main droplet
  droplet_ids = [digitalocean_droplet.main.id]

  # VPC configuration
  vpc_uuid = digitalocean_vpc.n8n_vpc.id

  depends_on = [
    digitalocean_droplet.main,
    digitalocean_certificate.n8n_cert
  ]
}

# Domain resource - register domain in DigitalOcean DNS (required for Let's Encrypt)
# This creates the domain if it doesn't exist, or uses it if it already exists
# Use main droplet IP as placeholder - will be updated by DNS record to point to load balancer
resource "digitalocean_domain" "n8n_domain" {
  count = var.domain_name != "" && var.create_dns_record ? 1 : 0
  name  = local.base_domain
  # Use main droplet IP as placeholder (required by DigitalOcean domain resource)
  # The actual A record will point to the load balancer
  ip_address = digitalocean_droplet.main.ipv4_address

  depends_on = [digitalocean_droplet.main]
}

# SSL Certificate (Let's Encrypt) - only if domain is provided and no cert name specified
resource "digitalocean_certificate" "n8n_cert" {
  count = var.domain_name != "" && var.ssl_certificate_name == "" ? 1 : 0
  name  = "${replace(var.domain_name, ".", "-")}-cert"
  type  = "lets_encrypt"
  domains = [var.domain_name]

  depends_on = [digitalocean_domain.n8n_domain]

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Record pointing to Load Balancer
# If domain_name is a subdomain, create A record for subdomain
# If domain_name is root domain, the domain resource already created the A record
resource "digitalocean_record" "n8n_dns" {
  count  = var.domain_name != "" && var.create_dns_record && local.subdomain != "@" ? 1 : 0
  domain = local.base_domain
  type   = "A"
  name   = local.subdomain
  value  = digitalocean_loadbalancer.n8n_lb[0].ip
  ttl    = 3600

  depends_on = [
    digitalocean_loadbalancer.n8n_lb,
    digitalocean_domain.n8n_domain
  ]
}

# Update domain's root A record to point to load balancer if domain_name is root domain
resource "digitalocean_record" "n8n_dns_root" {
  count  = var.domain_name != "" && var.create_dns_record && local.subdomain == "@" ? 1 : 0
  domain = local.base_domain
  type   = "A"
  name   = "@"
  value  = digitalocean_loadbalancer.n8n_lb[0].ip
  ttl    = 3600

  depends_on = [
    digitalocean_loadbalancer.n8n_lb,
    digitalocean_domain.n8n_domain
  ]
}
