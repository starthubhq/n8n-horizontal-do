#!/bin/bash
set -euo pipefail

# Read entire JSON payload from stdin
INPUT="$(cat || true)"

# Extract parameters from stdin as array of values: ["do_token", "region", "ssh_keys", "worker_count", "domain_name", "n8n_encryption_key"]
# Secrets from env first; otherwise from stdin array by index
DO_TOKEN="${do_token:-}"
if [ -z "${DO_TOKEN}" ]; then
  # Extract first element (index 0) from array
  DO_TOKEN="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[0] // empty else . // empty end)')"
fi

# Extract values by index: [0]=do_token, [1]=region, [2]=ssh_keys, [3]=worker_count, [4]=domain_name, [5]=n8n_encryption_key
REGION="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[1] // "nyc1" else "nyc1" end)')"
SSH_KEYS="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[2] // "" else "" end)')"
WORKER_COUNT="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[3] // "3" else "3" end)')"
DOMAIN_NAME="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[4] // "" else "" end)')"
N8N_ENCRYPTION_KEY="$(printf '%s' "$INPUT" | jq -r '(if type == "array" then .[5] // "" else "" end)')"

# Handle empty/null values with defaults
if [ -z "${REGION:-}" ] || [ "${REGION}" = "null" ]; then
  REGION="nyc1"
fi

if [ -z "${WORKER_COUNT:-}" ] || [ "${WORKER_COUNT}" = "null" ]; then
  WORKER_COUNT="3"
fi

if [ -z "${SSH_KEYS:-}" ] || [ "${SSH_KEYS}" = "null" ]; then
  SSH_KEYS=""
fi

if [ -z "${DOMAIN_NAME:-}" ] || [ "${DOMAIN_NAME}" = "null" ]; then
  DOMAIN_NAME=""
fi

if [ -z "${N8N_ENCRYPTION_KEY:-}" ] || [ "${N8N_ENCRYPTION_KEY}" = "null" ]; then
  N8N_ENCRYPTION_KEY=""
fi

# Validate required parameters (after applying defaults)
[ -n "${DO_TOKEN:-}" ] || { echo "Error: do_token missing" >&2; exit 1; }

echo "🚀 Deploying n8n with horizontal scaling on DigitalOcean..." >&2

# Create temporary directory for Terraform files
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Copy Terraform files from /app
if [ -f "/app/main.tf" ]; then
  cp /app/main.tf .
else
  echo "❌ Error: main.tf not found in /app" >&2
  exit 1
fi

if [ -f "/app/variables.tf" ]; then
  cp /app/variables.tf .
fi

if [ -f "/app/outputs.tf" ]; then
  cp /app/outputs.tf .
fi

if [ -f "/app/main-init.sh" ]; then
  cp /app/main-init.sh .
fi

if [ -f "/app/worker-init.sh" ]; then
  cp /app/worker-init.sh .
fi

# Parse SSH keys from comma-separated string to Terraform list format
# Terraform accepts JSON arrays in tfvars files
SSH_KEYS_LIST="[]"
if [ -n "${SSH_KEYS}" ]; then
  # Convert comma-separated string to JSON array, trimming whitespace
  SSH_KEYS_LIST=$(echo "$SSH_KEYS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R -s 'split("\n") | map(select(length > 0))')
fi

# Create terraform.tfvars file
cat > terraform.tfvars <<EOF
do_token = "${DO_TOKEN}"
region = "${REGION}"
valkey_region = "${REGION}"
main_region = "${REGION}"
worker_region = "${REGION}"
load_balancer_region = "${REGION}"
worker_count = ${WORKER_COUNT}
domain_name = "${DOMAIN_NAME}"
EOF

# Add SSH keys if provided
if [ -n "${SSH_KEYS}" ] && [ "${SSH_KEYS_LIST}" != "[]" ]; then
  echo "ssh_keys = ${SSH_KEYS_LIST}" >> terraform.tfvars
fi

# Add encryption key if provided
if [ -n "${N8N_ENCRYPTION_KEY}" ]; then
  echo "n8n_encryption_key = \"${N8N_ENCRYPTION_KEY}\"" >> terraform.tfvars
fi

echo "✅ terraform.tfvars generated:" >&2
# Don't print sensitive values
sed 's/do_token = .*/do_token = "***"/' terraform.tfvars | sed 's/n8n_encryption_key = .*/n8n_encryption_key = "***"/' >&2

# Initialize Terraform
echo "📦 Initializing Terraform..." >&2
terraform init -input=false >&2

# Apply the configuration
echo "⚙️  Applying Terraform configuration..." >&2
terraform apply -auto-approve -input=false >&2

# Refresh the state to ensure it's up to date
echo "🔄 Refreshing Terraform state..." >&2
terraform refresh -input=false >&2

# Output the state file to stdout as a JSON array
echo "📄 Outputting state file..." >&2
STATE_JSON=$(terraform state pull)
# Wrap the state file JSON in an array using jq to ensure valid JSON
echo "$STATE_JSON" | jq -s '.'

# Cleanup
rm -rf "$TEMP_DIR"

