#!/usr/bin/env bash
set -euo pipefail

echo "Installing ChromaDB MCP Server..."

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    echo "Install Python 3: https://www.python.org/downloads/"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Error: Python $REQUIRED_VERSION or higher is required. Found: $PYTHON_VERSION"
    exit 1
fi

# Install chroma-mcp
echo "Installing chroma-mcp via pip..."
pip3 install --user chroma-mcp

# Get the Python bin directory
PYTHON_BIN_DIR=$(python3 -m site --user-base)/bin

# Check if it's in PATH
if [[ ":$PATH:" != *":$PYTHON_BIN_DIR:"* ]]; then
    echo ""
    echo "⚠️  NOTE: The Python bin directory is not in your PATH."
    echo "Add this line to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "export PATH=\"$PYTHON_BIN_DIR:\$PATH\""
    echo ""
fi

echo "✅ ChromaDB MCP Server installed successfully!"
echo ""
echo "Next steps:"
echo "1. Edit config.json with your ChromaDB credentials"
echo "2. Merge config.json into ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "3. Restart Claude Code/Desktop"
