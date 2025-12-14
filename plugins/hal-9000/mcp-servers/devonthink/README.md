# DEVONthink MCP Server

Integration with DEVONthink for document research and knowledge synthesis.

## Features

- Document search across DEVONthink databases
- Document analysis (summarize, extract themes, compare)
- Knowledge graph construction and traversal
- Smart organization (auto-organize, create groups)
- Research workflows (explore topics, track evolution)
- Batch operations

## Use Cases

- Research topics across document collections
- Synthesize information from multiple sources
- Track topic evolution over time
- Organize large document repositories
- Extract insights from PDFs, web archives, notes
- Build knowledge graphs from research

## Prerequisites

- **macOS**: DEVONthink MCP only works on macOS
- **DEVONthink**: Pro or Server installed and running
- **Node.js**: 16+
- **dt-mcp server**: Custom MCP server for DEVONthink

## Installation

Requires the `dt-mcp` repository:

```bash
# Clone the dt-mcp repository
git clone https://github.com/yourusername/dt-mcp.git ~/git/dt-mcp

# Install dependencies
cd ~/git/dt-mcp
npm install

# Run the installation script
cd ~/git/hal-9000/mcp-servers/devonthink
./install.sh
```

Contact the repository maintainer if you don't have access to dt-mcp.

## Configuration

The `config.json` points to the dt-mcp server location. Update the path if you cloned dt-mcp to a different directory.

## Available Tools

### Search & Retrieval
- `search` - Basic, advanced, batch, smart group searches
- `document` - Read, create, update, delete, OCR documents

### Analysis & Synthesis
- `analyze` - Summarize, extract themes, compare, classify documents
- `graph` - Build knowledge graphs, find paths, detect clusters
- `ai` - AI-powered classification and similarity detection

### Organization
- `organize` - Create groups, collections, bulk tag, auto-organize
- `import` - Import URLs, papers (arXiv, DOI, PubMed), batch import

### Research
- `research` - Explore topics, organize findings, track evolution, trends

### System
- `system` - List databases, monitor, performance, help

## Example Workflows

### Topic Research
```
Research quantum computing
Organize findings into collections
Build knowledge graph of related concepts
Track evolution over time
```

### Document Analysis
```
Search for papers on specific topic
Analyze to extract themes
Compare related documents
Create summary synthesis
```

## Troubleshooting

### Server not starting

Ensure DEVONthink is running:
```bash
ps aux | grep DEVONthink
```

### Module not found errors

Reinstall dependencies in dt-mcp:
```bash
cd ~/git/dt-mcp
npm install
```

### AppleScript permission denied

Grant Terminal (or your shell) permissions in:
**System Settings → Privacy & Security → Automation → Terminal → DEVONthink**

## Links

- [DEVONthink](https://www.devontechnologies.com/apps/devonthink)
- [MCP Documentation](https://modelcontextprotocol.io/)
