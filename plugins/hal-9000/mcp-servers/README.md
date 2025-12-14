# MCP Servers

This directory contains pre-configured MCP (Model Context Protocol) servers that extend Claude Code's capabilities.

## Available Servers

### ChromaDB
Vector database for semantic search and knowledge management. Stores documents and enables semantic similarity searches.

**Location**: `chromadb/`

### Memory Bank (allPepper)
Persistent memory system for maintaining project context across Claude Code sessions. Organizes knowledge by projects.

**Location**: `memory-bank/`

### DEVONthink
Integration with DEVONthink for document research, knowledge synthesis, and information retrieval.

**Location**: `devonthink/`

## Installation

Each server has its own directory with:
- `install.sh` - Installation script for dependencies
- `config.json` - MCP server configuration snippet
- `README.md` - Detailed documentation

### Quick Install All

```bash
cd mcp-servers
for dir in */; do
    cd "$dir"
    ./install.sh
    cd ..
done
```

### Individual Installation

```bash
cd mcp-servers/chromadb
./install.sh
```

Then manually merge the `config.json` into your `~/Library/Application Support/Claude/claude_desktop_config.json` under the `mcpServers` key.

## Configuration Location

MCP servers are configured in:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

The configuration file has this structure:

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

After installing MCP servers, restart Claude Code (or Claude Desktop) to load the new configurations.
