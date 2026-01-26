# HAL-9000 Docker-in-Docker (DinD) Architecture

This directory contains the parent/worker container architecture for running Claude Code in isolated Docker containers.

## Architecture Overview

```
Host Machine
├── MCP Servers (stdio transport)     ← Run on HOST (not containerized)
│   ├── memory-bank-mcp
│   ├── sequential-thinking
│   └── chroma-mcp
│
└── Docker
    └── Parent Container (hal9000-parent)
        ├── Coordinator process
        ├── tmux dashboard
        └── Spawns workers via Docker socket
            ├── Worker 1 (--network=container:parent)
            ├── Worker 2 (--network=container:parent)
            └── Worker N (--network=container:parent)
```

### Why This Architecture?

Based on Phase 0 validation spikes:
- **MCP servers use stdio transport only** - Cannot run in containers over network
- **Network namespace sharing works** - Workers access parent's localhost
- **Lightweight workers achievable** - 469MB (79% reduction from 2.85GB)

## Quick Start with Claudy

The easiest way to use the DinD architecture is through the `claudy` CLI (v0.6.0+).

### 1. Start the Daemon

```bash
# Start the orchestrator (parent container with ChromaDB)
claudy daemon start

# Check status
claudy daemon status
```

### 2. Spawn Workers

```bash
# Interactive worker
claudy --via-parent /path/to/project

# Background worker
claudy --via-parent --detach --name my-worker /path/to/project
```

### 3. Manage the Daemon

```bash
claudy daemon status    # Check health and worker count
claudy daemon restart   # Restart the orchestrator
claudy daemon stop      # Stop the orchestrator
```

## Manual Quick Start

For advanced use cases, you can manage containers directly.

### 1. Build Images

```bash
# Build parent image
docker build -f Dockerfile.parent -t ghcr.io/hellblazer/hal-9000:parent .

# Build worker image (choose one)
docker build -f Dockerfile.worker-ultramin -t ghcr.io/hellblazer/hal-9000:worker .  # 469MB, no git
docker build -f Dockerfile.worker-minimal -t ghcr.io/hellblazer/hal-9000:worker .   # 588MB, with git
```

### 2. Initialize Volumes

```bash
./init-volumes.sh
```

### 3. Start Parent Container

```bash
docker run -d --name hal9000-parent \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.hal9000:/root/.hal9000 \
    ghcr.io/hellblazer/hal-9000:parent
```

### 4. Spawn Workers

```bash
# Interactive worker
docker exec hal9000-parent /scripts/spawn-worker.sh /path/to/project

# Background worker
docker exec hal9000-parent /scripts/spawn-worker.sh -d -n my-worker /path/to/project
```

## Migration from v0.5.x

If you're upgrading from claudy v0.5.x (single-container mode) to v0.6.x (DinD mode):

### Automatic Migration

```bash
# Dry run first (see what would happen)
./scripts/migrate-to-dind.sh --dry-run

# Run migration
./scripts/migrate-to-dind.sh
```

The migration script will:
1. Back up your existing data (ChromaDB, Memory Bank, plugins)
2. Create named Docker volumes
3. Migrate data into volumes
4. Start the DinD daemon
5. Verify the migration

### Using Legacy Mode

If you need to use the old single-container mode temporarily:

```bash
claudy --legacy /path/to/project
```

Note: `--legacy` mode is deprecated and will be removed in v1.0.

### Rollback

If you encounter issues, you can rollback:

```bash
# List available backups
./scripts/rollback-dind.sh --list-backups

# Rollback to v0.5.x mode
./scripts/rollback-dind.sh

# Keep volume data while rolling back
./scripts/rollback-dind.sh --keep-volumes
```

## Container Images

### Parent Image (`Dockerfile.parent`)

**Size**: ~264MB

**Purpose**: Coordinator container that spawns and manages workers.

**Contents**:
- Docker CLI (for spawning workers)
- tmux (session management)
- Coordinator scripts
- No Claude CLI (workers run Claude)

**Key Scripts**:
- `/scripts/parent-entrypoint.sh` - Initialization and coordinator
- `/scripts/spawn-worker.sh` - Spawn worker containers
- `/scripts/coordinator.sh` - Worker management commands
- `/scripts/setup-dashboard.sh` - tmux dashboard setup

### Worker Image (`Dockerfile.worker-ultramin`)

**Size**: ~469MB (without git), ~588MB (with git)

**Purpose**: Lightweight Claude Code execution environment.

**Contents**:
- Claude CLI (206MB)
- Minimal system libraries
- No Node.js, Python, or MCP servers

## Scripts Reference

### spawn-worker.sh

Spawn a Claude worker container.

```bash
spawn-worker.sh [options] [project_dir]

Options:
  -n, --name NAME       Worker name (default: auto-generated)
  -d, --detach          Run in background
  -i, --image IMAGE     Worker image
  --rm                  Remove on exit (default)
  --no-rm               Keep container after exit
  --memory SIZE         Memory limit (default: 4g)
  --cpus N              CPU limit (default: 2)
  --pids-limit N        Process limit (default: 100)
  --no-limits           Disable resource limits
```

#### Resource Limits

Workers have default resource limits to prevent runaway processes:

| Resource | Default | Description |
|----------|---------|-------------|
| Memory | 4g | Maximum memory usage |
| CPUs | 2 | CPU cores allocation |
| PIDs | 100 | Maximum processes |

