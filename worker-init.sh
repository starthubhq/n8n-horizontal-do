#!/bin/bash
set -e

# Log file location
LOG_FILE="/var/log/n8n-worker-init.log"

# Redirect all output to log file while also showing on console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================"
echo "n8n Worker Instance Initialization Script"
echo "Started at: $(date)"
echo "Log file: $LOG_FILE"
echo "================================================"

# Set n8n execution mode to queue
# This tells n8n workers to connect to the queue system (Redis/Valkey)
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
echo "Setting up n8n worker with Docker"
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
GENERIC_TIMEZONE="${timezone}"
N8N_ENCRYPTION_KEY="${encryption_key}"

if [ -z "$N8N_ENCRYPTION_KEY" ]; then
  echo "ERROR: N8N_ENCRYPTION_KEY is required for workers!"
  echo "Workers must use the same encryption key as the main instance."
  exit 1
fi

echo "Starting n8n worker container..."
docker run -d \
  --name n8n \
  --restart unless-stopped \
  -e GENERIC_TIMEZONE="$GENERIC_TIMEZONE" \
  -e TZ="$GENERIC_TIMEZONE" \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
  -e SKIP_MIGRATIONS=true \
  -e EXECUTIONS_MODE=queue \
  -e N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true \
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
  -e QUEUE_BULL_REDIS_TLS=true \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n worker

echo "✓ n8n worker container started"

# Wait for n8n worker to be ready (check container is running)
echo "Waiting for n8n worker to be ready..."
sleep 10
until docker ps | grep -q "n8n"; do
  echo "n8n worker container is not running yet, waiting..."
  sleep 5
done
echo "✓ n8n worker container is running"

# Verify Redis/Valkey connection
echo "Verifying Redis/Valkey connection..."
sleep 5
if docker logs n8n 2>&1 | grep -qi -E "(redis|queue|bull|connected)"; then
  echo "✓ Redis connection messages found in logs"
else
  echo "⚠ WARNING: No Redis connection messages found in logs"
  echo "Checking recent logs:"
  docker logs n8n --tail 20
fi

# Check for queue worker initialization
echo "Checking for queue worker initialization..."
if docker logs n8n 2>&1 | grep -qi -E "(worker|listening|processing|queue)"; then
  echo "✓ Queue worker initialization messages found"
else
  echo "⚠ WARNING: No queue worker messages found"
fi

echo "================================================"
echo "Worker instance initialization complete!"
echo "Completed at: $(date)"
echo "================================================"
echo "EXECUTIONS_MODE: queue"
echo "Web UI: DISABLED (worker mode)"
echo "Database: $DB_POSTGRESDB_HOST:$DB_POSTGRESDB_PORT"
echo "Queue: $QUEUE_BULL_REDIS_HOST:$QUEUE_BULL_REDIS_PORT"
echo "This worker is ready to process n8n workflows from the queue"
echo "================================================"
echo "Logs saved to: $LOG_FILE"
echo "View logs with: tail -f $LOG_FILE"
echo "View container logs with: docker logs n8n -f"
echo "================================================"

