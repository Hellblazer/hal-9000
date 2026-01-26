# DinD Troubleshooting Guide

## Quick Diagnostics

Run these commands to quickly identify issues:

```bash
# Check daemon status
claudy daemon status

# View parent container logs
docker logs hal9000-parent --tail 50

# Check ChromaDB health
curl http://localhost:8000/api/v2/heartbeat

# List all HAL-9000 containers
docker ps -a --filter "name=hal9000"
```

## Common Errors

### Error: "Parent container not running"

**Symptoms**:
```
Error: Parent container 'hal9000-parent' is not running
```

**Cause**: The parent container has stopped or was never started.

**Solution**:
```bash
# Check if container exists
docker ps -a --filter "name=hal9000-parent"

# If exists but stopped, start it
docker start hal9000-parent

# If doesn't exist, start daemon
claudy daemon start
```

### Error: "Cannot connect to Docker daemon"

**Symptoms**:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Cause**: Docker daemon not running or socket not accessible.

**Solution**:
```bash
# Check Docker is running
docker ps

# If not running:
# - Linux: sudo systemctl start docker
# - macOS: Open Docker Desktop
# - Windows: Start Docker Desktop

# Check socket permissions
ls -la /var/run/docker.sock
```

### Error: "ChromaDB failed to start"

**Symptoms**:
```
ChromaDB server failed to start within 30s
```

**Causes and Solutions**:

1. **Port in use**:
   ```bash
   # Check if port 8000 is in use
   lsof -i :8000

   # Use different port
   CHROMADB_PORT=8080 claudy daemon restart
   ```

2. **Corrupted data**:
   ```bash
   # Backup and reset ChromaDB data
   docker run --rm -v hal9000-chromadb:/data alpine mv /data /data.bak
   claudy daemon restart
   ```

3. **Insufficient memory**:
   ```bash
   # Check container memory
   docker stats hal9000-parent --no-stream

   # Increase if needed (requires rebuilding)
   ```

### Error: "Worker can't reach localhost:8000"

**Symptoms**:
```
curl: (7) Failed to connect to localhost port 8000
```

**Cause**: Network namespace not shared correctly.

**Solution**:
```bash
# Verify worker is using parent's network
docker inspect <worker-name> --format '{{.HostConfig.NetworkMode}}'
# Should show: container:hal9000-parent

# If not, respawn worker
docker rm -f <worker-name>
claudy --via-parent /path/to/project
```

### Error: "Resource limit exceeded"

**Symptoms**:
```
OOMKilled: true
```
or
```
pids limit reached
```

**Cause**: Worker exceeded memory, CPU, or process limits.

**Solution**:
```bash
# Spawn worker with higher limits
spawn-worker.sh --memory 8g --cpus 4 --pids-limit 200 /path/to/project

# Or disable limits (not recommended for production)
spawn-worker.sh --no-limits /path/to/project
```

### Error: "Image not found"

**Symptoms**:
```
Unable to find image 'ghcr.io/hellblazer/hal-9000:worker'
```

**Solution**:
```bash
# Pull the image manually
docker pull ghcr.io/hellblazer/hal-9000:worker

# Or build locally
docker build -f plugins/hal-9000/docker/Dockerfile.worker-minimal \
    -t ghcr.io/hellblazer/hal-9000:worker \
    plugins/hal-9000/docker/
```

## Network Issues

### Workers Can't Communicate

**Symptoms**: Workers can't reach each other or ChromaDB.

**Diagnosis**:
```bash
# Check parent container is running
docker ps --filter "name=hal9000-parent"

# Check worker network mode
docker inspect <worker-name> --format '{{.HostConfig.NetworkMode}}'

# Test connectivity from worker
docker exec <worker-name> curl http://localhost:8000/api/v2/heartbeat
```

**Solution**:
```bash
# Restart parent container
claudy daemon restart

# Respawn workers after restart
```

### Port Conflicts

**Symptoms**: Services can't bind to expected ports.

**Diagnosis**:
```bash
# Check what's using a port
lsof -i :8000
netstat -an | grep 8000
```

**Solution**:
```bash
# Use a different port
CHROMADB_PORT=8080 claudy daemon restart

# Update workers to use new port
export CHROMADB_URL=http://localhost:8080
```

### DNS Resolution Fails

**Symptoms**: Can't resolve external hostnames from workers.

**Solution**:
```bash
# Workers inherit parent's DNS
# Check parent can resolve
docker exec hal9000-parent nslookup google.com

# If parent fails, check host DNS
cat /etc/resolv.conf
```

## Volume Issues

### Permission Denied

**Symptoms**:
```
Permission denied: /data/chromadb
```

**Cause**: Volume ownership doesn't match container user.

**Solution**:
```bash
# Fix volume permissions
docker run --rm -v hal9000-chromadb:/data alpine chown -R root:root /data
docker run --rm -v hal9000-chromadb:/data alpine chmod -R 755 /data
```

### Data Not Persisted

**Symptoms**: Data disappears after container restart.

**Diagnosis**:
```bash
# Check volumes exist
docker volume ls | grep hal9000

# Check volume contents
docker run --rm -v hal9000-chromadb:/data alpine ls -la /data
```

