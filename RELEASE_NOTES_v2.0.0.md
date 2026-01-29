# HAL-9000 v2.0.0 Release Notes

**Release Date**: January 28, 2026
**Type**: Major Release
**Note**: All 16 custom agents removed (breaking change). DinD orchestration and profiles fully compatible with v1.x.

---

## Overview

HAL-9000 v2.0.0 represents a major evolution in containerized Claude, introducing Docker-in-Docker orchestration, persistent session management, and Foundation MCP servers running at the host level. Existing Docker features and profiles work unchanged, with all 16 custom agents removed.

**Key Highlights**:
- **Docker-in-Docker Orchestration** - Parent orchestrator with worker pool management
- **Session State Persistence** - MCP configurations and authentication survive session boundaries
- **Security Hardening** - Code injection and path traversal prevention with comprehensive security audit
- **Comprehensive Testing** - 30+ core tests (security, configuration, build integration)
- **Multi-Profile Docker Images** - Parent, worker, base, python, node, java profiles

---

## Major Features

### 1. Docker-in-Docker Orchestration

**Problem**: Running Claude Code in isolated containers while maintaining shared state and resource efficiency.

**Solution**: Parent-worker architecture with persistent shared volumes.

**What's New**:
- **Parent Container** - Orchestrator managing worker lifecycle and shared services
- **Worker Containers** - Isolated Claude Code instances with full marketplace support
- **Shared Volumes**:
  - `hal9000-claude-home` - Plugins, credentials, marketplace installations
  - `hal9000-claude-session` - Session state, MCP configurations, authentication
  - `hal9000-memory-bank` - Persistent cross-session memory

### 2. Persistent Session State

**Problem**: Configuration lost between container instances; users had to re-login and reconfigure MCP servers.

**Solution**: Shared volumes with pristine initialization and one-time setup.

**What's New**:
- Authentication tokens persist across sessions
- MCP server configurations survive container restarts
- Marketplace plugin installations shared across all workers
- One-time volume initialization with .initialized marker files

### 3. Foundation MCP Servers

Foundation MCP Servers run at the host level rather than inside worker containers. This architecture ensures:
- Single ChromaDB instance shared across all workers
- Consistent Memory Bank state across sessions
- Reduced resource overhead (one ChromaDB vs. per-worker)
- Simplified networking (workers connect to host services)

**Deployment**: `~/.hal9000/scripts/setup-foundation-mcp.sh`

**What's Included**:
- **ChromaDB** - Vector database server on port 8000 (configurable)
- **Memory Bank** - Persistent file-based storage for cross-session context
- **Sequential Thinking** - Pre-installed in all workers

### 4. Security Hardening

**Critical Fixes (v1.5.0)**:
- **Code Injection Prevention** - Safe config file parsing (no arbitrary code execution)
- **Path Traversal Prevention** - Profile name validation blocks `../` attacks

**Testing**: 19 security tests + 11 configuration constraint tests

---

## Docker Images

### Published Profiles

- **ghcr.io/hellblazer/hal-9000:parent** (934 MB) - DinD orchestrator
- **ghcr.io/hellblazer/hal-9000:worker** (1.68 GB) - DinD worker with MCP
- **ghcr.io/hellblazer/hal-9000:base** (2.85 GB) - Minimal Claude environment
- **ghcr.io/hellblazer/hal-9000:python** (2.85 GB) - Python 3.11 + uv
- **ghcr.io/hellblazer/hal-9000:node** (2.85 GB) - Node.js 20 LTS
- **ghcr.io/hellblazer/hal-9000:java** (2.85 GB) - Java 21 LTS

### Build System

```bash
# Build all profiles
plugins/hal-9000/docker/build-profiles.sh

# Build and push specific profiles
plugins/hal-9000/docker/build-profiles.sh --push python node java
```

---

## Test Coverage

**Security Tests** (19 tests):
- Code injection via config files (8 tests)
- Path traversal in profile names (11 tests)

**Configuration Tests** (11 tests):
- Volume initialization (5 tests)
- Container startup (6 tests)

**Build & Integration Tests** (73+ tests):
- Daemon lifecycle (11 tests)
- Pool manager (13 tests)
- Resource limits (16 tests)
- E2E migration (5 tests)

---

## Installation & Usage

### Fresh Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash

# Verify installation
hal-9000 --version          # Shows: 2.0.0
hal-9000 daemon start       # Start orchestrator
hal-9000                    # Launch Claude in current directory
```

### Foundation MCP Servers (One-Time Setup)

```bash
# Setup ChromaDB, Memory Bank, and Sequential Thinking
~/.hal9000/scripts/setup-foundation-mcp.sh

# Check status
~/.hal9000/scripts/setup-foundation-mcp.sh --status

# Customize ChromaDB port
~/.hal9000/scripts/setup-foundation-mcp.sh --chromadb-port 8001
```

### Marketplace Plugins

```bash
# Add marketplace
hal-9000 plugin marketplace add Hellblazer/hal-9000

# Install plugins
hal-9000 plugin install beads              # Issue tracking
hal-9000 plugin install aod                # Multi-branch development
```

---

## Breaking Changes

**Agent Removal**: All 16 custom agents (java-developer, code-review-expert, strategic-planner, and others) have been removed from hal-9000. Users who relied on agents should:
- Migrate to marketplace plugins for similar functionality
- Transition workflows to MCP server-based approaches
- Use containerized Claude without agent orchestration

---

## Migration from v1.x

Docker features and profiles work unchanged. No migration required.

**For Users Who Used Agents**:
1. All 16 agents removed - explore marketplace plugins for similar functionality
2. MCP servers (ChromaDB, Memory Bank) provide specialized capabilities
3. See documentation for migration guidance

---

## Known Issues & Workarounds

### Docker daemon not running

```bash
# Ensure Docker is running
docker ps

# Start daemon
hal-9000 daemon start
```

### Volume conflicts from previous sessions

```bash
# Clean up Docker volumes
docker volume prune -f

# Reinitialize volumes
hal-9000 daemon start
```

---

## Performance Notes

- **Container startup**: ~5-10 seconds per worker
- **Session recovery**: Instant (volumes mount pre-initialized)
- **ChromaDB vector searches**: <100ms typical (depends on dataset size)

---

## Feedback & Issues

- **Bug reports**: https://github.com/Hellblazer/hal-9000/issues
- **Documentation**: https://github.com/Hellblazer/hal-9000/wiki
- **Security**: https://github.com/Hellblazer/hal-9000/security

---

## License

Apache 2.0 - See LICENSE file for details.
