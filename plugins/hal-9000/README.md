# HAL-9000 Plugin

Productivity tools for Claude Code including MCP servers, custom agents, terminal automation, and development environments.

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

### Custom Agents

12 specialized agent configurations for Java development, code review, research, and analysis. Installed to `~/.claude/agents/`. See AGENTS.md for details.

### Session Commands

- `/check` - Save session context
- `/load` - Resume session
- `/sessions` - List sessions
- `/session-delete` - Delete session

### Terminal Tools

- **tmux-cli** - Terminal automation for interactive CLIs
- **vault** - Encrypted .env backup with SOPS
- **env-safe** - Safe .env inspection
- **find-session** - Search across agent sessions
- **Safety hooks** - Git, file, and environment protection

### Development Environments

- **ClaudeBox** - Docker-based containerized development
- **Claude Squad** - Multi-agent terminal UI
- **ClaudeBox Squad** - Multi-branch parallel development with git worktrees and isolated containers

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

Requires dt-mcp repository:
```bash
git clone https://github.com/yourusername/dt-mcp.git ~/git/dt-mcp
cd ~/git/dt-mcp
npm install
```

## Usage

### MCP Servers

ChromaDB and Memory Bank tools become available automatically. Use naturally in prompts:
```
Store this in ChromaDB with ID "design-notes"
Save this decision to memory bank project "my-app"
```

### Custom Agents

Launch via Task tool:
```
Use java-developer agent to implement UserService
Use code-review-expert agent to review PaymentService
```

### Terminal Tools

```bash
tmux-cli launch "python -m pdb script.py"
vault backup .env
find-session "auth implementation"
```

### ClaudeBox

```bash
claudebox run
claudebox run --profile python
```

### Claude Squad

```bash
cs                # Launch with Claude Code
cs -p "aider"     # Launch with Aider
```

### ClaudeBox Squad

```bash
# Create configuration for multiple branches
cat > squad.conf <<EOF
feature/auth:python:Add authentication
feature/api:node:Build REST API
EOF

# Launch all sessions
claudebox-squad squad.conf

# Manage sessions
cs-list           # List active sessions
cs-attach squad-feature-auth  # Attach to session
cs-cleanup        # Stop all sessions
```

## Documentation

- MCP Servers: `mcp-servers/*/README.md`
- Agents: `AGENTS.md`
- Commands: `commands/*.md`
- ClaudeBox Squad: `claudebox-squad/README.md`

## Troubleshooting

### MCP servers not available
- Restart Claude Code
- Check environment variables are set
- Verify prerequisites installed

### Agents not found
- Check `~/.claude/agents/` contains .md files
- Restart Claude Code

### Commands not working
- Check `~/.claude/commands/` contains .md files
- Try `/help` to see available commands
