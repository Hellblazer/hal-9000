# HAL-9000 Plugin

All-in-one MCP server suite for Claude Code.

## What's Included

### ChromaDB
Vector database for semantic search and knowledge management
- Store documents with semantic embeddings
- Search by meaning, not just keywords
- Version tracking and collections

### Memory Bank
Persistent memory across Claude Code sessions
- Project-based knowledge organization
- Maintain context between conversations
- Coordinate between parallel agents

### DEVONthink
Document research and knowledge synthesis
- Search across DEVONthink databases
- AI-powered document analysis
- Knowledge graph construction

## Installation

This plugin will be installed automatically through the hal-9000 marketplace.

### Prerequisites

- **ChromaDB**: Python 3.8+, ChromaDB Cloud account (or local setup)
- **Memory Bank**: Node.js 16+
- **DEVONthink**: macOS, DEVONthink Pro/Server, dt-mcp server

### Post-Installation

1. **Configure ChromaDB** (if using cloud):
   Set environment variables in Claude Code settings:
   ```
   CHROMADB_TENANT=your-tenant-id
   CHROMADB_DATABASE=your-database-name
   CHROMADB_API_KEY=your-api-key
   ```

2. **Set up DEVONthink**:
   Clone dt-mcp repository:
   ```bash
   git clone https://github.com/yourusername/dt-mcp.git ~/git/dt-mcp
   cd ~/git/dt-mcp
   npm install
   ```

3. **Restart Claude Code**

## Usage

Once installed, Claude Code will have access to:

- ChromaDB tools: `create_document`, `search_similar`, `hybrid_search`, etc.
- Memory Bank tools: `memory_bank_read`, `memory_bank_write`, `list_projects`, etc.
- DEVONthink tools: `search`, `analyze`, `graph`, `research`, etc.

See `mcp-servers/` subdirectories for detailed documentation on each MCP server.

## Configuration

### ChromaDB Local Mode

To use local ChromaDB instead of cloud:

Edit the plugin's MCP server configuration to use:
```json
{
  "command": "${HOME}/Library/Python/3.10/bin/chroma-mcp",
  "args": ["--client-type", "local", "--path", "${HOME}/.chromadb"]
}
```

### Custom Memory Bank Location

Change `MEMORY_BANK_ROOT` environment variable to your preferred location.

## Troubleshooting

See individual MCP server READMEs in `mcp-servers/` for specific troubleshooting guides.
