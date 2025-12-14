# HAL-9000 Claude Marketplace

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) providing MCP servers, custom agents, and development tools.

## Overview

HAL-9000 is a single plugin that bundles:
- MCP servers (ChromaDB, Memory Bank, Sequential Thinking, DEVONthink)
- Custom agent configurations (12 specialized agents)
- Session management commands
- Terminal automation tools (tmux-cli, vault, env-safe)
- Safety hooks for git, files, and environment variables
- Docker development environments (ClaudeBox)
- Multi-agent orchestration (Claude Squad)

## Installation

### Add Marketplace

1. Add to Claude Code:
   - Open Claude Code settings
   - Navigate to Marketplaces
   - Add marketplace URL: `https://github.com/Hellblazer/hal-9000.git`

2. Install the plugin:
   - Browse hal-9000 marketplace in Claude Code
   - Install "hal-9000" plugin
   - Run the installation script when prompted

### Installation Modes

The installer provides three modes:

**Mode 1: Complete** (default)
- Installs on host machine
- Also installs to `~/.claudebox/hal-9000` for container sharing
- ClaudeBox containers mount and inherit components

**Mode 2: Host Only**
- Installs only on host machine
- Skips ClaudeBox shared directory

**Mode 3: ClaudeBox Shared Only**
- Installs only to `~/.claudebox/hal-9000`
- For custom container setups

### ClaudeBox Container Sharing

Mode 1 installs components to `~/.claudebox/hal-9000/`. ClaudeBox containers mount this as `/hal-9000` and run `/hal-9000/setup.sh` to configure. MCP servers, agents, commands, and tools become available in all containers without reinstalling.

### Safe Installation

MCP server installers check for existing configurations using `claude mcp list`. If a server is already configured, the installer prompts before overwriting. Press N to skip and preserve existing configuration.

## Components

### MCP Servers

**ChromaDB**
- Vector database for semantic search
- Document storage with embeddings
- Hybrid search (semantic and keyword)

**Memory Bank**
- Persistent memory across sessions
- Project-based knowledge organization
- Multi-agent coordination

**Sequential Thinking**
- Step-by-step reasoning tool
- Problem decomposition
- Hypothesis verification

**DEVONthink** (macOS only)
- Document search and import (arXiv, PubMed, DOI)
- Minimal Python implementation (~800 tokens)
- Requires DEVONthink Pro/Server

### Custom Agents

12 specialized agent configurations installed to `~/.claude/agents/`:

**Development**
- java-developer
- java-architect-planner
- java-debugger

**Review & Analysis**
- code-review-expert
- plan-auditor
- deep-analyst
- codebase-deep-analyzer

**Research**
- deep-research-synthesizer
- devonthink-researcher

**Organization**
- knowledge-tidier
- pdf-chromadb-processor
- project-management-setup

See AGENTS.md for usage patterns.

### Session Commands

Custom commands for session management:
- `/check` - Save session context
- `/load` - Resume session
- `/sessions` - List sessions
- `/session-delete` - Delete session

### Terminal Tools

**tmux-cli**
- Terminal automation for interactive CLI apps
- Control debuggers (pdb, gdb)
- Launch multiple Claude instances

**vault**
- Encrypted .env file backup with SOPS
- Secure credential management

**env-safe**
- Safe .env file inspection
- Prevents accidental secret exposure

**find-session**
- Search across all agent sessions
- Cross-project session discovery

**Safety Hooks**
- Git operation protection (add, commit, checkout blocks)
- File operation guards (rm block)
- Environment file protection

### Development Environments

**ClaudeBox**
- Docker-based containerized development
- Pre-configured language profiles
- Project isolation with persistent configs

**Claude Squad**
- Multi-agent terminal UI
- Supports Claude Code, Codex, Gemini, Aider

**ClaudeBox Squad**
- Multi-branch parallel development
- Git worktrees with isolated containers
- Tmux session management
- Bridges ClaudeBox and Claude Squad

## Requirements

### Core Prerequisites
- **Python 3.8+** - For ChromaDB MCP server
- **Node.js 16+** - For Memory Bank and Sequential Thinking MCP servers
- **Bash shell** - For installation and management scripts
- **curl** - Used extensively for downloading components
- **git** - Required for ClaudeBox Squad and repository operations

