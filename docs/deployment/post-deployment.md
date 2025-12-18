# Post-Deployment

Steps to take after deploying your n8n infrastructure.

## Verify Deployment

### Check All Resources

```bash
# Check all resources
tofu show

# Get connection details
tofu output
```

### Test Main Instance

```bash
# Get the n8n URL
tofu output n8n_url

# Or test directly
curl http://$(tofu output -raw main_public_ip):5678
```

## Access n8n

1. Open the URL from `tofu output n8n_url` in your browser
2. Complete the n8n setup wizard
3. Create your first workflow!

## Verify Initialization

### Check Main Instance Logs

```bash
# SSH into main instance
ssh root@$(tofu output -raw main_public_ip)

# View initialization logs
cat /var/log/n8n-main-init.log

# View n8n container logs
docker logs n8n -f
```

### Check Worker Logs

```bash
# SSH into any worker
ssh root@<worker-ip>

# View initialization logs
cat /var/log/n8n-worker-init.log
```

## Verify Database Connections

```bash
# SSH into main instance
ssh root@$(tofu output -raw main_public_ip)

# Check PostgreSQL connection
docker exec n8n env | grep DB_POSTGRESDB

# Check Valkey connection
docker exec n8n env | grep REDIS
```

## Next Steps

1. **Configure DNS** (if using custom domain)
2. **Set up SSL/TLS** (if needed)
3. **Create workflows** in n8n
4. **Monitor performance** and scale as needed

## Scaling

See the [Architecture Overview](../architecture/overview.md) for scaling instructions.

## Troubleshooting

If you encounter issues, see the [Troubleshooting Guide](../troubleshooting.md).

