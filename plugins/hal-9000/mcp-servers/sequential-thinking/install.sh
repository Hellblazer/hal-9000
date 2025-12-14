#!/usr/bin/env bash
set -euo pipefail

echo "Installing Sequential Thinking MCP Server..."
echo ""

# Check if Sequential Thinking MCP is already installed
if command -v claude &> /dev/null && claude mcp list 2>/dev/null | grep -q "sequential-thinking"; then
    echo "⚠️  Sequential Thinking MCP server is already configured"
    echo ""
    read -p "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping Sequential Thinking installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
fi

# Check for npx
if ! command -v npx &> /dev/null; then
    echo "Error: npx not found. Please install Node.js first."
    exit 1
fi

# Test installation
echo "Testing sequential-thinking MCP server..."
if npx -y @modelcontextprotocol/server-sequential-thinking --help &> /dev/null; then
    echo "✓ Sequential Thinking MCP server is available"
else
    echo "Note: Will be installed via npx on first use"
fi

# Configuration snippet
echo ""
echo "Sequential Thinking MCP Configuration:"
echo ""
cat << 'EOF'
Add to Claude Code settings.json:

"mcpServers": {
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  }
}
EOF

echo ""
echo "✓ Sequential Thinking MCP setup complete"
echo ""
