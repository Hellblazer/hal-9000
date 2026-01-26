# claudy - Containerized Claude

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Hellblazer/hal-9000/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Container Registry](https://img.shields.io/badge/ghcr.io-hellblazer%2Fhal--9000-blue?logo=docker)](https://github.com/Hellblazer/hal-9000/pkgs/container/hal-9000)

Run Claude Code in isolated Docker containers with MCP servers pre-installed.

## Quick Start

```bash
# Install claudy
curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-claudy.sh | bash

# Set API key
export ANTHROPIC_API_KEY=sk-ant-api03-...

# Start the daemon (first time)
claudy daemon start

# Launch Claude in current directory
claudy
```

## What's Included

Every container comes with:

- **Claude CLI** - Native binary, auto-updates
- **ChromaDB** - Vector database (shared across containers)
- **Memory Bank** - Persistent memory across sessions
- **Sequential Thinking** - Step-by-step reasoning
- **tmux-cli** - Terminal automation tools

## Usage

### Basic

```bash
claudy                     # Launch in current directory
claudy /path/to/project    # Launch in specific directory
claudy --shell             # Start bash instead of Claude
```

### Daemon Management

```bash
claudy daemon start        # Start orchestrator + ChromaDB
claudy daemon status       # Check status
claudy daemon stop         # Stop everything
```

### Worker Pool (Optional)

Pre-warm containers for instant startup:

```bash
claudy pool start          # Start pool manager
claudy pool status         # View warm/busy workers
claudy pool scale 3        # Maintain 3 warm workers
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Host Machine                    │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         Parent Container                  │   │
│  │  ┌────────────────────────────────────┐  │   │
│  │  │       ChromaDB Server              │  │   │
│  │  │       (localhost:8000)             │  │   │
│  │  └────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────┘   │
│                      │                           │
│         ┌────────────┼────────────┐              │
│         ▼            ▼            ▼              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  │ Worker 1 │ │ Worker 2 │ │ Worker 3 │         │
│  │ Claude   │ │ Claude   │ │ Claude   │         │
│  │ MCP      │ │ MCP      │ │ MCP      │         │
│  └──────────┘ └──────────┘ └──────────┘         │
└─────────────────────────────────────────────────┘
```

- **Parent**: Runs ChromaDB server, manages workers
- **Workers**: Run Claude with MCP servers, share parent's network

## Requirements

- Docker
- Bash
- `ANTHROPIC_API_KEY` environment variable

## Configuration

### Environment Variables

```bash
export ANTHROPIC_API_KEY=sk-ant-api03-...  # Required
export CLAUDE_HOME=~/.claude               # Claude config (default)
export MEMORY_BANK_ROOT=~/memory-bank      # Memory storage (default)
```

### Profiles

```bash
claudy --profile base      # Minimal (default)
claudy --profile python    # + Python tools
claudy --profile node      # + Node.js tools
claudy --profile java      # + Java/Maven tools
```

## Companion Tools

### beads (bd) - Issue Tracking

AI-optimized issue tracker with dependency support:

```bash
bd init                           # Initialize in project
bd create "Task" -t feature -p 1  # Create issue
bd ready                          # Show unblocked work
bd close <id>                     # Complete issue
```

[beads documentation →](plugins/hal-9000/mcp-servers/beads/README.md)

### aod - Multi-Branch Development

Parallel development across git branches:

```bash
aod-init                 # Generate config
aod aod.yml              # Launch all branches
aod-list                 # Show sessions
aod-broadcast "cmd"      # Send to all
```

[aod documentation →](plugins/hal-9000/aod/README.md)

## Troubleshooting

```bash
claudy --diagnose              # Show diagnostic info
claudy daemon status           # Check daemon health
docker logs hal9000-parent     # View parent logs
```

### Common Issues

**"Parent container not running"**
```bash
claudy daemon start
```

**"Cannot connect to Docker"**
```bash
# Ensure Docker is running
docker ps
```

**"ChromaDB not responding"**
```bash
claudy daemon restart
```

## Documentation

- [Architecture Details](plugins/hal-9000/docs/dind/ARCHITECTURE.md)
- [Configuration Reference](plugins/hal-9000/docs/dind/CONFIGURATION.md)
- [Troubleshooting Guide](plugins/hal-9000/docs/dind/TROUBLESHOOTING.md)
- [Development Guide](plugins/hal-9000/docs/dind/DEVELOPMENT.md)

## License

Apache 2.0
