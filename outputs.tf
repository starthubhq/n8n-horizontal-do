output "database_cluster_id" {
  description = "The ID of the database cluster"
  value       = digitalocean_database_cluster.postgres.id
}

output "database_cluster_urn" {
  description = "The uniform resource name of the database cluster"
  value       = digitalocean_database_cluster.postgres.urn
}

output "database_name" {
  description = "The name of the default database (auto-created by DigitalOcean)"
  value       = digitalocean_database_cluster.postgres.database
}

output "database_user" {
  description = "The name of the database user"
  value       = digitalocean_database_user.postgres_user.name
}

output "database_host" {
  description = "The hostname of the database cluster"
  value       = digitalocean_database_cluster.postgres.host
}

output "database_port" {
  description = "The port of the database cluster"
  value       = digitalocean_database_cluster.postgres.port
}

output "database_uri" {
  description = "The full URI for connecting to the database"
  value       = digitalocean_database_cluster.postgres.private_uri
  sensitive   = true
}

output "database_connection_string" {
  description = "Connection string for the database"
  value       = "postgresql://${digitalocean_database_user.postgres_user.name}:${digitalocean_database_user.postgres_user.password}@${digitalocean_database_cluster.postgres.host}:${digitalocean_database_cluster.postgres.port}/${digitalocean_database_cluster.postgres.database}?sslmode=require"
  sensitive   = true
}

output "database_ca_certificate" {
  description = "CA certificate for PostgreSQL database SSL connections"
  value       = data.digitalocean_database_ca.postgres_ca.certificate
  sensitive   = true
}

# Valkey (Redis) Outputs
output "valkey_cluster_id" {
  description = "The ID of the Valkey database cluster"
  value       = digitalocean_database_cluster.valkey.id
}

output "valkey_cluster_urn" {
  description = "The uniform resource name of the Valkey database cluster"
  value       = digitalocean_database_cluster.valkey.urn
}

output "valkey_host" {
  description = "The hostname of the Valkey database cluster"
  value       = digitalocean_database_cluster.valkey.host
}

output "valkey_port" {
  description = "The port of the Valkey database cluster"
  value       = digitalocean_database_cluster.valkey.port
}

output "valkey_uri" {
  description = "The full URI for connecting to the Valkey database"
  value       = digitalocean_database_cluster.valkey.private_uri
  sensitive   = true
}

output "valkey_ca_certificate" {
  description = "CA certificate for Valkey database SSL connections"
  value       = data.digitalocean_database_ca.valkey_ca.certificate
  sensitive   = true
}

# Main Droplet Outputs
output "main_id" {
  description = "ID of the main droplet"
  value       = digitalocean_droplet.main.id
}

output "main_name" {
  description = "Name of the main droplet"
  value       = digitalocean_droplet.main.name
}

output "main_public_ip" {
  description = "Public IP address of the main droplet"
  value       = digitalocean_droplet.main.ipv4_address
}

output "n8n_url" {
  description = "URL to access n8n web interface"
  value       = "http://${digitalocean_droplet.main.ipv4_address}:5678"
}

output "n8n_encryption_key" {
  description = "Encryption key used by all n8n instances (save this securely!)"
  value       = var.n8n_encryption_key
  sensitive   = true
}

output "main_private_ip" {
  description = "Private IP address of the main droplet"
  value       = digitalocean_droplet.main.ipv4_address_private
}

# Worker Droplet Outputs
output "worker_ids" {
  description = "IDs of the worker droplets"
  value       = digitalocean_droplet.workers[*].id
}

output "worker_names" {
  description = "Names of the worker droplets"
  value       = digitalocean_droplet.workers[*].name
}

output "worker_public_ips" {
  description = "Public IP addresses of the worker droplets"
  value       = digitalocean_droplet.workers[*].ipv4_address
}

output "worker_private_ips" {
  description = "Private IP addresses of the worker droplets"
  value       = digitalocean_droplet.workers[*].ipv4_address_private
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = digitalocean_vpc.n8n_vpc.id
}

output "vpc_ip_range" {
  description = "IP range of the VPC"
  value       = digitalocean_vpc.n8n_vpc.ip_range
}

