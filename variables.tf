variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the database cluster"
  type        = string
  default     = "postgres-cluster"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "db_size" {
  description = "Database size slug (e.g., db-s-1vcpu-1gb, db-s-2vcpu-4gb)"
  type        = string
  default     = "db-s-1vcpu-1gb"
}

variable "region" {
  description = "DigitalOcean region (e.g., nyc1, sfo3, ams3)"
  type        = string
  default     = "nyc1"
}

variable "node_count" {
  description = "Number of nodes in the database cluster"
  type        = number
  default     = 1
}

variable "database_user" {
  description = "Name of the database user"
  type        = string
  default     = "doadmin"
}

variable "tags" {
  description = "Tags to apply to the database cluster"
  type        = list(string)
  default     = []
}

variable "maintenance_day" {
  description = "Day of the week for maintenance (monday, tuesday, etc.)"
  type        = string
  default     = "sunday"
}

variable "maintenance_hour" {
  description = "Hour of the day for maintenance (00-23)"
  type        = string
  default     = "02"
}

variable "allowed_sources" {
  description = "List of firewall rules to allow connections from specific sources"
  type = list(object({
    type  = string
    value = string
  }))
  default = []
}

# Valkey (Redis) Database Variables
variable "valkey_cluster_name" {
  description = "Name of the Valkey database cluster"
  type        = string
  default     = "valkey-cluster"
}

variable "valkey_version" {
  description = "Redis/Valkey version"
  type        = string
  default     = "8"
}

variable "valkey_size" {
  description = "Valkey database size slug (e.g., db-s-1vcpu-1gb, db-s-2vcpu-4gb)"
  type        = string
  default     = "db-s-1vcpu-1gb"
}

variable "valkey_region" {
  description = "DigitalOcean region for Valkey cluster (e.g., nyc1, sfo3, ams3)"
  type        = string
  default     = "nyc1"
}

variable "valkey_node_count" {
  description = "Number of nodes in the Valkey database cluster"
  type        = number
  default     = 1
}

variable "valkey_user" {
  description = "Name of the Valkey database user"
  type        = string
  default     = "doadmin"
}

variable "valkey_tags" {
  description = "Tags to apply to the Valkey database cluster"
  type        = list(string)
  default     = []
}

variable "valkey_allowed_sources" {
  description = "List of firewall rules to allow connections from specific sources for Valkey"
  type = list(object({
    type  = string
    value = string
  }))
  default = []
}

# Worker Droplets Configuration
variable "worker_count" {
  description = "Number of worker droplets to create"
  type        = number
  default     = 3
}

variable "worker_name_prefix" {
  description = "Prefix for worker droplet names (will be followed by index number)"
  type        = string
  default     = "n8n-worker"
}

variable "worker_size" {
  description = "Droplet size for workers (e.g., s-1vcpu-1gb, s-2vcpu-2gb)"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "worker_image" {
  description = "Droplet image/OS for workers (use 'docker-20-04' for Docker pre-installed)"
  type        = string
  default     = "docker-20-04"
}

variable "worker_region" {
  description = "DigitalOcean region for worker droplets"
  type        = string
  default     = "nyc1"
}

variable "worker_tags" {
  description = "Tags to apply to worker droplets"
  type        = list(string)
  default     = ["n8n", "worker"]
}

variable "ssh_keys" {
  description = "List of SSH key IDs or fingerprints to add to worker droplets"
  type        = list(string)
  default     = []
}

variable "worker_user_data" {
  description = "Optional cloud-init user data script for worker initialization"
  type        = string
  default     = ""
}

# Main Droplet Configuration
variable "main_name" {
  description = "Name for the main droplet"
  type        = string
  default     = "n8n-main"
}

variable "main_size" {
  description = "Droplet size for main instance (e.g., s-1vcpu-1gb, s-2vcpu-2gb)"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "main_image" {
  description = "Droplet image/OS for main instance (use 'docker-20-04' for Docker pre-installed)"
  type        = string
  default     = "docker-20-04"
}

variable "main_region" {
  description = "DigitalOcean region for main droplet"
  type        = string
  default     = "nyc1"
}

variable "main_tags" {
  description = "Tags to apply to main droplet"
  type        = list(string)
  default     = ["n8n", "main"]
}

variable "main_user_data" {
  description = "Optional cloud-init user data script for main instance initialization"
  type        = string
  default     = ""
}

variable "n8n_timezone" {
  description = "Timezone for n8n (e.g., America/New_York, Europe/London, UTC)"
  type        = string
  default     = "America/New_York"
}

variable "n8n_encryption_key" {
  description = "Encryption key for n8n (must be the same across all instances). If not provided, will be auto-generated. Must be 32 characters long."
  type        = string
  default     = ""
  sensitive   = true
}

# Load Balancer and DNS Configuration
variable "domain_name" {
  description = "Domain name for n8n (e.g., n8n.example.com). Leave empty to skip DNS and load balancer setup."
  type        = string
  default     = ""
}

variable "load_balancer_name" {
  description = "Name for the load balancer"
  type        = string
  default     = "n8n-lb"
}

variable "load_balancer_size" {
  description = "Size of the load balancer (lb-small, lb-medium, lb-large)"
  type        = string
  default     = "lb-small"
}

variable "load_balancer_region" {
  description = "Region for the load balancer (should match main droplet region)"
  type        = string
  default     = "nyc1"
}

variable "ssl_certificate_name" {
  description = "DigitalOcean certificate name for SSL termination. If not provided and domain_name is set, a Let's Encrypt certificate will be created automatically."
  type        = string
  default     = ""
}

variable "dns_domain" {
  description = "Base domain name for DNS (e.g., 'example.com'). If not provided, will be extracted from domain_name. Required if domain_name is a subdomain."
  type        = string
  default     = ""
}

variable "create_dns_record" {
  description = "Whether to create DNS A record pointing to the load balancer"
  type        = bool
  default     = true
}

