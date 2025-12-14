#!/usr/bin/env bash
set -euo pipefail

echo "Installing DEVONthink MCP Server..."

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: DEVONthink MCP Server only works on macOS"
    exit 1
fi

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    echo "Install Node.js: https://nodejs.org/"
    exit 1
fi

# Check Node version
NODE_VERSION=$(node --version | sed 's/v//' | cut -d'.' -f1)
REQUIRED_VERSION=16

if [ "$NODE_VERSION" -lt "$REQUIRED_VERSION" ]; then
    echo "Error: Node.js $REQUIRED_VERSION or higher is required. Found: v$NODE_VERSION"
    exit 1
fi

# Check for DEVONthink
if ! osascript -e 'application "DEVONthink 3" is running' 2>/dev/null; then
    echo "Warning: DEVONthink 3 is not running."
    echo "Start DEVONthink before using this MCP server."
fi

# Check for dt-mcp repository
DT_MCP_DIR="$HOME/git/dt-mcp"
if [ ! -d "$DT_MCP_DIR" ]; then
    echo "Error: dt-mcp repository not found at $DT_MCP_DIR"
    echo ""
    echo "Please clone the dt-mcp repository first:"
    echo "  git clone https://github.com/yourusername/dt-mcp.git $DT_MCP_DIR"
    echo "  cd $DT_MCP_DIR"
    echo "  npm install"
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "$DT_MCP_DIR/node_modules" ]; then
    echo "Installing dt-mcp dependencies..."
    cd "$DT_MCP_DIR"
    npm install
fi

echo "✅ DEVONthink MCP Server is ready!"
echo ""
echo "Server location: $DT_MCP_DIR/server.js"
echo ""
echo "Next steps:"
echo "1. Ensure DEVONthink is running"
echo "2. Edit config.json to set the correct path to server.js"
echo "3. Merge config.json into ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "4. Restart Claude Code/Desktop"
echo "5. Grant automation permissions if prompted"
