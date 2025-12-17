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
  description = "Droplet image/OS for workers"
  type        = string
  default     = "ubuntu-22-04-x64"
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