**Solution**:
```bash
# Recreate volumes if missing
docker volume create hal9000-chromadb
docker volume create hal9000-memorybank
docker volume create hal9000-plugins

# Restore from backup
./scripts/rollback-dind.sh --restore
```

### Volume Full

**Symptoms**: Write operations fail.

**Diagnosis**:
```bash
# Check volume size
docker system df -v | grep hal9000

# Check specific volume
docker run --rm -v hal9000-chromadb:/data alpine df -h /data
```

**Solution**:
```bash
# Clean up old data
docker run --rm -v hal9000-chromadb:/data alpine find /data -type f -mtime +30 -delete

# Or resize volume (Docker Desktop)
# Increase disk space in Docker Desktop preferences
```

## Pool Manager Issues

### Warm Workers Not Created

**Symptoms**: `claudy pool status` shows 0 warm workers.

**Diagnosis**:
```bash
# Check if pool manager is running
claudy pool status

# Check logs
cat ~/.hal9000/logs/pool-manager.log
```

**Solution**:
```bash
# Restart pool manager
claudy pool stop
claudy pool start

# Create warm workers manually
claudy pool warm
```

### Workers Not Claimed

**Symptoms**: Cold start despite warm workers available.

**Cause**: Worker claiming logic failed.

**Solution**:
```bash
# Check worker states
ls -la ~/.hal9000/pool/workers/

# Clean up stale state
rm -rf ~/.hal9000/pool/workers/*.json

# Restart pool
claudy pool stop
claudy pool start
```

### Idle Workers Not Cleaned Up

**Symptoms**: Workers accumulate beyond max.

**Diagnosis**:
```bash
# Check pool status
claudy pool status

# Check idle timeout
echo $IDLE_TIMEOUT
```

**Solution**:
```bash
# Force cleanup
claudy pool cleanup

# Restart with shorter timeout
IDLE_TIMEOUT=60 claudy pool stop
claudy pool start
```

## Recovery Procedures

### Complete Reset

If everything is broken, start fresh:

```bash
# Stop everything
claudy daemon stop
docker ps -a --filter "name=hal9000" --format "{{.Names}}" | xargs -r docker rm -f

# Remove volumes (WARNING: deletes data)
docker volume rm hal9000-chromadb hal9000-memorybank hal9000-plugins

# Remove images
docker rmi ghcr.io/hellblazer/hal-9000:parent
docker rmi ghcr.io/hellblazer/hal-9000:worker

# Fresh start
claudy daemon start
```

### Restore from Backup

```bash
# List available backups
./scripts/rollback-dind.sh --list-backups

# Restore
./scripts/rollback-dind.sh --restore ~/.hal9000-backup-YYYYMMDD
```

### Export Volume Data

Before resetting, export important data:

```bash
# Export ChromaDB
docker run --rm \
    -v hal9000-chromadb:/source:ro \
    -v $(pwd):/backup \
    alpine tar czf /backup/chromadb-backup.tar.gz -C /source .

# Export Memory Bank
docker run --rm \
    -v hal9000-memorybank:/source:ro \
    -v $(pwd):/backup \
    alpine tar czf /backup/membank-backup.tar.gz -C /source .
```

### Emergency Recovery

If the parent container is stuck:

```bash
# Force remove
docker rm -f hal9000-parent

# Kill any orphan workers
docker ps -a --filter "name=hal9000-worker" --format "{{.Names}}" | xargs -r docker rm -f
docker ps -a --filter "name=hal9000-warm" --format "{{.Names}}" | xargs -r docker rm -f

# Start fresh
claudy daemon start
```

## Getting Help

### Collecting Debug Information

```bash
# Create debug bundle
DEBUG_DIR=/tmp/hal9000-debug-$(date +%Y%m%d-%H%M%S)
mkdir -p $DEBUG_DIR

# Collect logs
docker logs hal9000-parent > $DEBUG_DIR/parent.log 2>&1
cp ~/.hal9000/logs/* $DEBUG_DIR/

# Collect state
docker ps -a > $DEBUG_DIR/containers.txt
docker volume ls > $DEBUG_DIR/volumes.txt
claudy daemon status > $DEBUG_DIR/status.txt 2>&1

# Create archive
tar czf hal9000-debug.tar.gz -C /tmp $(basename $DEBUG_DIR)
echo "Debug bundle: hal9000-debug.tar.gz"
```

### Reporting Issues

When reporting issues, include:

1. Output of `claudy daemon status`
2. Output of `docker version`
3. Output of `claudy --version`
4. Relevant log snippets
5. Steps to reproduce

File issues at: https://github.com/Hellblazer/hal-9000/issues

---

**Navigation**: [Overview](README.md) | [Installation](INSTALLATION.md) | [Configuration](CONFIGURATION.md) | [Architecture](ARCHITECTURE.md) | [Migration](MIGRATION.md) | [Troubleshooting](TROUBLESHOOTING.md) | [Development](DEVELOPMENT.md)

**Quick Links**: [Quick Diagnostics](#quick-diagnostics) | [Common Errors](#common-errors) | [Network Issues](#network-issues) | [Recovery Procedures](#recovery-procedures)
