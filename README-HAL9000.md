# hal-9000 - Containerized Claude CLI

Quick, frictionless access to Claude inside a containerized development environment.

**Status**: Phase 1 - Core Foundation (Alpha)

## What is hal-9000?

hal-9000 is a simple wrapper that opens Claude inside a tmux session within a hal-9000 container. No permission dialogs. No complexity. Just `hal-9000` and you're working.

```bash
$ cd ~/my-project
$ hal-9000
# Claude opens inside a container with your project mounted
```

## Quick Start

### 1. Prerequisites

- Docker (running)
- bash 4.4+ (macOS, Linux, WSL2)
- hal-9000 Docker images built locally (or will use base)

### 2. Install

```bash
# Clone hal-9000 repository
git clone https://github.com/hellblazer/hal-9000.git
cd hal-9000

# Install hal-9000
./install-hal-9000.sh

# Verify installation
hal-9000 --verify
```

### 3. First Use

```bash
# Navigate to your project
cd ~/my-project

# Start Claude in a container
hal-9000

# That's it! You're now in Claude inside a container
# Your project is mounted at /workspace
```

## Features

### Docker Integration

hal-9000 automatically mounts your Docker daemon socket into the container, allowing you to use `docker` commands as if you were on the host:

```bash
# Inside hal-9000 container
docker build -t my-app .
docker run my-app
docker compose up

# All commands work against your host Docker daemon
```

**Requirements**: Docker daemon running on host
**Security**: Container doesn't have Docker privileges - uses host daemon

### Automatic Project Detection

hal-9000 automatically detects your project type:

- **Java**: Looks for `pom.xml`, `build.gradle`, `build.gradle.kts`
- **Python**: Looks for `pyproject.toml`, `Pipfile`, `requirements.txt`
- **Node.js**: Looks for `package.json`
- **Default**: Uses base profile if nothing detected

```bash
# Auto-detects profile
hal-9000

# Or force a specific profile
hal-9000 --profile python
```

### Per-Project Session Isolation

Each project gets its own isolated session with:
- Isolated `.claude` directory (config, agents, commands)
- Isolated tmux session
- Deterministic session naming for consistency
- Automatic cleanup of old sessions

### No Permission Dialogs

Because hal-9000 runs inside a container (sandbox), there are no permission popups. The container is the security boundary.

### Persistent Plugins & Configuration

hal-9000 uses Docker volumes to share CLAUDE_HOME across all sessions:
- Plugins installed in any session persist for all sessions
- Settings, agents, commands shared across workers
- No copying or syncing - just shared volumes

```bash
# Install a plugin - it persists across all hal-9000 sessions
hal-9000 plugin install memory-bank
hal-9000 mcp list
```

## Usage

### Basic Commands

```bash
# Start Claude (auto-detect profile)
hal-9000

# Start Claude with specific profile
hal-9000 --profile java

# Start bash shell instead of Claude
hal-9000 --shell

# Run detached (don't attach to tmux)
hal-9000 --detach

# Custom session name
hal-9000 --name my-session

# Specific directory
hal-9000 ~/projects/myapp
```

### Claude Command Passthrough

Run any `claude` command through hal-9000 - it executes in a container with the shared volume:

```bash
# Plugin management
hal-9000 plugin list                        # List installed plugins
hal-9000 plugin install memory-bank         # Install a plugin
hal-9000 plugin marketplace add <url>       # Add a marketplace

# MCP server management
hal-9000 mcp list                           # List MCP servers
hal-9000 mcp add <server>                   # Add an MCP server

# Health checks
hal-9000 doctor                             # Check Claude health
```

All changes persist in the shared Docker volume (`hal9000-claude-home`).

### DinD Mode (v0.7.0+)

For multi-worker orchestration with shared services:

```bash
# Start the daemon (parent container with ChromaDB)
hal-9000 daemon start

# Spawn workers via parent (shared network namespace)
hal-9000 --via-parent ~/my-project

# Check orchestrator status
hal-9000 daemon status

# Stop orchestrator
hal-9000 daemon stop
```

See `plugins/hal-9000/docker/README-dind.md` for full DinD architecture documentation.

### Help and Diagnostics

```bash
# Show all options
hal-9000 --help

# Check prerequisites (Docker, bash, tmux)
hal-9000 --verify

# Show detailed diagnostics
hal-9000 --diagnose
```

