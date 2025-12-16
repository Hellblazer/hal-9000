# HAL-9000 Claude Marketplace

[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](https://github.com/Hellblazer/hal-9000/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Container Registry](https://img.shields.io/badge/ghcr.io-hellblazer%2Fhal--9000-blue?logo=docker)](https://github.com/Hellblazer/hal-9000/pkgs/container/hal-9000)

Claude Code productivity suite: containerized Claude, multi-branch development, MCP servers, issue tracking (beads), and custom agents.

## Architecture: tmux is the Backbone

**tmux is required** for hal9000 and aod. It's the coordination layer that makes everything work:

- **Session isolation** - Each Claude instance runs in its own tmux session
- **Remote control** - Send commands to any session without switching (`aod-send`, `hal9000-send`)
- **Persistence** - Sessions survive disconnection; reattach anytime
- **Orchestration** - Broadcast commands to all sessions simultaneously

```bash
# Required: Install tmux first
brew install tmux        # macOS
apt install tmux         # Ubuntu/Debian
```

All session management commands (`*-list`, `*-attach`, `*-send`, `*-broadcast`) are thin wrappers around tmux. Understanding tmux basics helps tremendously.

**[tmux Cheat Sheet →](CHEATSHEET.md#tmux-essentials)** | **[tmux-cli Reference →](CHEATSHEET.md#tmux-cli-remote-control)**

## Quick Start

### 1. Add Marketplace

Claude Code Settings → Marketplaces → Add: `https://github.com/Hellblazer/hal-9000.git`

### 2. Install Plugin

Browse marketplace → Install "hal-9000" → Run installer (choose mode when prompted)

[Detailed installation guide →](plugins/hal-9000/README.md#installation)

## What's Included

### hal9000 (Containerized Claude)

Launch isolated Claude containers with the full hal-9000 stack:

```bash
# Single container in current directory
hal9000 run
hal9000 run --profile python

# Multiple sessions for parallel work
hal9000 squad --sessions 3
hal9000 squad tasks.conf

# Session management
hal9000-list                      # List active sessions
hal9000-attach hal9000-1          # Attach to session
hal9000-send hal9000-1 "cmd"      # Send command
hal9000-broadcast "npm install"   # Send to all
hal9000-cleanup                   # Stop all
```

**Features:**
- ✅ **Claude CLI in containers** - Isolated Claude instance per session
- ✅ **MCP servers pre-installed** - Memory Bank, ChromaDB, Sequential Thinking ready to use
- ✅ **Shared Memory Bank** - Host's `~/memory-bank` mounted for cross-container access
- ✅ **Auto-configured** - MCP servers automatically configured on container startup
- ✅ **Custom agents & commands** - All 12 agents available in every container
- ✅ **Language profiles** - Python, Node.js, Java variants available

[Full hal9000 documentation →](plugins/hal-9000/hal9000/README.md)

### aod (Army of Darkness)

Multi-branch parallel development using hal9000 containers with git worktrees:

```bash
# Generate config template (YAML or simple format)
aod-init

# Or create YAML config manually
cat > aod.yml <<EOF
tasks:
  - branch: feature/auth
    profile: python
    description: Add OAuth2 authentication

  - branch: feature/api
    profile: node
    description: Build REST API endpoints
EOF

# Launch all sessions
aod aod.yml

# Manage sessions
aod-list                         # List active sessions
aod-attach aod-feature-auth      # Attach to session
aod-cleanup                      # Stop all sessions
```

**Simple format** (still supported):
```bash
# Format: branch:profile:description
feature/auth:python:Add OAuth2 authentication
feature/api:node:Build REST API endpoints
```

**Use cases:**
- Work on multiple features simultaneously
- Code review multiple PRs in parallel
- Bug triage across different branches
- Experiment with different approaches

Commands: `aod-init`, `aod`, `aod-list`, `aod-attach`, `aod-stop`, `aod-cleanup`, `aod-send`, `aod-broadcast`

**Quick control:** Use `aod-send SESSION "command"` to execute in specific session, or `aod-broadcast "command"` to run in all sessions without switching.

**Claude awareness:** Each session gets a `CLAUDE.md` with session context - Claude knows which session it's in and can coordinate with other sessions.

**vs hal9000:** Use aod for multi-branch development with git worktree isolation. Use hal9000 for general containerized work on current directory.

[Full aod documentation →](plugins/hal-9000/aod/README.md)

### MCP Servers

**ChromaDB** - Vector database for semantic search<br>
Usage: `Store this document in ChromaDB`, `Search ChromaDB for "authentication patterns"`<br>
[Details →](plugins/hal-9000/mcp-servers/chromadb/README.md)

**Memory Bank** - Persistent memory across sessions<br>
Usage: `Save this decision to memory bank`, `What did we decide about the schema?`<br>
[Details →](plugins/hal-9000/mcp-servers/memory-bank/README.md)

**Sequential Thinking** - Step-by-step reasoning<br>
Usage: `Debug this issue using sequential thinking`<br>
[Details →](plugins/hal-9000/mcp-servers/sequential-thinking/)

**DEVONthink** (macOS) - Document search and import<br>
Usage: `Search my DEVONthink for ML papers`, `Import arXiv paper 2312.03032`<br>
[Details →](plugins/hal-9000/mcp-servers/devonthink/README.md)

### Issue Tracking (beads)

**bd** - AI-optimized issue tracker with dependency support. "Issues chained together like beads."

```bash
bd init                           # Initialize in project
bd create "Task" -t feature -p 1  # Create issue
bd ready                          # Show ready work (no blockers)
bd update <id> --status in_progress
bd close <id> --reason "Done"
bd dep add <id> <blocker-id>      # Add dependency
```

[Details →](plugins/hal-9000/mcp-servers/beads/README.md)

### Custom Agents

12 specialized agents installed to `~/.claude/agents/`:

- **Development** - java-developer, java-architect-planner, java-debugger
- **Review & Analysis** - code-review-expert, plan-auditor, deep-analyst, codebase-deep-analyzer
- **Research** - deep-research-synthesizer, devonthink-researcher
- **Organization** - knowledge-tidier, pdf-chromadb-processor, project-management-setup

Usage: Agents are invoked automatically by Claude Code based on task context.

[Full agent documentation →](plugins/hal-9000/AGENTS.md)

### Session Commands

- `/check` - Save session context
- `/load` - Resume session
- `/sessions` - List all sessions
- `/session-delete` - Delete session

### Terminal Tools

- **tmux-cli** - Control interactive CLI apps from Claude
- **ccstatusline** - Real-time Claude Code status line (context %, git info, session time)
- **vault** - Encrypted .env backup with SOPS
- **env-safe** - Safe .env inspection without exposing secrets
- **find-session** - Search across all Claude Code sessions
- **Safety Hooks** - Git, file, and environment protection

## Configuration

### ChromaDB Cloud

```bash
export CHROMADB_TENANT="your-tenant-id"
export CHROMADB_DATABASE="your-database-name"
export CHROMADB_API_KEY="your-api-key"
```

Get credentials at [trychroma.com](https://www.trychroma.com/)

### Memory Bank

Default: `~/memory-bank`
Override: `export MEMORY_BANK_ROOT="/custom/path"`

### Optional Templates

Installer offers optional configuration templates:

**tmux.conf** - Catppuccin theme with CPU/RAM monitoring
- Session persistence (tmux-resurrect)
- Mouse support with clipboard integration
- Powerline status bar

**CLAUDE.md** - hal-9000 best practices guide
- tmux-cli usage patterns
- Agent workflow guidance
- ChromaDB/Memory Bank reference
- aod command quick reference

Both templates backup existing files before installation.

## Requirements

**Core:**
- Python 3.8+ (for ChromaDB)
- Node.js 16+ (for Memory Bank, Sequential Thinking)
- Bash, curl, git

**For hal9000/aod:**
- Docker
- tmux (auto-installed if missing)
- git (aod only - for worktrees)

**Optional:**
- macOS + DEVONthink Pro/Server (for DEVONthink MCP)
- SOPS (for vault encryption)

## Troubleshooting

**Installation Issues:**
- **PEP 668 errors**: Automatically handled by installer (v1.1.0+)
- **Command not found after install**: Add `~/.local/bin` to your PATH
- **SSL Certificate errors**: Update certificates or use trusted hosts

**Runtime Issues:**
- **MCP servers not appearing**: Restart Claude Code completely (⌘Q)
- **hal9000/aod sessions not starting**: Verify Docker is running (`docker ps`), check tmux (`which tmux`), try `hal9000-cleanup` or `aod-cleanup` then retry
- **Python/Node commands not found**: `export PATH="$HOME/.local/bin:$PATH"`, restart shell

[Full troubleshooting guide →](plugins/hal-9000/TROUBLESHOOTING.md)

## Documentation

- **[Cheat Sheet](CHEATSHEET.md)** - Quick reference for hal9000, aod, tmux, tmux-cli, and terminal tools
- [hal9000 (Containerized Claude)](plugins/hal-9000/hal9000/README.md)
- [aod (Army of Darkness)](plugins/hal-9000/aod/README.md)
- [Agent Usage](plugins/hal-9000/AGENTS.md)
- [ChromaDB MCP](plugins/hal-9000/mcp-servers/chromadb/README.md)
- [Memory Bank MCP](plugins/hal-9000/mcp-servers/memory-bank/README.md)
- [Sequential Thinking MCP](plugins/hal-9000/mcp-servers/sequential-thinking/)
- [DEVONthink MCP](plugins/hal-9000/mcp-servers/devonthink/README.md)
- [Beads (bd) Issue Tracker](plugins/hal-9000/mcp-servers/beads/README.md)

## Security

- Never commit secrets to git
- Use `vault backup .env` for encrypted backups
- Safety hooks block accidental `.env` commits
- Review files before committing: `git diff --cached`

## License

Apache 2.0

## Credits

- [ChromaDB](https://www.trychroma.com/)
- [Memory Bank](https://github.com/allpepper/memory-bank-mcp)
- [Claude Code Tools](https://github.com/pchalasani/claude-code-tools)
- [ClaudeBox](https://github.com/RchGrav/claudebox)
- [Beads](https://github.com/steveyegge/beads)
