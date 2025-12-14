# HAL-9000: Hellbound Claude Marketplace

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) providing MCP servers and productivity tools.

## What is This?

HAL-9000 is a **Claude Code plugin marketplace** that you can add to Claude Code to install powerful extensions:

- **hal-9000 plugin**: All-in-one MCP server suite (ChromaDB, Memory Bank, DEVONthink)
- **session-tools plugin**: Session management commands for workflow continuity

## Installation

### Add Marketplace to Claude Code

1. **Clone this repository**:
   ```bash
   git clone https://github.com/hal.hildebrand/hal-9000.git
   ```

2. **Add marketplace in Claude Code**:
   - Open Claude Code settings
   - Navigate to Marketplaces
   - Add local marketplace: `/path/to/hal-9000`

3. **Install plugins**:
   - Browse the hal-9000 marketplace in Claude Code
   - Install "hal-9000" plugin for MCP servers
   - Install "session-tools" plugin for session management
   - Follow post-installation instructions

### Quick Setup (Alternative)

If you want to install without using the marketplace feature, use the legacy installer:

```bash
cd hal-9000
./install.sh
```

## Available Plugins

### 🔌 hal-9000 Plugin

All-in-one MCP server suite:

**ChromaDB**
- Vector database for semantic search
- Document storage with embeddings
- Hybrid search (semantic + keyword)

**Memory Bank**
- Persistent memory across sessions
- Project-based knowledge organization
- Agent coordination

**DEVONthink** (macOS only)
- Document research integration
- Knowledge graph construction
- AI-powered analysis

[Full Documentation](plugins/hal-9000/README.md)

### ⚡ session-tools Plugin

Session management commands:

- `/check` - Save session context
- `/load` - Resume saved session
- `/sessions` - List all sessions
- `/session-delete` - Delete session

[Full Documentation](plugins/session-tools/README.md)

### 🎯 hell-agents Plugin

Specialized Claude Code agent configurations and workflows:

**Development Agents**
- java-developer, java-architect-planner, java-debugger

**Review & Analysis Agents**
- code-review-expert, plan-auditor, deep-analyst, codebase-deep-analyzer

**Research & Exploration Agents**
- Explore, deep-research-synthesizer, devonthink-researcher

**Planning & Organization Agents**
- Plan, project-management-setup, knowledge-tidier

[Full Documentation](plugins/hell-agents/README.md)

### 🛠️ claude-code-tools Plugin

Comprehensive toolkit for enhancing Claude Code:

**tmux-cli** - Terminal automation ("Playwright for terminals")
- Control interactive CLI applications
- Debug with pdb/gdb
- Launch multiple Claude instances
- Test interactive scripts

**Session Search**
- find-session: Unified search across all agents
- find-claude-session: Claude-specific search
- Cross-project session discovery

**Security & Safety**
- vault: Encrypted .env backup with SOPS
- env-safe: Safe .env inspection
- Safety hooks: Git, file, and environment protection

**Optional: lmsh** - Natural language shell (requires Rust)

[Full Documentation](plugins/claude-code-tools/README.md)

## Requirements

### hal-9000 Plugin
- **ChromaDB**: Python 3.8+
- **Memory Bank**: Node.js 16+
- **DEVONthink**: macOS, DEVONthink Pro/Server, dt-mcp repository

### session-tools Plugin
- Bash shell
- Git (optional, for git status)

### claude-code-tools Plugin
- **Required**: Python 3.11+, uv, tmux
- **Optional**: SOPS (for vault), jq (for auto-config), Rust/Cargo (for lmsh)

## Configuration

### ChromaDB Cloud Setup

Set environment variables in Claude Code:
```
CHROMADB_TENANT=your-tenant-id
CHROMADB_DATABASE=your-database-name
CHROMADB_API_KEY=your-api-key
```

Get these from [ChromaDB Cloud](https://www.trychroma.com/)

### ChromaDB Local Setup

Edit plugin config to use local mode:
```json
{
  "args": ["--client-type", "local", "--path", "${HOME}/.chromadb"]
}
```

### Memory Bank Location

Default: `~/memory-bank`

To change, update `MEMORY_BANK_ROOT` environment variable.

### DEVONthink Setup

Clone and install dt-mcp:
```bash
git clone https://github.com/yourusername/dt-mcp.git ~/git/dt-mcp
cd ~/git/dt-mcp
npm install
```

## Usage Examples

### With ChromaDB
```
Store this document in ChromaDB with ID "api-design-notes"
Search ChromaDB for documents similar to "authentication patterns"
```

### With Memory Bank
```
Save this architecture decision to memory bank project "my-app"
What did we decide about the database schema? (checks memory bank)
```

### With DEVONthink
```
Search DEVONthink for papers on "quantum computing"
Analyze these 5 documents and extract common themes
Build a knowledge graph from my research database
```

### With Session Tools
```
/check oauth-feature Add OAuth2 authentication flow
/load oauth-feature
/sessions
```

## Additional Resources

### CLAUDE.md Templates

The `templates/` directory contains CLAUDE.md templates for different project types:
- Java projects (Maven/Gradle)
- TypeScript projects (Node.js/React)
- Python projects (pip/poetry)

Copy a template to your project root and customize it.

### Documentation

- [hal-9000 Plugin](plugins/hal-9000/README.md)
- [session-tools Plugin](plugins/session-tools/README.md)
- [ChromaDB MCP](plugins/hal-9000/mcp-servers/chromadb/README.md)
- [Memory Bank MCP](plugins/hal-9000/mcp-servers/memory-bank/README.md)
- [DEVONthink MCP](plugins/hal-9000/mcp-servers/devonthink/README.md)

## Marketplace Structure

```
hal-9000/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition
├── plugins/
│   ├── hal-9000/                 # MCP server suite
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── mcp-servers/          # Individual MCP docs
│   │   └── README.md
│   └── session-tools/            # Session commands
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/             # Command files
│       └── README.md
├── templates/                    # CLAUDE.md templates
└── README.md
```

## Troubleshooting

### Marketplace not showing up
- Verify path is correct in Claude Code settings
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

## Contributing

Contributions welcome! To add a plugin:

1. Create plugin directory in `plugins/`
2. Add `.claude-plugin/plugin.json`
3. Update `.claude-plugin/marketplace.json`
4. Add documentation
5. Submit PR

## License

Apache 2.0 - See [LICENSE](LICENSE)

## Acknowledgments

Built for the Claude Code community.

- ChromaDB: [Chroma](https://www.trychroma.com/)
- Memory Bank: [@allpepper/memory-bank-mcp](https://github.com/allpepper/memory-bank-mcp)
- Session tools: Inspired by tmux session management
