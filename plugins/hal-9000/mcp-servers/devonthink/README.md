# DEVONthink MCP Server

Minimal Python-based MCP server providing Claude direct access to DEVONthink databases.

## Features

- **Search** - Advanced DEVONthink search with Boolean operators, field searches, wildcards
- **Read** - Get document content and metadata by UUID
- **Create** - Create new markdown, text, or RTF documents
- **Import** - Import from URLs and academic papers (arXiv, PubMed, DOI)

## Requirements

- macOS (DEVONthink is macOS-only)
- Python 3.8+ (pre-installed on macOS)
- DEVONthink 3.x or 4.x
- MCP Python package (installed automatically)

## Installation

Run the installer from hal-9000 plugin installation, or manually:

```bash
cd mcp-servers/devonthink
./install.sh
```

This will:
1. Install Python dependencies (`pip3 install mcp`)
2. Configure Claude to use the Python server
3. Set up automation permissions

## Configuration

The installer configures Claude to run:

```json
{
  "mcpServers": {
    "devonthink": {
      "command": "python3",
      "args": ["/path/to/server.py"]
    }
  }
}
```

## Usage

### Search Documents

```
Search my DEVONthink for documents about machine learning
Find papers tagged with "research" from 2023
```

Advanced syntax:
- Boolean: `quantum AND physics`, `AI OR ML`
- Field: `tag:research AND kind:PDF`
- Wildcards: `neural*`
- Phrases: `"exact phrase"`

### Read Documents

```
Show me the content of document ABC-123-DEF
```

Documents are identified by UUID (shown in search results).

### Create Documents

```
Create a markdown note in DEVONthink with my meeting summary
```

Supports markdown, plain text, and RTF formats.

### Import Documents

```
Import this arXiv paper: 2312.03032
Import from DOI: 10.1000/xyz123
Import this URL: https://example.com/paper.pdf
```

Automatically downloads and imports to DEVONthink.

## Architecture

Minimal implementation:
- **server.py** - ~450 lines, 3 MCP tools
- **scripts/minimal/** - 4 AppleScripts (~150 lines each)
  - search.applescript
  - read.applescript
  - create.applescript
  - import.applescript

Total: ~600 lines of code, ~800 tokens context overhead.

## Troubleshooting

### Tools not appearing in Claude

1. Verify config path: `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json`
2. Check Python: `which python3`
3. Verify MCP installed: `pip3 list | grep mcp`
4. Restart Claude completely (⌘Q)

### Import not working

1. Ensure DEVONthink is running
2. Check network connection
3. Test AppleScript: `osascript scripts/minimal/import.applescript "https://arxiv.org/pdf/2312.03032.pdf" "test"`

### Permission errors

Grant automation permissions:
- System Settings → Privacy & Security → Automation
- Enable "Terminal" or "Claude" to control DEVONthink

## Testing

Test the server:

```bash
# Verify server loads
python3 -c "import sys; sys.path.insert(0, '.'); import server; print('✓ Server loads')"

# Test search AppleScript
osascript scripts/minimal/search.applescript "test" "" 10

# Test import
osascript scripts/minimal/import.applescript "https://example.com/doc.pdf" "test-tag"
```

## Why Python?

This version uses Python instead of Node.js because:
- Python comes pre-installed on macOS
- Single dependency (`pip3 install mcp`)
- Smaller footprint (~800 tokens vs 4000+)
- Simpler codebase, easier to maintain

## License

MIT License

## Credits

Built for use with Claude Code and Claude Desktop.

Developed for the hal-9000 marketplace.
