#!/bin/bash
set -euo pipefail

# Read entire JSON payload from stdin
INPUT="$(cat || true)"

# Create temporary directory for OpenTofu files
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Copy OpenTofu files from /app
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

# Function to convert JSON value to HCL format
json_to_hcl() {
  local key="$1"
  local value="$2"
  
  # Check if value is null or empty
  if [ "$value" = "null" ] || [ -z "$value" ]; then
    return 1  # Skip null/empty values
  fi
  
  # Check if value is a JSON array
  if echo "$value" | jq -e '. | type == "array"' >/dev/null 2>&1; then
    # Check if it's an array of objects (for allowed_sources, valkey_allowed_sources)
    local first_elem=$(echo "$value" | jq -r '.[0] // empty')
    if echo "$first_elem" | jq -e '. | type == "object"' >/dev/null 2>&1; then
      # Array of objects - format as HCL list of objects
      echo "${key} = ["
      echo "$value" | jq -r '.[] | "  {\n    type = \"\(.type)\"\n    value = \"\(.value)\"\n  },"' | sed '$ s/,$//'
      echo "]"
    else
      # Simple array - format as HCL list
      local hcl_list=$(echo "$value" | jq -r 'map("\"\(.)\"") | join(", ")')
      echo "${key} = [${hcl_list}]"
    fi
  # Check if value is a JSON object
  elif echo "$value" | jq -e '. | type == "object"' >/dev/null 2>&1; then
    # Object - format as HCL object
    echo "${key} = {"
    echo "$value" | jq -r 'to_entries[] | "  \(.key) = \"\(.value)\""'
    echo "}"
  # Check if value is a boolean
  elif [ "$value" = "true" ] || [ "$value" = "false" ]; then
    echo "${key} = ${value}"
  # Check if value is a number
  elif echo "$value" | grep -qE '^-?[0-9]+(\.[0-9]+)?$'; then
    echo "${key} = ${value}"
  # Otherwise treat as string
  else
    # Escape quotes in string values
    local escaped_value=$(echo "$value" | sed 's/"/\\"/g')
    echo "${key} = \"${escaped_value}\""
  fi
}

# Check if input is a JSON array
INPUT_TYPE=$(echo "$INPUT" | jq -r 'type' 2>/dev/null || echo "unknown")

if [ "$INPUT_TYPE" != "array" ]; then
  echo "❌ Error: Input must be a JSON array" >&2
  exit 1
fi

# Define array index to variable name mapping (all 42 variables)
# Order matches the README test example
declare -A ARRAY_VARS=(
  [0]="do_token"
  [1]="region"
  [2]="ssh_keys"
  [3]="worker_count"
  [4]="domain_name"
  [5]="n8n_encryption_key"
  [6]="cluster_name"
  [7]="postgres_version"
  [8]="db_size"
  [9]="node_count"
  [10]="database_user"
  [11]="tags"
  [12]="maintenance_day"
  [13]="maintenance_hour"
  [14]="allowed_sources"
  [15]="valkey_cluster_name"
  [16]="valkey_version"
  [17]="valkey_size"
  [18]="valkey_region"
  [19]="valkey_node_count"
  [20]="valkey_user"
  [21]="valkey_tags"
  [22]="valkey_allowed_sources"
  [23]="worker_name_prefix"
  [24]="worker_size"
  [25]="worker_image"
  [26]="worker_region"
  [27]="worker_tags"
  [28]="worker_user_data"
  [29]="main_name"
  [30]="main_size"
  [31]="main_image"
  [32]="main_region"
  [33]="main_tags"
  [34]="main_user_data"
  [35]="n8n_timezone"
  [36]="load_balancer_name"
  [37]="load_balancer_size"
  [38]="load_balancer_region"
  [39]="ssl_certificate_name"
  [40]="dns_domain"
  [41]="create_dns_record"
)