### Environment Variables

**HAL9000_HOME**: Path to hal-9000 session metadata storage

```bash
# Override default session storage location (default: ~/.hal9000)
export HAL9000_HOME=$HOME/.my-hal9000-sessions
hal-9000
```

**ANTHROPIC_API_KEY**: API key for Claude authentication

```bash
# Set API key for all hal-9000 sessions
export ANTHROPIC_API_KEY=sk-ant-api03-...
hal-9000
```

### Docker Volumes

hal-9000 uses shared Docker volumes for persistence:

| Volume | Purpose |
|--------|---------|
| `hal9000-claude-home` | CLAUDE_HOME - plugins, settings, agents |
| `hal9000-memory-bank` | Memory bank for cross-session context |

All workers share these volumes, so plugins installed in any session persist everywhere.

## How It Works

### Architecture

![hal-9000 Sessions Architecture](../docs/diagrams/hal9000-sessions.png)

### Execution Flow

1. **Detect**: Auto-detect project type from markers
2. **Volumes**: Ensure shared Docker volumes exist
3. **Metadata**: Create session metadata in `~/.hal9000/claude/{session}/`
4. **Launch**: Start container with shared volumes mounted
5. **Mount**: Project directory mounted at /workspace

### Session Naming

Sessions are named deterministically:
```
hal-9000-{project-name}-{path-hash}
```

This ensures:
- Same project always gets same session name
- No collisions if same project name in different directories
- Easy to identify in `tmux list-sessions`

## Features (Phase 1 - Current)

✅ **Core Foundation**
- Simple bash wrapper
- Auto-profile detection
- Per-project session isolation
- Session-based authentication
- Help and diagnostics

🔄 **Coming Soon (Phase 2-3)**
- Configuration system (.hal-9000rc)
- Multi-project coordination
- Skills (/wrap, /sup, /fragile)
- Advanced orchestration
- Knowledge storage integration

## Troubleshooting

### "Docker not found"
```bash
# Install Docker
# macOS: brew install docker
# Linux: apt-get install docker.io

# Start Docker daemon
# macOS: open -a Docker
# Linux: systemctl start docker
```

### "No Claude session found"
```bash
# Authenticate Claude
claude /login

# Then run hal-9000 again
hal-9000
```

### "Container image not found"
```bash
# Build hal-9000 images
cd plugins/hal-9000/docker
./build-profiles.sh

# Then try hal-9000 again
hal-9000
```

### "Permission denied"
```bash
# Make sure hal-9000 is executable
chmod +x /usr/local/bin/hal-9000

# Or reinstall
./install-hal-9000.sh
```

## Architecture

### Why a Container?

- **Isolation**: Your project code runs in sandbox
- **No permissions**: Container is the security boundary
- **Reproducibility**: Same environment every time
- **Flexibility**: Different profiles per project type

### Why tmux?

- **Background management**: Keep sessions alive
- **Reattach**: Return to work later with full state
- **Parallel**: Run multiple projects simultaneously
- **Integration**: Works from IDE terminal or external shell

### Why Simple?

- **Zero configuration**: Works out of the box
- **Frictionless**: Just type `hal-9000` and go
- **Progressive**: Advanced features available when needed
- **Human control**: Claude doesn't make unilateral decisions

## Development Status

| Phase | Status | Features |
|-------|--------|----------|
| **Phase 1** | ✅ In Progress | Core script, profiles, session management |
| **Phase 2** | 📋 Planned | Configuration, multi-project coordination |
| **Phase 3** | 📋 Planned | Skills, advanced orchestration |

## Contributing

To report issues or suggest improvements:

1. Check [GitHub Issues](https://github.com/hellblazer/hal-9000/issues)
2. For bugs, provide: OS, bash version, error messages
3. For features, link to design documents in `.pm/` directory

## Documentation

- **Installation**: See `install-hal-9000.sh`
- **Design Details**: See `.pm/HAL9000_MASTER_INDEX.md` in Memory Bank
- **Architecture**: See `.pm/HAL9000_DESIGN_SYNTHESIS.md`
- **Authentication**: See `.pm/hal-9000-authentication-revised.md`

## License

Apache 2.0 - See LICENSE file in repository

---

**Get started**: `cd ~/your-project && hal-9000`

**Need help?** `hal-9000 --help` or `hal-9000 --diagnose`
