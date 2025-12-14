# HAL-9000 Claude Marketplace

Claude Code productivity suite: multi-branch development, MCP servers, and custom agents.

## Quick Start

### 1. Add Marketplace

Claude Code Settings → Marketplaces → Add: `https://github.com/Hellblazer/hal-9000.git`

### 2. Install Plugin

Browse marketplace → Install "hal-9000" → Run installer (choose mode when prompted)

[Detailed installation guide →](plugins/hal-9000/README.md#installation)

## What's Included

### aod (Army of Darkness)

Multi-branch parallel development using ClaudeBox containers with git worktrees and tmux sessions

```bash
# Create task configuration
cat > aod.conf <<EOF
feature/auth:python:Add OAuth2 authentication
feature/api:node:Build REST API endpoints
bugfix/validation:python:Fix input validation
EOF

# Launch all sessions
aod aod.conf

# List active sessions
aod-list

# Attach to a session
aod-attach aod-feature-auth

# Stop all sessions
aod-cleanup
```

**Use cases:**
- Work on multiple features simultaneously
- Code review multiple PRs in parallel
- Bug triage across different branches
- Experiment with different approaches

Commands: `aod`, `aod-list`, `aod-attach`, `aod-stop`, `aod-cleanup`, `aod-send`, `aod-broadcast`

**Quick control:** Use `aod-send SESSION "command"` to execute in specific session, or `aod-broadcast "command"` to run in all sessions without switching.

**Claude awareness:** Each session gets a `CLAUDE.md` with session context - Claude knows which session it's in and can coordinate with other sessions.

[Full aod documentation →](plugins/hal-9000/aod/README.md)

### MCP Servers

**ChromaDB** - Vector database for semantic search
Usage: `Store this document in ChromaDB`, `Search ChromaDB for "authentication patterns"`
[Details →](plugins/hal-9000/mcp-servers/chromadb/README.md)

**Memory Bank** - Persistent memory across sessions
Usage: `Save this decision to memory bank`, `What did we decide about the schema?`
[Details →](plugins/hal-9000/mcp-servers/memory-bank/README.md)

**Sequential Thinking** - Step-by-step reasoning
Usage: `Debug this issue using sequential thinking`
[Details →](plugins/hal-9000/mcp-servers/sequential-thinking/)

**DEVONthink** (macOS) - Document search and import
Usage: `Search my DEVONthink for ML papers`, `Import arXiv paper 2312.03032`
[Details →](plugins/hal-9000/mcp-servers/devonthink/README.md)

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

**For aod:**
- Docker
- tmux (auto-installed if missing)
- git

## Troubleshooting

**Installation Issues?** See the [Troubleshooting Guide](plugins/hal-9000/TROUBLESHOOTING.md) for:
- PEP 668 errors on modern Linux distributions
- Python package installation problems
- PATH configuration issues
- Platform-specific solutions (macOS, Linux, Docker)

**Common Issues:**
- **Debian/Ubuntu PEP 668 Error**: Automatically handled by installer (v1.1.0+)
- **Command not found after install**: Add `~/.local/bin` to your PATH
- **SSL Certificate errors**: Update certificates or use trusted hosts

[Full troubleshooting guide →](plugins/hal-9000/TROUBLESHOOTING.md)

**Optional:**
- macOS + DEVONthink Pro/Server (for DEVONthink MCP)
- SOPS (for vault encryption)

## Troubleshooting

**MCP servers not appearing:**
- Restart Claude Code completely (⌘Q)
- Check config: `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json`

**aod sessions not starting:**
- Verify Docker is running: `docker ps`
- Check tmux is installed: `which tmux`
- Try: `aod-cleanup` then retry

**Python/Node commands not found:**
- Add to PATH: `export PATH="$HOME/.local/bin:$PATH"`
- Restart shell or `source ~/.bashrc`

**Installation fails:**
- Check prerequisites: `python3 --version`, `node --version`
- Re-run installer (prompts before overwriting)
- Check logs for specific errors

[Complete troubleshooting guide →](docs/TROUBLESHOOTING.md)

## Foundation Tools

aod uses ClaudeBox for containerization:

**ClaudeBox** - Containerized development: `claudebox run --profile python`

## Documentation

- **[Cheat Sheet](plugins/hal-9000/CHEATSHEET.md)** - Quick reference for aod, tmux, tmux-cli, and terminal tools
- [aod (Army of Darkness)](plugins/hal-9000/aod/README.md)
- [Agent Usage](plugins/hal-9000/AGENTS.md)
- [ChromaDB MCP](plugins/hal-9000/mcp-servers/chromadb/README.md)
- [Memory Bank MCP](plugins/hal-9000/mcp-servers/memory-bank/README.md)
- [Sequential Thinking MCP](plugins/hal-9000/mcp-servers/sequential-thinking/)
- [DEVONthink MCP](plugins/hal-9000/mcp-servers/devonthink/README.md)

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
