# Troubleshooting

Common issues and solutions when deploying production grade horizontal n8n on DigitalOcean.

## Initialization Issues

### Viewing Initialization Logs

All initialization scripts save their output to log files for troubleshooting.

#### Main Instance Logs

```bash
# SSH into main instance
ssh root@$(terraform output -raw main_public_ip)

# View initialization logs
cat /var/log/n8n-main-init.log

# Follow logs in real-time (if still initializing)
tail -f /var/log/n8n-main-init.log

# View n8n container logs
docker logs n8n -f
```

#### Worker Instance Logs

```bash
# SSH into any worker
ssh root@<worker-ip>

# View initialization logs
cat /var/log/n8n-worker-init.log

# Follow logs in real-time (if still initializing)
tail -f /var/log/n8n-worker-init.log
```

### What the Logs Contain

- Script start/completion timestamps
- Docker readiness checks
- Volume creation
- n8n container startup
- Database connection details (host/port only, not passwords)
- Health check results
- Any errors encountered during setup

## Common Issues

### Database Connection Failures

**Symptoms:**
- n8n fails to start
- Connection timeout errors in logs
- "SSL required" errors

**Solutions:**

1. **Check database is ready:**
   ```bash
   # Databases take 10-15 minutes to provision
   terraform output database_host
   ```

2. **Verify SSL configuration:**
   - Ensure `DB_POSTGRESDB_SSL_ENABLED=true` is set
   - Check `SSL_REJECT_UNAUTHORIZED=false` for DigitalOcean certificates

3. **Check VPC connectivity:**
   - Verify all resources are in the same VPC
   - Check firewall rules allow database access

### Queue Connection Issues

**Symptoms:**
- Workers not processing jobs
- "Redis connection failed" errors

**Solutions:**

1. **Verify Valkey is ready:**
   ```bash
   terraform output valkey_host
   ```

2. **Check TLS configuration:**
   - Ensure `QUEUE_BULL_REDIS_TLS=true` is set
   - Verify TLS certificate settings

3. **Test Redis connection from worker:**
   ```bash
   ssh root@<worker-ip>
   docker exec n8n env | grep REDIS
   ```

### Encryption Key Mismatch

**Symptoms:**
- Workers can't decrypt data
- "Decryption failed" errors

**Solutions:**

1. **Verify all instances use the same key:**
   ```bash
   terraform output -raw n8n_encryption_key
   ```

2. **Check environment variables:**
   ```bash
   ssh root@$(terraform output -raw main_public_ip)
   docker exec n8n env | grep N8N_ENCRYPTION_KEY
   ```

3. **Ensure key is 32 hex characters:**
   - Auto-generated keys are correct
   - Manual keys must be exactly 32 hex characters

### Docker Not Available

**Symptoms:**
- "docker: command not found"
- Container startup failures

**Solutions:**

1. **Verify Docker image:**
   - Ensure using `docker-20-04` or `docker-24-04` image
   - Or install Docker via cloud-init

2. **Check Docker service:**
   ```bash
   ssh root@<droplet-ip>
   systemctl status docker
   docker --version
   ```

### Workers Not Processing Jobs

**Symptoms:**
- Jobs stuck in queue
- Workers idle

**Solutions:**

1. **Verify worker configuration:**
   ```bash
   ssh root@<worker-ip>
   docker exec n8n env | grep EXECUTIONS_MODE
   # Should be: EXECUTIONS_MODE=queue
   ```

2. **Check queue connection:**
   - Verify Valkey connection details
   - Check TLS settings
   - Ensure workers can reach Valkey via VPC

3. **Verify worker mode:**
   ```bash
   docker exec n8n env | grep N8N_DISABLE_PRODUCTION_MAIN_PROCESS
   # Should be: N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true
   ```

## Verification Steps

### Verify Deployment

```bash
# Check all resources
terraform show

# Get connection details
terraform output

# Test main instance
curl http://$(terraform output -raw main_public_ip):5678
```

### Verify Database Connections

```bash
# SSH into main instance
ssh root@$(terraform output -raw main_public_ip)

# Check PostgreSQL connection
docker exec n8n env | grep DB_POSTGRESDB

# Check Valkey connection
docker exec n8n env | grep REDIS
```

### Verify Worker Status

```bash
# SSH into worker
ssh root@<worker-ip>

# Check n8n container
docker ps | grep n8n

# Check logs
docker logs n8n --tail 50
```

## Getting Help

If you encounter issues not covered here:

1. Check the [n8n Documentation](https://docs.n8n.io)
2. Review [DigitalOcean Documentation](https://docs.digitalocean.com)
3. Check [Terraform DigitalOcean Provider Docs](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
4. Review initialization logs (see above)

## Cleanup

If you need to start over:

```bash
# Destroy all resources
terraform destroy

# Remove state files (if needed)
rm terraform.tfstate terraform.tfstate.backup
```

