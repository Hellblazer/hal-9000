# HAL-9000 Plugin

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Hellblazer/hal-9000/releases)
[![Container](https://img.shields.io/badge/docker-dind-success?logo=docker)](../../docker/README.md)
[![MCP Servers](https://img.shields.io/badge/MCP-4%20servers-purple)](mcp-servers/)

Containerized Claude with Docker-in-Docker orchestration, persistent session state, MCP servers, multi-branch development, and safety tools.

## Components

### MCP Servers

**ChromaDB**
- Vector database for semantic search
- Document storage with embeddings
- Hybrid search combining semantic and keyword matching

**Memory Bank**
- Persistent memory across sessions
- Project-based knowledge organization
- Multi-agent coordination

**Sequential Thinking**
- Step-by-step reasoning
- Problem decomposition
- Hypothesis verification

**DEVONthink** (macOS only)
- Document research integration
- Knowledge graph construction
- Requires DEVONthink Pro/Server

### Session Commands

- `/check` - Save session context
- `/load` - Resume session
- `/sessions` - List sessions
- `/session-delete` - Delete session

### Terminal Tools

- **tmux-cli** - Terminal automation for interactive CLIs
- **ccstatusline** - Pre-configured Claude Code status line with Powerline styling (context %, session time, git info, worktree status) - requires Nerd Font for full appearance
- **vault** - Encrypted .env backup with SOPS
- **env-safe** - Safe .env inspection
- **find-session** - Search across agent sessions
- **Safety hooks** - Git, file, and environment protection

### Development Environments

**hal9000** - Containerized Claude sessions
- `hal9000 run --profile python` - Single containerized session
- `hal9000 squad --sessions 3` - Multiple parallel sessions
- Good for: isolated development, parallel tasks on same codebase
- [hal9000 documentation →](hal9000/README.md)

**aod (Army of Darkness)** - Multi-branch parallel development
- Uses git worktrees + tmux + hal-9000 containers with pre-installed MCP servers
- Good for: working on multiple branches of same repo simultaneously
- [aod documentation →](aod/README.md)

**ClaudeBox** - Foundation tool (external)
- hal9000 and aod build on ClaudeBox container infrastructure
- [ClaudeBox documentation →](https://github.com/RchGrav/claudebox)

## Installation

Install through the hal-9000 marketplace in Claude Code. The installer provides three modes:

1. **Complete** - Host installation plus ClaudeBox shared directory
2. **Host Only** - Host installation without ClaudeBox sharing
3. **ClaudeBox Shared Only** - Shared directory for containers

## Requirements

- Python 3.8+ (ChromaDB)
- Node.js 16+ (Memory Bank, Sequential Thinking)
- Docker (ClaudeBox, optional)
- tmux (auto-installed if missing)
- gh - GitHub CLI (auto-installed if missing)

## Configuration

### ChromaDB Cloud

Set environment variables:
```bash
CHROMADB_TENANT=your-tenant-id
CHROMADB_DATABASE=your-database-name
CHROMADB_API_KEY=your-api-key
```

### ChromaDB Local

Use local storage at `~/.chromadb` instead of cloud. The installer can configure this.

### Memory Bank

Default: `~/memory-bank`

Override with `MEMORY_BANK_ROOT` environment variable.

### DEVONthink

DEVONthink MCP server is included in `mcp-servers/devonthink/`. Requires:
- macOS with DEVONthink Pro/Server installed
- Python 3.8+ (pre-installed on macOS)
- Grant automation permissions in System Settings

The server is automatically configured during hal-9000 installation.

## Usage

### MCP Servers

ChromaDB and Memory Bank tools become available automatically. Use naturally in prompts:
```
Store this in ChromaDB with ID "design-notes"
Save this decision to memory bank project "my-app"
```

### Terminal Tools

```bash
tmux-cli launch "python -m pdb script.py"
vault backup .env
find-session "auth implementation"
```

### aod (Army of Darkness)

Multi-branch parallel development with optimized container performance.

```bash
# Create configuration for multiple branches
cat > aod.conf <<EOF
feature/auth:python:Add authentication
feature/api:node:Build REST API
EOF

# Launch all sessions
aod aod.conf

# Manage sessions
aod-list                         # List active sessions
aod-attach aod-feature-auth      # Attach to session
aod-send aod-feature-auth "cmd"  # Send command without attaching
aod-broadcast "cmd"              # Send to all sessions
aod-cleanup                      # Stop all sessions
```

**v2.0.0 Architecture:** Docker-in-Docker parent-worker orchestration with Foundation MCP servers (ChromaDB, Memory Bank, Sequential Thinking) running at host level. All workers share persistent volumes for credentials, plugins, and cross-session state.

### hal9000 Sessions

hal9000 wraps ClaudeBox for containerized Claude with the full hal-9000 stack:

```bash
# Single container
hal9000 run --profile python

# Multiple sessions
hal9000 squad --sessions 3
```

See [hal9000 documentation](hal9000/README.md) for session management commands.

## Documentation

- **[Cheat Sheet](../../CHEATSHEET.md)** - Quick reference for aod, tmux, tmux-cli, and terminal tools
- MCP Servers: `mcp-servers/*/README.md`
- Commands: `commands/*.md`
- aod (Army of Darkness): `aod/README.md`

## Troubleshooting

### MCP servers not available
- Restart Claude Code
- Check environment variables are set
- Verify prerequisites installed

### Commands not working
- Check `~/.claude/commands/` contains .md files
- Try `/help` to see available commands

### ccstatusline not showing

**Problem:** Status line doesn't appear in Claude Code

**Solutions:**
- Verify Node.js or Bun installed: `which bunx` or `which npx`
- Check Claude settings: `cat ~/.claude/settings.json | jq .statusLine`
- Test command manually: `bunx -y ccstatusline@latest`
- Verify widget config exists: `cat ~/.config/ccstatusline/settings.json`
- Restart Claude Code completely (not just refresh)

**Problem:** Status line shows errors or wrong data

**Solutions:**
- Reconfigure widgets: `bunx ccstatusline@latest`
- Check settings valid JSON: `jq . ~/.config/ccstatusline/settings.json`
- Reset to defaults: Re-run `install.sh` to recreate config