# Extract all values from JSON array and store in associative array
declare -A VAR_VALUES
for idx in "${!ARRAY_VARS[@]}"; do
  var_name="${ARRAY_VARS[$idx]}"
  # Extract raw value from JSON array
  raw_value=$(echo "$INPUT" | jq -r ".[$idx] // empty")
  
  if [ -n "$raw_value" ] && [ "$raw_value" != "null" ] && [ "$raw_value" != "" ]; then
    # Check if the value is valid JSON (array or object)
    # This handles cases where JSON strings like "[\"production\", \"n8n\"]" are in the array
    if echo "$raw_value" | jq . >/dev/null 2>&1; then
      # Try to determine if it's an array or object
      json_type=$(echo "$raw_value" | jq -r 'type' 2>/dev/null || echo "")
      if [ "$json_type" = "array" ] || [ "$json_type" = "object" ]; then
        # Store as compact JSON
        VAR_VALUES["$var_name"]=$(echo "$raw_value" | jq -c .)
      else
        # It's a JSON primitive (string, number, bool), store as-is
        VAR_VALUES["$var_name"]="$raw_value"
      fi
    else
      # Not valid JSON, store as string
      VAR_VALUES["$var_name"]="$raw_value"
    fi
  fi
done

# Check for do_token in environment first, then in array
DO_TOKEN="${do_token:-}"
if [ -z "${DO_TOKEN}" ]; then
  DO_TOKEN="${VAR_VALUES[do_token]:-}"
fi

# Validate required parameters
[ -n "${DO_TOKEN:-}" ] || { echo "Error: do_token missing" >&2; exit 1; }

# Set defaults for backward compatibility
REGION="${VAR_VALUES[region]:-nyc1}"
[ "$REGION" = "null" ] && REGION="nyc1"
[ -z "$REGION" ] && REGION="nyc1"

WORKER_COUNT="${VAR_VALUES[worker_count]:-3}"
[ "$WORKER_COUNT" = "null" ] && WORKER_COUNT="3"
[ -z "$WORKER_COUNT" ] && WORKER_COUNT="3"

SSH_KEYS="${VAR_VALUES[ssh_keys]:-}"
[ "$SSH_KEYS" = "null" ] && SSH_KEYS=""

DOMAIN_NAME="${VAR_VALUES[domain_name]:-}"
[ "$DOMAIN_NAME" = "null" ] && DOMAIN_NAME=""

N8N_ENCRYPTION_KEY="${VAR_VALUES[n8n_encryption_key]:-}"
[ "$N8N_ENCRYPTION_KEY" = "null" ] && N8N_ENCRYPTION_KEY=""

# Parse SSH keys from comma-separated string to OpenTofu list format
SSH_KEYS_LIST="[]"
if [ -n "${SSH_KEYS}" ]; then
  SSH_KEYS_LIST=$(echo "$SSH_KEYS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R -s 'split("\n") | map(select(length > 0))')
fi

# Create terraform.tfvars file starting with required and common values
cat > terraform.tfvars <<EOF
do_token = "${DO_TOKEN}"
region = "${REGION}"
valkey_region = "${VAR_VALUES[valkey_region]:-${REGION}}"
main_region = "${VAR_VALUES[main_region]:-${REGION}}"
worker_region = "${VAR_VALUES[worker_region]:-${REGION}}"
load_balancer_region = "${VAR_VALUES[load_balancer_region]:-${REGION}}"
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

# Process all other variables from array (skip already processed ones)
for idx in "${!ARRAY_VARS[@]}"; do
  var_name="${ARRAY_VARS[$idx]}"
  value="${VAR_VALUES[$var_name]:-}"
  
  # Skip if empty/null or already processed
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    continue
  fi
  
  # Skip variables already added above
  case "$var_name" in
    do_token|region|valkey_region|main_region|worker_region|load_balancer_region|worker_count|domain_name|ssh_keys|n8n_encryption_key)
      continue
      ;;
  esac
  
  # Determine variable type and format accordingly
  # Check if value is boolean
  if [ "$value" = "true" ] || [ "$value" = "false" ]; then
    echo "${var_name} = ${value}" >> terraform.tfvars
  # Check if value is a number
  elif echo "$value" | grep -qE '^-?[0-9]+(\.[0-9]+)?$'; then
    echo "${var_name} = ${value}" >> terraform.tfvars
  # Try to parse as JSON (for arrays/objects)
  elif echo "$value" | jq . >/dev/null 2>&1; then
    # Value is valid JSON, use json_to_hcl
    json_to_hcl "$var_name" "$value" >> terraform.tfvars 2>/dev/null || {
      # If json_to_hcl fails, treat as simple string
      escaped_value=$(echo "$value" | sed 's/"/\\"/g')
      echo "${var_name} = \"${escaped_value}\"" >> terraform.tfvars
    }
  else
    # Treat as string
    escaped_value=$(echo "$value" | sed 's/"/\\"/g')
    echo "${var_name} = \"${escaped_value}\"" >> terraform.tfvars
  fi
