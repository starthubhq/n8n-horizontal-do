# Initialization Scripts

The deployment uses initialization scripts to automatically configure n8n on first boot.

## Main Instance Script (`main-init.sh`)

The main droplet automatically runs `main-init.sh` on first boot, which:

- Sets `EXECUTIONS_MODE=queue` (enables n8n queue mode for production grade horizontal n8n)
- Creates Docker volume for n8n data persistence
- Starts n8n container with Docker
- Connects to PostgreSQL database (for workflows, credentials, execution history)
- Connects to Valkey/Redis (for queue management)
- Exposes n8n on port 5678
- Configures timezone (default: America/New_York)
- Makes environment variables persistent across reboots

### Queue Mode Configuration

The main instance is configured for optimal production grade horizontal n8n:

- **EXECUTIONS_MODE=queue**: Uses queue system for distributing work
- **OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true**: Routes manual executions to workers
- **N8N_RUNNERS_ENABLED=true**: Enables task runners (JavaScript only by default)
- **N8N_ENCRYPTION_KEY**: Shared encryption key (same across all instances)
- **SKIP_MIGRATIONS**: Only main runs migrations, workers skip them

## Worker Instance Script (`worker-init.sh`)

Each worker droplet automatically runs `worker-init.sh` on first boot, which:

- Sets `EXECUTIONS_MODE=queue` (connects workers to the queue system)
- Creates Docker volume for n8n data persistence
- Starts n8n container with Docker in worker mode
- Connects to PostgreSQL database (for reading workflow definitions)
- Connects to Valkey/Redis (for pulling jobs from queue)
- Configures timezone (default: America/New_York)
- Makes environment variables persistent across reboots

### Key Differences from Main Instance

- `N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true` (disables web UI, runs as worker only)
- No web UI port exposed (workers don't need port 5678)
- No health check endpoint (workers are headless)
- Automatically connects to queue and processes jobs

## Customization

You can customize these scripts or provide your own via the `main_user_data` and `worker_user_data` variables in `variables.tfvars`.

