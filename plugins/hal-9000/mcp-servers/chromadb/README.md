# ChromaDB MCP Server

Vector database for semantic search and knowledge management in Claude Code.

## What It Does

ChromaDB enables:
- **Semantic Search**: Find documents by meaning, not just keywords
- **Knowledge Management**: Store and retrieve information contextually
- **Document Versioning**: Track changes to documents over time
- **Collections**: Organize documents into logical groups
- **Hybrid Search**: Combine semantic and keyword matching

## Use Cases

- Store research findings for long-running projects
- Build a personal knowledge base
- Track evolving concepts and ideas
- Find related documents across large collections
- Maintain project-specific context across sessions

## Installation

Run the installation script:

```bash
./install.sh
```

This will install the chroma-mcp package via pip.

## Configuration

### Cloud Mode (Recommended for sharing across machines)

The provided `config.json` uses ChromaDB Cloud. You'll need:
1. A ChromaDB Cloud account (https://www.trychroma.com/)
2. Your tenant ID
3. Your database name
4. An API key

Update the configuration with your credentials before merging into Claude's config.

### Local Mode (For local-only storage)

Alternatively, use local storage:

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

Once installed, Claude Code can use:
- `create_document` - Store new documents
- `read_document` - Retrieve documents by ID
- `update_document` - Modify existing documents
- `delete_document` - Remove documents
- `search_similar` - Find semantically similar documents
- `hybrid_search` - Combined semantic + keyword search
- `create_collection` - Organize documents
- `list_collections` - View all collections
- `bulk_create_documents` - Batch document creation

## Prerequisites

- Python 3.8 or higher
- pip

## Troubleshooting

### Command not found: chroma-mcp

The install script adds the Python bin directory to your PATH. If it's still not found:

```bash
export PATH="$HOME/Library/Python/3.10/bin:$PATH"
```

Add this to your `.zshrc` or `.bashrc` to make it permanent.

### Connection errors

If using ChromaDB Cloud:
- Verify your API key is correct
- Check tenant ID and database name
- Ensure you have an active internet connection

## Links

- [ChromaDB Documentation](https://docs.trychroma.com/)
- [ChromaDB Cloud](https://www.trychroma.com/)
- [MCP Server Source](https://github.com/chroma-core/chroma-mcp)
