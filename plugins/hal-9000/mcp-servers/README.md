# MCP Servers

MCP (Model Context Protocol) servers extend Claude Code with additional capabilities.

## Available Servers

### ChromaDB
Vector database for semantic search and document storage.

**Location**: `chromadb/`

### Memory Bank
Project-based persistent memory across Claude Code sessions.

**Location**: `memory-bank/`

### Sequential Thinking
Step-by-step reasoning for complex problem solving.

Installed via npm on demand - no local directory.

### DEVONthink
Document research and knowledge synthesis. Requires DEVONthink Pro/Server (macOS only).

**Location**: `devonthink/`

## Installation

Each server directory contains:
- `install.sh` - Dependency installation
- `config.json` - MCP server configuration
- `README.md` - Usage documentation

### Install All

```bash
cd mcp-servers
for dir in */; do
    cd "$dir"
    ./install.sh
    cd ..
done
```

### Install Individual

```bash
cd mcp-servers/chromadb
./install.sh
```

The install script merges `config.json` into Claude's MCP configuration automatically.

## Configuration Location

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

Configuration structure:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {}
    }
  }
}
```

## Restart Required

Restart Claude Code after installation to load new MCP servers.
