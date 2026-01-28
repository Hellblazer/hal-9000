# Release Notes - hal-9000 v1.4.0

**Release Date**: January 27, 2026

## Overview

hal-9000 v1.4.0 introduces **persistent session management** and **cross-session MCP configuration**, eliminating the need to re-authenticate or reconfigure tools with every new container instance.

## What's New

### 🎯 Major Features

#### Session Persistence Across Container Instances
- **Authentication tokens persist** - login once, use in all subsequent sessions
- **Claude session state survives** container lifecycle changes
- Implemented via `hal9000-claude-session` shared Docker volume
- Users no longer need to re-login when starting a new project

**Before v1.4.0**:
```bash
hal-9000 /project1          # Login required
exit
hal-9000 /project2          # Login required AGAIN ✗
```

**After v1.4.0**:
```bash
hal-9000 /project1          # Login once
exit
hal-9000 /project2          # Logged in automatically ✓
```

#### MCP Server Configuration Persistence
- **MCP server registrations survive** session boundaries
- **Custom MCP server settings** are preserved across containers
- **Feature flags and preferences** maintained consistently
- Critical for multi-session workflows with shared tools

**Example**:
```bash
# Session 1: Add a custom MCP server
hal-9000 /project1
# Inside Claude: (add custom MCP server)
exit

# Session 2: Custom server automatically available
hal-9000 /project2
# Custom MCP server is ready to use ✓
```

#### Subscription Login Support
- Users can now authenticate with Claude subscription
- API key authentication still fully supported
- Subscription auth provides better credential management
- Both methods store credentials in persistent volume

### 🐳 Docker Images

All four profile images published and tested:

| Image | Size | Includes |
|-------|------|----------|
| `base` | 652MB | Claude CLI, Docker CLI, Node.js, Python, uv, foundation MCP servers |
| `python` | 652MB | base + Python 3.11, pip, venv |
| `node` | 652MB | base + Node.js 20 LTS, npm, yarn, pnpm |
| `java` | 652MB | base + Java 21 LTS, Maven, Gradle |

**Registry**: `ghcr.io/hellblazer/hal-9000`

### 📦 Foundation MCP Servers (Pre-installed)

- **ChromaDB** - Vector database for semantic search
- **Memory Bank** - Cross-session persistent memory
- **Sequential Thinking** - Step-by-step reasoning

### 🏗️ Shared Volumes

Three persistent Docker volumes enable cross-session state:

| Volume | Purpose | Content |
|--------|---------|---------|
| `hal9000-claude-home` | Plugin installations & credentials | `~/.claude` directory |
| `hal9000-claude-session` | Session state & MCP config | `.claude.json` + auth tokens |
| `hal9000-memory-bank` | Cross-session memory | Structured memory store |

## Installation

### New Users

```bash
# Download and install hal-9000 CLI
curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash

# Verify installation
hal-9000 --version

# Start using it
hal-9000 /path/to/your/project
```

### Upgrade from v1.3.2

The upgrade is transparent - no configuration changes needed:

```bash
# Stop running containers (optional)
hal-9000 daemon stop

# Re-run the installer
curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash

# Restart
hal-9000 /path/to/your/project
```

**Migration Note**: Your existing session data and MCP configurations are automatically preserved in shared volumes.

## Key Improvements

### Persistence
- Session state no longer lost between container instances
- Credentials cached for faster login experience
- MCP registrations survive container lifecycle

### Reliability
- Fixed critical bug where authentication state was not shared
- Improved credential caching mechanism
- Better Docker volume mount handling

### Developer Experience
- Faster project switching (no re-login required)
- Consistent MCP environment across all sessions
- Better integration with Claude Code plugins

## Breaking Changes

**None**. This is a fully backward-compatible release.

Existing installations will continue to work without modification. New sessions will automatically use the persistent volumes.

## Docker Images Registry

Images are published to GitHub Container Registry (ghcr.io):

```bash
# Automatically pulled by hal-9000 CLI when needed
hal-9000 /path

# Manual pull (if needed)
docker pull ghcr.io/hellblazer/hal-9000:base
docker pull ghcr.io/hellblazer/hal-9000:python
docker pull ghcr.io/hellblazer/hal-9000:node
docker pull ghcr.io/hellblazer/hal-9000:java
```

## Verification & Testing

### Installation Verification
```bash
hal-9000 --verify
# Should report: Prerequisites verified
```

### Session Persistence Test
```bash
# First session
hal-9000 /project1
# [Inside Claude] Run any command
exit

# Second session (without re-login)
hal-9000 /project2
# [Session should be authenticated]
```

### MCP Configuration Test
```bash
# Add custom MCP server in first session
hal-9000 /project1
# [Register custom MCP server]
exit

# Check persistence in second session
hal-9000 /project2
# [Custom MCP server should be available]
```

## Known Issues

None at this time. Please report issues at: https://github.com/Hellblazer/hal-9000/issues

## Support

- **Documentation**: https://github.com/Hellblazer/hal-9000
- **Issues**: https://github.com/Hellblazer/hal-9000/issues
- **Community**: GitHub Discussions

## Credits

Session persistence implementation and verification enabled by comprehensive Docker volume testing and architectural validation.

---

**Previous Version**: v1.3.2
**Next Version Target**: v1.5.0 (E2E testing, CI/CD pipeline)

## SHA256 Checksums

```
install-hal-9000.sh: [provided in release assets]
```

---

*hal-9000: Containerized Claude with persistent sessions and MCP configuration management*
