# Configuration Variables

This page documents all available OpenTofu variables for customizing your n8n deployment.

## Required Variables

### `do_token`
- **Type**: `string`
- **Description**: DigitalOcean API token
- **Example**: `"dop_v1_abc123..."`

### `ssh_keys`
- **Type**: `list(string)`
- **Description**: List of SSH key fingerprints to add to droplets
- **Example**: `["aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"]`

## Optional Variables

See `.tfvars.example` for a complete list of all available variables and their descriptions.

## Getting Your SSH Key Fingerprint

```bash
ssh-keygen -lf ~/.ssh/id_rsa.pub -E md5 | awk '{print $2}' | sed 's/MD5://g'
```

Or from DigitalOcean dashboard: https://cloud.digitalocean.com/account/security

