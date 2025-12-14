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

1. Clone this repository:
   ```bash
   git clone https://github.com/hal.hildebrand/hal-9000.git
   ```

2. Add to Claude Code:
   - Open Claude Code settings
   - Navigate to Marketplaces
   - Add local marketplace: `/path/to/hal-9000`

3. Install the plugin:
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
- Document research integration
- Knowledge graph construction
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

Slash commands for session management:
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
- Isolated git worktrees per task
- Background task completion
- Supports Claude Code, Codex, Gemini, Aider

## Requirements

### Required
- Python 3.8+ (ChromaDB)
- Node.js 16+ (Memory Bank, Sequential Thinking)
- Bash shell

### Host Mode Additional
- Docker (ClaudeBox)
- tmux (auto-installed if missing)
- gh - GitHub CLI (auto-installed if missing)

### Optional
- macOS + DEVONthink Pro/Server (DEVONthink MCP)
- SOPS (vault encryption)
- jq (config merging)

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

Requires dt-mcp repository:
```bash
git clone https://github.com/yourusername/dt-mcp.git ~/git/dt-mcp
cd ~/git/dt-mcp
npm install
```

The installer can handle this if needed.

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

## Documentation

- [hal-9000 Plugin](plugins/hal-9000/README.md)
- [Agent Usage](plugins/hal-9000/AGENTS.md)
- [ChromaDB MCP](plugins/hal-9000/mcp-servers/chromadb/README.md)
- [Memory Bank MCP](plugins/hal-9000/mcp-servers/memory-bank/README.md)
- [Sequential Thinking MCP](plugins/hal-9000/mcp-servers/sequential-thinking/)
- [DEVONthink MCP](plugins/hal-9000/mcp-servers/devonthink/README.md)

## Troubleshooting

### Marketplace not showing
- Verify path in Claude Code settings
- Check `.claude-plugin/marketplace.json` exists
- Restart Claude Code

### Plugin installation fails
- Check prerequisites are installed
- Review post-installation instructions
- Check Claude Code logs

### MCP servers not working
- Restart Claude Code after installation
- Verify environment variables are set
- Check individual MCP server READMEs

## License

Apache 2.0

## Acknowledgments

- ChromaDB: [Chroma](https://www.trychroma.com/)
- Memory Bank: [@allpepper/memory-bank-mcp](https://github.com/allpepper/memory-bank-mcp)
- Claude Code Tools: [claude-code-tools](https://github.com/pchalasani/claude-code-tools)
- ClaudeBox: [Hellblazer/claudebox](https://github.com/Hellblazer/claudebox)
- Claude Squad: [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad)
