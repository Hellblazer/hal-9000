#!/usr/bin/env bash
set -euo pipefail

echo "Installing Memory Bank MCP Server..."

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

# Create memory bank directory
MEMORY_BANK_DIR="$HOME/memory-bank"
if [ ! -d "$MEMORY_BANK_DIR" ]; then
    echo "Creating memory bank directory at $MEMORY_BANK_DIR..."
    mkdir -p "$MEMORY_BANK_DIR"
fi

# Install the package globally to test
echo "Installing @allpepper/memory-bank-mcp..."
npm install -g @allpepper/memory-bank-mcp@latest

echo "✅ Memory Bank MCP Server installed successfully!"
echo ""
echo "Memory bank directory: $MEMORY_BANK_DIR"
echo ""
echo "Next steps:"
echo "1. Edit config.json to set your memory bank path"
echo "2. Merge config.json into ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "3. Restart Claude Code/Desktop"