Override via environment variables or arguments:

```bash
# Via environment
WORKER_MEMORY=8g WORKER_CPUS=4 spawn-worker.sh /path/to/project

# Via arguments
spawn-worker.sh --memory 8g --cpus 4 --pids-limit 200 /path/to/project

# Disable all limits
spawn-worker.sh --no-limits /path/to/project
```

### coordinator.sh

Manage worker containers.

```bash
coordinator.sh <command> [args]

Commands:
  list              List active workers
  count             Count active workers
  stop <name>       Stop a specific worker
  stop-all          Stop all workers
  logs <name>       View worker logs
  attach <name>     Attach to worker shell
  status            Show status summary
```

### init-volumes.sh

Initialize HAL-9000 persistent volumes.

```bash
init-volumes.sh [options]

Options:
  --clean       Remove existing volumes first
  --status      Show current status only
```

## Network Architecture

Workers share the parent container's network namespace:

```bash
docker run --network=container:hal9000-parent ...
```

This means:
- Workers can access `localhost:PORT` services on parent
- Workers share parent's DNS resolution
- No port conflicts between workers
- Parent must be running for workers to have network

### Connecting to Host MCP Servers

Since MCP servers run on the host with stdio transport, workers cannot directly access them. Instead:

1. **Option A**: Mount host's Claude config into worker
   ```bash
   docker run -v ~/.claude:/root/.claude ...
   ```

2. **Option B**: Use parent container as relay (future enhancement)

3. **Option C**: Run Claude directly on host, use workers for execution only

## Volume Structure

```
~/.hal9000/
├── sessions/        # Worker session metadata
├── logs/            # Container logs
├── config/          # Configuration files
│   └── hal9000.conf # Main config
└── workers/         # Per-worker Claude home directories
```

## tmux Dashboard

The parent container includes a tmux dashboard for monitoring.

```bash
# Attach to dashboard
docker exec -it hal9000-parent tmux -L hal9000 attach

# Key bindings (in tmux)
prefix + w    Spawn new worker
prefix + s    Show status
prefix + l    List workers
prefix + S    Stop all workers (with confirmation)
```

## Startup Optimization

The parent container uses an optimized startup sequence (P6-4):

### Parallel Initialization

Startup is organized into phases:
1. **Critical init** (~100ms): Directories, Docker socket verification
2. **Parallel init** (~500ms): ChromaDB starts async, tmux and image check run in parallel
3. **Service ready** (variable): Wait for ChromaDB to be ready
4. **Background services** (non-blocking): Pool manager starts without blocking

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_IMAGE_PULL` | false | Skip worker image pull entirely |
| `LAZY_IMAGE_PULL` | false | Pull worker image in background |
| `ENABLE_POOL_MANAGER` | false | Enable warm worker pool |
| `MIN_WARM_WORKERS` | 2 | Minimum warm workers to maintain |
| `MAX_WARM_WORKERS` | 5 | Maximum warm workers allowed |

### Fast Startup Configuration

For fastest startup (when image is pre-pulled):

```bash
docker run -d --name hal9000-parent \
    -e SKIP_IMAGE_PULL=true \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/hellblazer/hal-9000:parent
```

For background image pull (non-blocking):

```bash
docker run -d --name hal9000-parent \
    -e LAZY_IMAGE_PULL=true \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/hellblazer/hal-9000:parent
```

### Pre-warming Strategy

Enable the pool manager for instant worker availability:

```bash
docker run -d --name hal9000-parent \
    -e ENABLE_POOL_MANAGER=true \
    -e MIN_WARM_WORKERS=3 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/hellblazer/hal-9000:parent
```

Warm workers are pre-created and can be claimed instantly (<50ms) versus cold start (~2-5s).

## Testing

Run integration tests:

```bash
./test-phase1-integration.sh
```

Run performance benchmarks:

```bash
./scripts/build/benchmark-dind.sh all
```

## Troubleshooting

### Docker socket not accessible

```
Error: Cannot connect to Docker daemon
```

Ensure Docker socket is mounted:
```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

### Worker can't reach parent's localhost

Verify network namespace sharing:
```bash
# Should show same network namespace
docker exec hal9000-parent cat /proc/net/tcp
docker exec worker-name cat /proc/net/tcp
```

### Old Docker client version

If you see "client version too old" errors, the parent image uses docker-ce-cli for compatibility with Docker Desktop.

## Phase 0 Validation Results

| Spike | Result | Finding |
|-------|--------|---------|
| P0-1: MCP HTTP Transport | NO-GO | stdio only, run on host |
| P0-3: Network Namespace | GO | --network=container:parent works |
| P0-4: Worker Image | GO | 469MB achievable |

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.parent` | Parent/coordinator container |
| `Dockerfile.worker-minimal` | Worker with git (588MB) |
| `Dockerfile.worker-ultramin` | Worker without git (469MB) |
| `parent-entrypoint.sh` | Parent initialization |
| `spawn-worker.sh` | Worker spawning |
| `coordinator.sh` | Worker management |
| `init-volumes.sh` | Volume initialization |
| `setup-dashboard.sh` | tmux dashboard |
| `tmux-dashboard.conf` | tmux configuration |
| `test-phase1-integration.sh` | Integration tests |
