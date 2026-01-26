# HAL-9000 Volume Architecture

This document describes the volume and storage architecture for the HAL-9000 Docker-in-Docker system, enabling data sharing between parent and worker containers.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HOST MACHINE                                   │
│                                                                             │
│  ~/.hal9000/                          ~/.claude/                            │
│  ├── config/                          ├── settings.json                     │
│  ├── sessions/                        ├── .credentials.json                 │
│  ├── logs/                            ├── agents/                           │
│  ├── workers/                         └── commands/                         │
│  ├── chromadb/                                                              │
│  └── memory-bank/                                                           │
│                                                                             │
│  Docker Volumes:                                                            │
│  ├── hal9000-chromadb    (shared ChromaDB data)                            │
│  ├── hal9000-memorybank  (shared Memory Bank)                              │
│  └── hal9000-plugins     (marketplace plugins)                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Parent Container │  │  Worker 1        │  │  Worker 2        │
│                   │  │                  │  │                  │
│  /root/.hal9000/  │  │  /root/.claude/  │  │  /root/.claude/  │
│  (orchestration)  │  │  (claude config) │  │  (claude config) │
│                   │  │                  │  │                  │
│  /data/chromadb/  │  │  /data/chromadb/ │  │  /data/chromadb/ │
│  (shared)         │  │  (shared)        │  │  (shared)        │
│                   │  │                  │  │                  │
│  /data/membank/   │  │  /data/membank/  │  │  /data/membank/  │
│  (shared)         │  │  (shared)        │  │  (shared)        │
│                   │  │                  │  │                  │
│  /workspace       │  │  /workspace      │  │  /workspace      │
│  (project mount)  │  │  (project mount) │  │  (project mount) │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Directory Structure

### Host Directories

| Path | Purpose | Mounted To |
|------|---------|------------|
| `~/.hal9000/` | HAL-9000 orchestration state | Parent: `/root/.hal9000` |
| `~/.hal9000/config/` | Configuration files | Parent only |
| `~/.hal9000/sessions/` | Worker session metadata | Parent only |
| `~/.hal9000/logs/` | Orchestration logs | Parent only |
| `~/.hal9000/workers/` | Per-worker Claude configs | Workers: `/root/.claude` |
| `~/.hal9000/chromadb/` | ChromaDB persistent data | All: `/data/chromadb` |
| `~/.hal9000/memory-bank/` | Memory Bank projects | All: `/data/membank` |
| `~/.claude/` | Host Claude configuration | Reference only |

### Docker Named Volumes

| Volume | Purpose | Default Mount |
|--------|---------|---------------|
| `hal9000-chromadb` | Shared ChromaDB storage | `/data/chromadb` |
| `hal9000-memorybank` | Shared Memory Bank | `/data/membank` |
| `hal9000-plugins` | Marketplace plugins | `/data/plugins` |
| `hal9000-claude-{worker}` | Per-worker Claude state | `/root/.claude` |

## Volume Categories

### 1. Orchestration Volumes (Parent Only)

These volumes are used by the parent container for managing workers:

```bash
# Session metadata
~/.hal9000/sessions/
├── hal9000-worker-1234567890.json
├── hal9000-worker-0987654321.json
└── ...

# Logs
~/.hal9000/logs/
├── parent.log
├── coordinator.log
└── workers/
    ├── worker-1234567890.log
    └── ...

# Configuration
~/.hal9000/config/
├── hal9000.conf
└── defaults/
```

### 2. Shared Data Volumes (All Containers)

These volumes are mounted to both parent and all workers for data sharing:

#### ChromaDB

```bash
# Named volume structure
hal9000-chromadb/
├── chroma.sqlite3           # Main database
├── collections/             # Vector collections
│   ├── research-findings/
│   ├── code-patterns/
│   └── decisions/
└── embeddings/              # Cached embeddings
```

**Mount command:**
```bash
docker run ... -v hal9000-chromadb:/data/chromadb ...
```

#### Memory Bank

```bash
# Named volume structure
hal9000-memorybank/
├── project1/
│   ├── hypotheses.md
│   ├── findings.md
│   └── blockers.md
├── project2_active/
│   └── session.md
└── shared/
    └── cross-project.md
```

**Mount command:**
```bash
docker run ... -v hal9000-memorybank:/data/membank ...
```

### 3. Per-Worker Volumes

Each worker gets its own Claude configuration volume:

```bash
# Per-worker Claude home
hal9000-claude-{worker-name}/
├── .credentials.json        # Auth (copied from host)
├── settings.json            # MCP and preferences
├── agents/                  # Custom agents
├── commands/                # Custom commands
└── projects/                # Project-specific config
```

**Creation in DinD mode:**
```bash
# Named volume (DinD mode)
docker volume create hal9000-claude-$WORKER_NAME
docker run ... -v hal9000-claude-$WORKER_NAME:/root/.claude ...
```

**Creation on host:**
```bash
# Host directory (host mode)
mkdir -p ~/.hal9000/workers/$WORKER_NAME
docker run ... -v ~/.hal9000/workers/$WORKER_NAME:/root/.claude ...
```

### 4. Project Volumes

The project being worked on is mounted at `/workspace`:

```bash
docker run ... -v /path/to/project:/workspace ...
```

## Volume Lifecycle

### Initialization

```bash
# Initialize all volumes
./init-volumes.sh

# Creates:
# - Host directories under ~/.hal9000/
# - Named Docker volumes
# - Default configuration files
```