done

# Also check environment variables as fallback (for variables not in array)
VAR_NAMES=(
  "cluster_name" "postgres_version" "db_size" "node_count" "database_user"
  "tags" "maintenance_day" "maintenance_hour" "allowed_sources"
  "valkey_cluster_name" "valkey_version" "valkey_size" "valkey_region"
  "valkey_node_count" "valkey_user" "valkey_tags" "valkey_allowed_sources"
  "worker_name_prefix" "worker_size" "worker_image" "worker_tags"
  "worker_user_data" "main_name" "main_size" "main_image" "main_tags"
  "main_user_data" "n8n_timezone"
  "load_balancer_name" "load_balancer_size" "ssl_certificate_name"
  "dns_domain" "create_dns_record"
)

# Function to get environment variable value (handles various naming conventions)
get_env_var() {
  local var_name="$1"
  local value=""
  
  # Try different naming conventions:
  # 1. Original name (e.g., cluster_name)
  value=$(printenv "$var_name" 2>/dev/null || echo "")
  
  # 2. Uppercase with underscores (e.g., CLUSTER_NAME)
  if [ -z "$value" ]; then
    local upper_var=$(echo "$var_name" | tr '[:lower:]' '[:upper:]')
    value=$(printenv "$upper_var" 2>/dev/null || echo "")
  fi
  
  # 3. Uppercase with dashes replaced by underscores (e.g., CLUSTER_NAME for cluster-name)
  if [ -z "$value" ]; then
    local upper_underscore=$(echo "$var_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    value=$(printenv "$upper_underscore" 2>/dev/null || echo "")
  fi
  
  echo "$value"
}

# Add variables from environment if they are set and not already in VAR_VALUES
for var_name in "${VAR_NAMES[@]}"; do
  # Skip if already processed from array
  [ -n "${VAR_VALUES[$var_name]:-}" ] && continue
  
  env_value=$(get_env_var "$var_name")
  
  if [ -n "$env_value" ] && [ "$env_value" != "null" ]; then
    # Try to parse as JSON first, if that fails treat as string
    if echo "$env_value" | jq . >/dev/null 2>&1; then
      # Value is valid JSON, use json_to_hcl
      json_to_hcl "$var_name" "$env_value" >> terraform.tfvars 2>/dev/null || {
        # If json_to_hcl fails, treat as simple string
        escaped_value=$(echo "$env_value" | sed 's/"/\\"/g')
        echo "${var_name} = \"${escaped_value}\"" >> terraform.tfvars
      }
    else
      # Value is not JSON, treat as string
      escaped_value=$(echo "$env_value" | sed 's/"/\\"/g')
      echo "${var_name} = \"${escaped_value}\"" >> terraform.tfvars
    fi
  fi
done

echo "✅ terraform.tfvars generated:" >&2
# Don't print sensitive values
sed 's/do_token = .*/do_token = "***"/' terraform.tfvars | sed 's/n8n_encryption_key = .*/n8n_encryption_key = "***"/' >&2

echo "🚀 Deploying production grade horizontal n8n on DigitalOcean..." >&2

# Initialize OpenTofu
echo "📦 Initializing OpenTofu..." >&2
tofu init -input=false >&2

# Apply the configuration
echo "⚙️  Applying OpenTofu configuration..." >&2
tofu apply -auto-approve -input=false >&2

# Refresh the state to ensure it's up to date
echo "🔄 Refreshing OpenTofu state..." >&2
tofu refresh -input=false >&2

# Output the state file to stdout as a JSON array
echo "📄 Outputting state file..." >&2
STATE_JSON=$(tofu state pull)
# Wrap the state file JSON in an array using jq to ensure valid JSON
echo "$STATE_JSON" | jq -s '.'

# Cleanup
rm -rf "$TEMP_DIR"
