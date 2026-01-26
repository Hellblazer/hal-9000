# MCP Server Configuration for Workers

## Overview

Based on Phase 0 validation (P0-1), MCP servers use **stdio transport only** and must run on the HOST machine, not inside containers. This document explains how workers access MCP functionality.

## Architecture

```
Host Machine
├── ~/.claude/settings.json       ← MCP server configuration
├── MCP Server Processes          ← Spawned by Claude CLI via stdio
│   ├── mcp-server-memory-bank
│   ├── mcp-server-sequential-thinking
│   └── chroma-mcp
│
└── Docker
    └── Worker Container
        ├── /root/.claude/        ← Mounted from host
        └── Claude CLI            ← Reads settings.json, spawns MCP servers
```

## How MCP Works in Workers

### Option 1: Mount Host's Claude Config (Recommended)

Mount the host's `~/.claude` directory into the worker:

```bash
docker run --rm -it \
    --network=container:hal9000-parent \
    -v ~/.claude:/root/.claude \
    -v /path/to/project:/workspace \
    ghcr.io/hellblazer/hal-9000:worker
```

This gives the worker:
- MCP server configuration from `settings.json`
- Authentication credentials
- Custom agents and commands

**How it works**:
1. Claude CLI inside worker reads `/root/.claude/settings.json`
2. Claude spawns MCP servers as child processes (stdio transport)
3. MCP servers run inside the worker container
4. Communication happens via stdin/stdout pipes

### Option 2: Separate Claude Config per Worker

Create a per-worker Claude configuration:

```bash
# Create worker-specific config
mkdir -p ~/.hal9000/workers/worker-1/.claude
cp ~/.claude/settings.json ~/.hal9000/workers/worker-1/.claude/

# Run with worker-specific config
docker run --rm -it \
    --network=container:hal9000-parent \
    -v ~/.hal9000/workers/worker-1/.claude:/root/.claude \
    -v /path/to/project:/workspace \
    ghcr.io/hellblazer/hal-9000:worker
```

### Option 3: No MCP (Minimal Mode)

Run workers without MCP servers:

```bash
docker run --rm -it \
    --network=container:hal9000-parent \
    -v /path/to/project:/workspace \
    -e ANTHROPIC_API_KEY \
    ghcr.io/hellblazer/hal-9000:worker
```

Claude will work but without MCP tools (memory-bank, sequential-thinking, chromadb).

## MCP Server Requirements

For MCP servers to work inside workers, the container needs:

### memory-bank-mcp

```json
{
  "mcpServers": {
    "memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp@0.2.2"],
      "env": {
        "MEMORY_BANK_ROOT": "/root/memory-bank"
      }
    }
  }
}
```

**Container requirement**: Node.js and npx in PATH

**Note**: Worker images don't include Node.js by default. Use `ghcr.io/hellblazer/hal-9000:base` for full MCP support, or run MCP-free with `ghcr.io/hellblazer/hal-9000:worker`.

### sequential-thinking

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking@2025.12.18"]
    }
  }
}
```

**Container requirement**: Node.js and npx in PATH

### chroma-mcp

```json
{
  "mcpServers": {
    "chromadb": {
      "command": "chroma-mcp",
      "args": ["--client-type", "ephemeral"],
      "env": {}
    }
  }
}
```

**Container requirement**: Python and chroma-mcp installed

## Worker Image Comparison

| Image | Size | MCP Support | Use Case |
|-------|------|-------------|----------|
| `hal-9000:worker` | 588MB | No (Claude only) | Lightweight tasks |
| `hal-9000:worker-ultramin` | 469MB | No (Claude only) | Minimal footprint |
| `hal-9000:base` | 2.85GB | Yes (full) | Full MCP functionality |

## spawn-worker.sh MCP Options

The `spawn-worker.sh` script supports MCP configuration:

```bash
# With host's Claude config (MCP enabled if base image)
spawn-worker.sh --mount-claude /path/to/project

# Without MCP
spawn-worker.sh /path/to/project

# With specific Claude home
spawn-worker.sh --claude-home ~/.hal9000/workers/worker-1/.claude /path/to/project
```

## Shared Data Considerations

### ChromaDB

If using ChromaDB with cloud mode, workers need:
- `CHROMADB_TENANT` environment variable
- `CHROMADB_DATABASE` environment variable
- `CHROMADB_API_KEY` environment variable

```bash
docker run --rm -it \
    -e CHROMADB_TENANT \
    -e CHROMADB_DATABASE \
    -e CHROMADB_API_KEY \
    -v ~/.claude:/root/.claude \
    ghcr.io/hellblazer/hal-9000:base
```

### Memory Bank

Memory bank data should be persisted:

```bash
docker run --rm -it \
    -v ~/.claude:/root/.claude \
    -v ~/memory-bank:/root/memory-bank \
    ghcr.io/hellblazer/hal-9000:base
```

## Troubleshooting

### "MCP server not found"

**Cause**: Worker image doesn't have Node.js/Python for MCP servers.

**Solution**: Use `hal-9000:base` image or run without MCP.

### "Cannot connect to MCP server"

**Cause**: MCP servers use stdio, not network.

**Solution**: Mount host's `~/.claude` into worker. MCP servers will run inside worker.

### "ChromaDB connection failed"

**Cause**: ChromaDB environment variables not passed.

**Solution**: Pass `-e CHROMADB_*` environment variables to docker run.

## Summary

| Scenario | Image | Mount | MCP Works? |
|----------|-------|-------|------------|
| Full MCP | base | ~/.claude | Yes |
| Claude only | worker | None | No |
| Shared config | worker | ~/.claude | No* |

*Worker image lacks Node.js/Python for MCP servers. Mount host config for credentials only.

## Recommended Configuration

For most use cases:

```bash
# Full MCP support (slower startup, larger image)
docker run --rm -it \
    --network=container:hal9000-parent \
    -v ~/.claude:/root/.claude \
    -v ~/memory-bank:/root/memory-bank \
    -v /path/to/project:/workspace \
    -e CHROMADB_TENANT -e CHROMADB_API_KEY \
    ghcr.io/hellblazer/hal-9000:base

# Lightweight (no MCP, faster startup)
docker run --rm -it \
    --network=container:hal9000-parent \
    -v /path/to/project:/workspace \
    -e ANTHROPIC_API_KEY \
    ghcr.io/hellblazer/hal-9000:worker
```