### Worker Spawn

```bash
# When spawning a worker:
./spawn-worker.sh -n my-worker /path/to/project

# Creates/uses:
# 1. hal9000-claude-my-worker volume (or ~/.hal9000/workers/my-worker/)
# 2. Mounts hal9000-chromadb to /data/chromadb
# 3. Mounts hal9000-memorybank to /data/membank
# 4. Mounts project to /workspace
```

### Cleanup

```bash
# Remove all volumes (destructive!)
./init-volumes.sh --clean

# Remove specific worker volume
docker volume rm hal9000-claude-my-worker
```

## Concurrent Access

### ChromaDB Server Architecture

The parent container runs a ChromaDB HTTP server that all workers connect to:

```
┌─────────────────────────────────────────────────────────────┐
│                    Parent Container                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          ChromaDB Server (port 8000)                │   │
│  │                                                     │   │
│  │  - Handles concurrent read/write safely             │   │
│  │  - Data persisted to /data/chromadb                 │   │
│  │  - Workers connect via HTTP                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                          ↑                                  │
└──────────────────────────│──────────────────────────────────┘
                           │ localhost:8000
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Worker 1    │  │   Worker 2    │  │   Worker N    │
│               │  │               │  │               │
│ chroma-mcp    │  │ chroma-mcp    │  │ chroma-mcp    │
│ --client-type │  │ --client-type │  │ --client-type │
│   http        │  │   http        │  │   http        │
└───────────────┘  └───────────────┘  └───────────────┘
```

**Why HTTP client instead of persistent storage?**
- SQLite (persistent mode) has limited concurrent write support
- Multiple workers writing to same SQLite file causes locking issues
- HTTP server handles concurrent access safely
- Workers share network namespace, so localhost:8000 works

```yaml
# MCP server configuration for workers
mcpServers:
  chromadb:
    command: chroma-mcp
    args: ["--client-type", "http", "--host", "localhost", "--port", "8000"]
    env:
      CHROMA_ANONYMIZED_TELEMETRY: "false"
```

**Concurrency notes:**
- Parent runs ChromaDB server, handles all database operations
- Workers connect as HTTP clients (safe concurrent access)
- Server-side locking ensures data integrity
- No file-level conflicts between workers

### Memory Bank

Memory Bank uses file-based storage with project isolation:

```bash
# Each project gets its own directory
/data/membank/
├── project-a/          # Worker 1 working here
├── project-b/          # Worker 2 working here
└── shared/             # Cross-project data
```

**Concurrency notes:**
- Use project-per-worker for isolation
- Shared directory for cross-worker communication
- File-level locking for concurrent edits

## Configuration Integration

### MCP Server Configuration

Workers connect to parent's ChromaDB server via HTTP:

```json
{
  "mcpServers": {
    "chromadb": {
      "command": "chroma-mcp",
      "args": ["--client-type", "http", "--host", "localhost", "--port", "8000"]
    },
    "memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp"],
      "env": {
        "MEMORY_BANK_ROOT": "/data/membank"
      }
    }
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HAL9000_BASE` | `~/.hal9000` | Base directory for HAL-9000 |
| `CHROMADB_PATH` | `/data/chromadb` | ChromaDB data directory |
| `MEMORYBANK_PATH` | `/data/membank` | Memory Bank root |
| `PLUGINS_PATH` | `/data/plugins` | Marketplace plugins |

## Security Considerations

### Volume Permissions

```bash
# Host directories should be user-readable
chmod 700 ~/.hal9000
chmod 600 ~/.hal9000/config/hal9000.conf

# Credentials need protection
chmod 600 ~/.hal9000/workers/*/.*
```

### Secrets Management

- API keys stored in environment variables, not files
- Credentials copied at worker spawn time
- No secrets in shared volumes

### Isolation

- Workers can't access parent's orchestration data
- Workers can't access other workers' Claude configs
- Shared data (ChromaDB, Memory Bank) is intentionally shared

## Troubleshooting

### Volume Not Found

```bash
# Check if volume exists
docker volume ls | grep hal9000

# Create missing volumes
./init-volumes.sh
```

### Permission Denied

```bash
# Check ownership
ls -la ~/.hal9000/

# Fix permissions
chmod -R u+rwX ~/.hal9000/
```

### Data Not Syncing

```bash
# Verify mount
docker exec worker-name ls -la /data/chromadb/

# Check volume driver
docker volume inspect hal9000-chromadb
```

### Stale Data in Worker

```bash
# Worker might have cached data
# Restart the worker to get fresh mounts
docker restart worker-name
```

## Best Practices

1. **Use named volumes for DinD mode** - Host paths don't work inside containers
2. **Initialize before first run** - Run `init-volumes.sh` before starting
3. **Project isolation** - Use separate Memory Bank projects per task
4. **Regular backups** - Back up `~/.hal9000/` periodically
5. **Clean unused volumes** - Remove orphaned worker volumes

## Volume Mount Summary

```bash
# Full worker spawn with all volumes
docker run -d --rm \
    --name hal9000-worker-$NAME \
    --network container:hal9000-parent \
    -v hal9000-claude-$NAME:/root/.claude \
    -v hal9000-chromadb:/data/chromadb \
    -v hal9000-memorybank:/data/membank \
    -v hal9000-plugins:/data/plugins \
    -v /path/to/project:/workspace \
    -e ANTHROPIC_API_KEY \
    ghcr.io/hellblazer/hal-9000:worker
```
