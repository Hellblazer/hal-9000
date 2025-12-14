# ChromaDB MCP Server

Vector database for semantic search and knowledge management.

## Features

- Semantic search by meaning, not just keywords
- Document storage with embeddings
- Version tracking for documents
- Collections for organization
- Hybrid search combining semantic and keyword matching

## Use Cases

- Store research findings
- Build personal knowledge base
- Track concepts and ideas
- Find related documents
- Maintain project context across sessions

## Installation

Run the installation script:

```bash
./install.sh
```

Installs the chroma-mcp package via pip.

## Configuration

### Cloud Mode

Uses ChromaDB Cloud for cross-machine access. Requires:
1. ChromaDB Cloud account (https://www.trychroma.com/)
2. Tenant ID
3. Database name
4. API key

Set environment variables or update the configuration before installation.

### Local Mode

For local-only storage:

```json
{
  "mcpServers": {
    "chromadb": {
      "command": "/path/to/chroma-mcp",
      "args": [
        "--client-type", "local",
        "--path", "/Users/yourusername/.chromadb"
      ]
    }
  }
}
```

## Available Tools

- `create_document` - Store documents
- `read_document` - Retrieve by ID
- `update_document` - Modify documents
- `delete_document` - Remove documents
- `search_similar` - Find semantically similar documents
- `hybrid_search` - Combined semantic and keyword search
- `create_collection` - Organize documents
- `list_collections` - View collections
- `bulk_create_documents` - Batch operations

## Prerequisites

- Python 3.8+
- pip

## Troubleshooting

### Command not found: chroma-mcp

Add Python bin directory to PATH:

```bash
export PATH="$HOME/Library/Python/3.10/bin:$PATH"
```

Add to `.zshrc` or `.bashrc` to persist.

### Connection errors

Cloud mode:
- Verify API key
- Check tenant ID and database name
- Ensure internet connection

## Links

- [ChromaDB Documentation](https://docs.trychroma.com/)
- [ChromaDB Cloud](https://www.trychroma.com/)
- [MCP Server Source](https://github.com/chroma-core/chroma-mcp)
