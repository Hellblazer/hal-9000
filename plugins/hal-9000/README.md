# HAL-9000 Plugin

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Hellblazer/hal-9000/releases)
[![Container](https://img.shields.io/badge/docker-dind-success?logo=docker)](../../docker/README.md)

Containerized Claude with Docker-in-Docker orchestration, persistent session state, multi-branch development, and safety tools.

## Components

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
- Uses git worktrees + tmux + hal-9000 containers
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

- Docker (optional, for containerized sessions)
- tmux (auto-installed if missing)
- gh - GitHub CLI (auto-installed if missing)

## Usage

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

**v2.0.0 Architecture:** Docker-in-Docker parent-worker orchestration with shared persistent volumes for credentials, plugins, and cross-session state across all workers.

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
- Commands: `commands/*.md`
- aod (Army of Darkness): `aod/README.md`

## Troubleshooting

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
