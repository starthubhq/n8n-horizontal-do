# Prerequisites

Before deploying production grade horizontal n8n on DigitalOcean, ensure you have the following:

## Required Accounts & Services

### 1. DigitalOcean Account

- Sign up at [digitalocean.com](https://www.digitalocean.com)
- Add a payment method (required for creating resources)

### 2. DigitalOcean API Token

1. Go to [API Tokens](https://cloud.digitalocean.com/account/api/tokens)
2. Click "Generate New Token"
3. Give it a name (e.g., "OpenTofu")
4. Select "Write" scope
5. Copy the token (you'll need it for `variables.tfvars`)

### 3. SSH Key in DigitalOcean

1. If you don't have an SSH key, generate one:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

2. Get your SSH key fingerprint:
   ```bash
   ssh-keygen -lf ~/.ssh/id_rsa.pub -E md5 | awk '{print $2}' | sed 's/MD5://g'
   ```

3. Add the SSH key to DigitalOcean:
   - Go to [SSH Keys](https://cloud.digitalocean.com/account/security)
   - Click "Add SSH Key"
   - Paste your public key (`~/.ssh/id_rsa.pub`)
   - Copy the fingerprint shown

## Required Software

### OpenTofu

Install OpenTofu on your local machine:

**macOS (Homebrew):**
```bash
brew install opentofu
```

**Linux:**
```bash
# Download from https://opentofu.org/docs/intro/install/
# Or use your package manager
```

**Windows:**
- Download from [opentofu.org/docs/intro/install/](https://opentofu.org/docs/intro/install/)
- Or use Chocolatey: `choco install opentofu`

**Verify installation:**
```bash
tofu version
```

### DigitalOcean CLI (Optional but Recommended)

The `doctl` CLI is useful for managing DigitalOcean resources:

**macOS (Homebrew):**
```bash
brew install doctl
```

**Linux/Windows:**
- Download from [doctl releases](https://github.com/digitalocean/doctl/releases)

**Authenticate:**
```bash
doctl auth init
```

## System Requirements

- **Operating System**: macOS, Linux, or Windows
- **RAM**: At least 4GB available
- **Internet**: Stable connection for downloading OpenTofu providers and images
- **Disk Space**: ~500MB for OpenTofu and providers

## Estimated Costs

Before deploying, be aware of the estimated monthly costs:

| Resource | Size | Monthly Cost |
|----------|------|--------------|
| PostgreSQL | db-s-1vcpu-1gb | $15 |
| Valkey | db-s-1vcpu-1gb | $15 |
| Main Droplet | s-1vcpu-2gb | $12 |
| Worker (x3) | s-1vcpu-1gb | $6 × 3 = $18 |
| **Total** | | **~$60/month** |

These are estimates and may vary based on your region and usage.

## Next Steps

Once you have all prerequisites ready, proceed to the [Quick Start Guide](quick-start.md).

