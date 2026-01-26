# DinD Configuration Guide

## Environment Variables

### Parent Container

| Variable | Default | Description |
|----------|---------|-------------|
| `HAL9000_HOME` | `/root/.hal9000` | Base directory for state |
| `WORKER_IMAGE` | `ghcr.io/hellblazer/hal-9000:worker` | Worker container image |
| `CHROMADB_HOST` | `0.0.0.0` | ChromaDB bind address |
| `CHROMADB_PORT` | `8000` | ChromaDB server port |
| `CHROMADB_DATA_DIR` | `/data/chromadb` | ChromaDB data directory |

### Startup Optimization

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_IMAGE_PULL` | `false` | Skip worker image pull entirely |
| `LAZY_IMAGE_PULL` | `false` | Pull worker image in background |

### Pool Manager

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_POOL_MANAGER` | `false` | Enable warm worker pool |
| `MIN_WARM_WORKERS` | `2` | Minimum warm workers to maintain |
| `MAX_WARM_WORKERS` | `5` | Maximum warm workers allowed |
| `IDLE_TIMEOUT` | `300` | Seconds before idle worker cleanup |
| `CHECK_INTERVAL` | `30` | Seconds between pool checks |

### Worker Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKER_MEMORY` | `4g` | Memory limit per worker |
| `WORKER_CPUS` | `2` | CPU cores per worker |
| `WORKER_PIDS_LIMIT` | `100` | Maximum processes per worker |

## Configuration Examples

### Basic Setup

```bash
# Start with defaults
claudy daemon start
```

### Fast Startup (Image Pre-pulled)

```bash
# Skip image pull check for faster startup
SKIP_IMAGE_PULL=true claudy daemon start
```

### High-Performance Workers

```bash
# Increase resources for heavy workloads
WORKER_MEMORY=8g WORKER_CPUS=4 WORKER_PIDS_LIMIT=200 claudy daemon start
```

### Warm Worker Pool

```bash
# Enable pool with 3 warm workers
ENABLE_POOL_MANAGER=true MIN_WARM_WORKERS=3 claudy daemon start
```

### Custom ChromaDB Port

```bash
# Use different port (useful if 8000 is in use)
CHROMADB_PORT=8080 claudy daemon start
```

## Claudy CLI Options

### Daemon Commands

```bash
claudy daemon start     # Start parent container
claudy daemon stop      # Stop parent container
claudy daemon status    # Check daemon health
claudy daemon restart   # Restart parent container
```

### Worker Spawn Options

```bash
claudy --via-parent /path/to/project   # Spawn via parent
claudy --via-parent --detach           # Spawn in background
claudy --via-parent --name my-session  # Custom session name
```

### Pool Commands

```bash
claudy pool start      # Start pool manager
claudy pool stop       # Stop pool manager
claudy pool status     # Show pool status
claudy pool scale 5    # Scale to 5 warm workers
claudy pool cleanup    # Remove idle workers
```

### Resource Limits via CLI

```bash
# Spawn worker with custom limits (spawn-worker.sh)
spawn-worker.sh --memory 8g --cpus 4 /path/to/project

# Disable limits
spawn-worker.sh --no-limits /path/to/project
```

## Volume Configuration

### Required Volumes

```bash
# Docker socket (required for worker spawning)
-v /var/run/docker.sock:/var/run/docker.sock

# HAL9000 state directory
-v ~/.hal9000:/root/.hal9000
```

### Optional Volumes

```bash
# ChromaDB persistent storage
-v hal9000-chromadb:/data/chromadb

# Memory Bank storage
-v hal9000-memorybank:/data/membank

# Plugins storage
-v hal9000-plugins:/data/plugins
```

## Network Configuration

Workers share the parent's network namespace:

```bash
docker run --network=container:hal9000-parent ...
```

This allows workers to:
- Access ChromaDB at `localhost:8000`
- Share DNS resolution with parent
- Communicate with other workers via localhost

## Resource Limit Recommendations

### Development Workload
```bash
WORKER_MEMORY=4g
WORKER_CPUS=2
WORKER_PIDS_LIMIT=100
```

### Heavy Compilation
```bash
WORKER_MEMORY=8g
WORKER_CPUS=4
WORKER_PIDS_LIMIT=200
```

### Minimal Footprint
```bash
WORKER_MEMORY=2g
WORKER_CPUS=1
WORKER_PIDS_LIMIT=50
```

## Troubleshooting Configuration

### Check Current Configuration

```bash
# View parent container environment
docker inspect hal9000-parent --format '{{json .Config.Env}}' | jq .

# View pool status with configuration
claudy pool status
```

### Reset to Defaults

```bash
# Stop and remove parent
claudy daemon stop
docker rm -f hal9000-parent

# Start with defaults
claudy daemon start
```

## Configuration Files

### Session Metadata

Worker sessions are recorded in `~/.hal9000/sessions/`:

```json
{
    "name": "worker-name",
    "image": "ghcr.io/hellblazer/hal-9000:worker",
    "parent": "hal9000-parent",
    "project_dir": "/path/to/project",
    "created_at": "2026-01-26T12:00:00Z",
    "resource_limits": {
        "enabled": true,
        "memory": "4g",
        "cpus": "2",
        "pids_limit": "100"
    }
}
```

### Pool State

Pool manager state stored in `~/.hal9000/pool/`:
- `pool-manager.pid` - Daemon process ID
- `workers/*.json` - Individual worker state files
