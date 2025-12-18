#!/bin/bash
set -e

# Log file location
LOG_FILE="/var/log/n8n-main-init.log"

# Redirect all output to log file while also showing on console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================"
echo "n8n Main Instance Initialization Script"
echo "Started at: $(date)"
echo "Log file: $LOG_FILE"
echo "================================================"

# Set n8n execution mode to queue
# This tells n8n to use a queue system (Redis/Valkey) for distributed execution
echo "Setting EXECUTIONS_MODE=queue"
export EXECUTIONS_MODE=queue

# Make the environment variable persistent across reboots
# Add to /etc/environment
if ! grep -q "EXECUTIONS_MODE" /etc/environment; then
  echo "EXECUTIONS_MODE=queue" | sudo tee -a /etc/environment
  echo "✓ Added EXECUTIONS_MODE to /etc/environment"
else
  echo "✓ EXECUTIONS_MODE already in /etc/environment"
fi

# Also add to current user's profile
if ! grep -q "EXECUTIONS_MODE" ~/.bashrc; then
  echo 'export EXECUTIONS_MODE=queue' >> ~/.bashrc
  echo "✓ Added EXECUTIONS_MODE to ~/.bashrc"
else
  echo "✓ EXECUTIONS_MODE already in ~/.bashrc"
fi

echo "================================================"
echo "Opening firewall port for n8n"
echo "================================================"

# Open port 5678 for n8n
echo "Opening port 5678 for n8n..."
ufw allow 5678/tcp
echo "✓ Port 5678 opened for n8n"

echo "================================================"
echo "Setting up n8n with Docker"
echo "================================================"

# Wait for Docker to be ready
echo "Waiting for Docker to be ready..."
until docker info > /dev/null 2>&1; do
  echo "Docker is not ready yet, waiting..."
  sleep 2
done
echo "✓ Docker is ready"

# Create Docker volume for n8n data
echo "Creating Docker volume for n8n data..."
docker volume create n8n_data
echo "✓ Docker volume created"

# Database configuration (injected by Terraform)
DB_POSTGRESDB_HOST="${db_host}"
DB_POSTGRESDB_PORT="${db_port}"
DB_POSTGRESDB_DATABASE="${db_name}"
DB_POSTGRESDB_USER="${db_user}"
DB_POSTGRESDB_PASSWORD="${db_password}"

# Valkey/Redis configuration for queue mode
QUEUE_BULL_REDIS_HOST="${valkey_host}"
QUEUE_BULL_REDIS_PORT="${valkey_port}"
QUEUE_BULL_REDIS_PASSWORD="${valkey_password}"

# n8n configuration
N8N_PORT=5678
GENERIC_TIMEZONE="${timezone}"
N8N_ENCRYPTION_KEY="${encryption_key}"

# Generate encryption key if not provided via variable
if [ -z "$N8N_ENCRYPTION_KEY" ] || [ "$N8N_ENCRYPTION_KEY" = "" ]; then
  echo "WARNING: No encryption key provided via variable!"
  echo "Generating encryption key (you must use the same key for all instances)..."
  N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
  echo "Generated encryption key: $N8N_ENCRYPTION_KEY"
  echo "IMPORTANT: Save this key and set n8n_encryption_key in variables.tfvars for workers!"
fi

echo "Starting n8n container..."
docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p $N8N_PORT:5678 \
  -e GENERIC_TIMEZONE="$GENERIC_TIMEZONE" \
  -e TZ="$GENERIC_TIMEZONE" \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
  -e EXECUTIONS_MODE=queue \
  -e OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true \
  -e N8N_METRICS=false \
  -e N8N_DIAGNOSTICS_ENABLED=false \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_DATABASE="$DB_POSTGRESDB_DATABASE" \
  -e DB_POSTGRESDB_HOST="$DB_POSTGRESDB_HOST" \
  -e DB_POSTGRESDB_PORT="$DB_POSTGRESDB_PORT" \
  -e DB_POSTGRESDB_USER="$DB_POSTGRESDB_USER" \
  -e DB_POSTGRESDB_PASSWORD="$DB_POSTGRESDB_PASSWORD" \
  -e DB_POSTGRESDB_SSL_ENABLED=true \
  -e DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false \
  -e QUEUE_BULL_REDIS_HOST="$QUEUE_BULL_REDIS_HOST" \
  -e QUEUE_BULL_REDIS_PORT="$QUEUE_BULL_REDIS_PORT" \
  -e QUEUE_BULL_REDIS_PASSWORD="$QUEUE_BULL_REDIS_PASSWORD" \
  -e QUEUE_BULL_REDIS_DB=0 \
  -e N8N_SECURE_COOKIE=false \
  -e QUEUE_BULL_REDIS_TLS=true \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n

echo "✓ n8n container started"

# Wait for n8n to be ready
echo "Waiting for n8n to be ready..."
sleep 10
until curl -f http://localhost:$N8N_PORT/healthz > /dev/null 2>&1; do
  echo "n8n is not ready yet, waiting..."
  sleep 5
done

echo "================================================"
echo "Main instance initialization complete!"
echo "Completed at: $(date)"
echo "================================================"
echo "n8n is running on port $N8N_PORT"
echo "EXECUTIONS_MODE: queue"
echo "Database: $DB_POSTGRESDB_HOST:$DB_POSTGRESDB_PORT"
echo "Queue: $QUEUE_BULL_REDIS_HOST:$QUEUE_BULL_REDIS_PORT"
echo "================================================"
echo "Access n8n at: http://$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address):$N8N_PORT"
echo "================================================"
echo "Logs saved to: $LOG_FILE"
echo "View logs with: tail -f $LOG_FILE"
echo "================================================"