### Host Mode Additional
- **Docker** - Required for ClaudeBox containerized development
- **tmux** - For ClaudeBox Squad session management (auto-installed if missing)
- **gh** - GitHub CLI (auto-installed if missing)

### Recommended
- **jq** - For config merging (recommended for clean installations)
  - macOS: `brew install jq`
  - Linux: `apt-get install jq`

### Optional
- **macOS + DEVONthink Pro/Server** - For DEVONthink MCP integration
- **SOPS** - For vault encryption features

### System Requirements
- **OS**: macOS or Linux
- **Disk Space**: ~500MB for complete installation
- **Memory**: 2GB minimum for running MCP servers

## Configuration

### ChromaDB

**Cloud Mode:**
Set environment variables:
```bash
CHROMADB_TENANT=your-tenant-id
CHROMADB_DATABASE=your-database-name
CHROMADB_API_KEY=your-api-key
```

Get credentials from [ChromaDB Cloud](https://www.trychroma.com/).

**Local Mode:**
The installer can configure local storage at `~/.chromadb`.

### Memory Bank

Default location: `~/memory-bank`

Override with `MEMORY_BANK_ROOT` environment variable.

### DEVONthink

Python-based MCP server included in hal-9000. No external repository needed.

Requires Python 3.8+ (pre-installed on macOS) and `pip3 install mcp`.

## Usage

### MCP Servers

**ChromaDB:**
```
Store this document in ChromaDB with ID "api-design"
Search ChromaDB for documents about "authentication patterns"
```

**Memory Bank:**
```
Save this decision to memory bank project "my-app"
What did we decide about the database schema?
```

**Sequential Thinking:**
```
Debug this issue using sequential thinking
Break down this architecture decision step by step
```

### Session Commands

```bash
/check oauth-feature Add OAuth2 authentication
/load oauth-feature
/sessions
/session-delete oauth-feature
```

### Terminal Tools

```bash
# Terminal automation
tmux-cli launch "python -m pdb script.py"

# Encrypted backup
vault backup .env

# Session search
find-session "authentication bug"
```

### ClaudeBox

```bash
claudebox run
claudebox run --profile python
```

### Claude Squad

```bash
cs                    # Launch with Claude Code
cs -p "aider"        # Launch with Aider
cs -y                # Auto-accept mode
```

### ClaudeBox Squad

```bash
# Create configuration
cat > squad.conf <<EOF
feature/auth:python:Add authentication
feature/api:node:Build REST API
EOF

# Launch all sessions
claudebox-squad squad.conf

# Manage sessions
cs-list              # List active sessions
cs-attach squad-feature-auth  # Attach to session
cs-cleanup           # Stop all sessions
```

## Documentation

- [hal-9000 Plugin](plugins/hal-9000/README.md)
- [Agent Usage](plugins/hal-9000/AGENTS.md)
- [ClaudeBox Squad](plugins/hal-9000/claudebox-squad/README.md)
- [ChromaDB MCP](plugins/hal-9000/mcp-servers/chromadb/README.md)
- [Memory Bank MCP](plugins/hal-9000/mcp-servers/memory-bank/README.md)
- [Sequential Thinking MCP](plugins/hal-9000/mcp-servers/sequential-thinking/)
- [DEVONthink MCP](plugins/hal-9000/mcp-servers/devonthink/README.md) - Python-based minimal server

## Troubleshooting

### Common Issues

#### Marketplace not showing
- Verify the absolute path in Claude Code settings points to the repository root
- Check that `.claude-plugin/marketplace.json` exists in the repository
- Restart Claude Code completely
- Check Claude Code logs for marketplace loading errors

#### Plugin installation fails
**Prerequisites missing:**
- Verify Python 3.8+ is installed: `python3 --version`
- Verify Node.js 16+ is installed: `node --version`
- Ensure curl is available: `which curl`
- Check that git is installed: `git --version`

**Installation interrupted:**
- Check if backup was created in `~/.hal-9000-backup-*`
- Re-run the installer - it will prompt before overwriting existing configs
- Review installation logs for specific error messages

**Permission errors:**
- Ensure you have write access to `~/.claude/`
- Check that `~/.local/bin` or Homebrew prefix is writable
- Avoid using `sudo` - installation should run as your user

#### MCP servers not working
**Server not found:**
- Restart Claude Code after installation
- Check that the MCP server command is in your PATH
- For ChromaDB: verify `chroma-mcp` is in Python's user bin directory
- For Memory Bank/Sequential Thinking: ensure `npx` is available

**Environment variables not set:**
- ChromaDB Cloud requires `CHROMADB_TENANT`, `CHROMADB_DATABASE`, `CHROMADB_API_KEY`
- Memory Bank respects `MEMORY_BANK_ROOT` (defaults to `~/memory-bank`)
- Check Claude's config file for correct environment variable syntax

**Configuration conflicts:**
- If you have existing MCP server configs, the installer will prompt before overwriting
- Review `~/.claude/claude_desktop_config.json` (macOS) or `~/.config/Claude/claude_desktop_config.json` (Linux)
- Check for duplicate server names in config

#### Python/Node not in PATH
- After installing Python packages: `export PATH="$HOME/.local/bin:$PATH"`
- Add to shell config (`~/.bashrc`, `~/.zshrc`) for persistence
- The installer can auto-configure PATH if you accept the prompt

#### Docker not running (ClaudeBox)
- Ensure Docker Desktop is running: `docker ps`
- Check Docker daemon: `docker version`
- macOS: Start Docker Desktop application
- Linux: `sudo systemctl start docker`

#### Mid-installation failures
- Check if backup exists: `ls ~/.hal-9000-backup-*`
- Review what was installed: check `~/.claude/commands/`, `~/.claude/agents/`
- Safe to re-run installer - it checks existing installations
- Remove incomplete installs: `./uninstall.sh`

#### Commands not found after installation
- ClaudeBox Squad scripts: check if `~/.local/bin` or Homebrew prefix is in PATH
- Verify scripts are executable: `ls -l ~/.local/bin/claudebox-squad`
- Re-source shell config: `source ~/.bashrc` or `source ~/.zshrc`

#### Git worktree issues (ClaudeBox Squad)
- Failed to remove worktree: Use `git worktree prune` then `rm -rf` the directory
- Worktree already exists: Run `cs-cleanup` to clean all squad sessions
- Permission errors: Check repository permissions

#### ClaudeBox container conflicts
- Port already in use: ClaudeBox Squad uses dynamic slot-based ports
- Container name conflicts: Run `cs-cleanup` to remove all squad containers
- Stuck containers: `docker rm -f $(docker ps -aq --filter "name=claudebox")`

#### Custom agents not appearing
- Check files exist: `ls ~/.claude/agents/*.md`
- Restart Claude Code to reload agent configurations
- Verify file permissions are readable: `chmod 644 ~/.claude/agents/*.md`

## Security

### API Keys and Secrets
HAL-9000 includes tools for secure credential management:

**Using vault for encrypted backups:**
```bash
# Requires SOPS (Mozilla's encryption tool)
vault backup .env                    # Encrypt and backup
vault restore                        # Decrypt and restore
```

**Environment file protection:**
- Safety hooks prevent accidental commits of `.env` files
- `env-safe` tool allows safe inspection without revealing secrets
- Always use environment variables for API keys, never hardcode

**Configuring ChromaDB API keys securely:**
```bash
# Add to your shell profile (~/.bashrc or ~/.zshrc)
export CHROMADB_TENANT="your-tenant-id"
export CHROMADB_DATABASE="your-database"
export CHROMADB_API_KEY="your-api-key"
```

**Best practices:**
- Never commit secrets to git repositories
- Use vault tool to maintain encrypted backups of .env files
- Review `.gitignore` to ensure sensitive files are excluded
- Regularly rotate API keys and credentials
- Use separate credentials for development vs production

**Warning about repository commits:**
- Safety hooks will block `git add` on .env files
- Review files before committing: `git status`, `git diff --cached`
- HAL-9000 safety hooks help prevent accidental secret exposure

## License

Apache 2.0

## Acknowledgments

- ChromaDB: [Chroma](https://www.trychroma.com/)
- Memory Bank: [@allpepper/memory-bank-mcp](https://github.com/allpepper/memory-bank-mcp)
- Claude Code Tools: [claude-code-tools](https://github.com/pchalasani/claude-code-tools)
- ClaudeBox: [RchGrav/claudebox](https://github.com/RchGrav/claudebox)
- Claude Squad: [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad)
