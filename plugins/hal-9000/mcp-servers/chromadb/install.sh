#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing ChromaDB MCP Server...${NC}"
echo ""

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
CHROMA_MCP_PATH="$PYTHON_BIN_DIR/chroma-mcp"

# Check if it's in PATH
if [[ ":$PATH:" != *":$PYTHON_BIN_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  NOTE: The Python bin directory is not in your PATH.${NC}"
    echo "Add this line to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "export PATH=\"$PYTHON_BIN_DIR:\$PATH\""
    echo ""
fi

echo ""
echo -e "${BLUE}ChromaDB Configuration${NC}"
echo ""
echo "Choose ChromaDB client type:"
echo "1) Cloud (ChromaDB Cloud service)"
echo "2) Local (Local ChromaDB instance)"
read -p "Select [1]: " CLIENT_TYPE_CHOICE
CLIENT_TYPE_CHOICE=${CLIENT_TYPE_CHOICE:-1}

if [ "$CLIENT_TYPE_CHOICE" = "1" ]; then
    # Cloud configuration
    echo ""
    echo "Get your ChromaDB Cloud credentials from: https://www.trychroma.com/"
    echo ""
    read -p "Tenant ID: " CHROMADB_TENANT
    read -p "Database name: " CHROMADB_DATABASE
    read -p "API key: " CHROMADB_API_KEY

    # Create config snippet
    CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": [
        "--client-type", "cloud",
        "--tenant", "$CHROMADB_TENANT",
        "--database", "$CHROMADB_DATABASE",
        "--api-key", "$CHROMADB_API_KEY"
      ]
    }
  }
}
EOF
)
else
    # Local configuration
    read -p "ChromaDB path [$HOME/.chromadb]: " CHROMADB_PATH
    CHROMADB_PATH=${CHROMADB_PATH:-$HOME/.chromadb}

    # Create directory if it doesn't exist
    mkdir -p "$CHROMADB_PATH"

    # Create config snippet
    CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": [
        "--client-type", "local",
        "--path", "$CHROMADB_PATH"
      ]
    }
  }
}
EOF
)
fi

# Determine Claude config path
if [[ "$OSTYPE" == "darwin"* ]]; then
    CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
else
    CLAUDE_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
fi

# Check if Claude config exists
if [ -f "$CLAUDE_CONFIG" ]; then
    echo ""
    echo -e "${YELLOW}Found existing Claude configuration${NC}"
    echo ""
    read -p "Automatically merge ChromaDB config into Claude? (y/N): " AUTO_MERGE

    if [[ "$AUTO_MERGE" =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_PATH="${CLAUDE_CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$CLAUDE_CONFIG" "$BACKUP_PATH"
        echo "Backed up to: $BACKUP_PATH"

        # Merge configs using jq if available, otherwise manual
        if command -v jq &> /dev/null; then
            TMP_CONFIG=$(mktemp)
            jq -s '.[0] * .[1]' "$CLAUDE_CONFIG" <(echo "$CONFIG_JSON") > "$TMP_CONFIG"
            mv "$TMP_CONFIG" "$CLAUDE_CONFIG"
            echo -e "${GREEN}✅ Config merged successfully!${NC}"
        else
            echo ""
            echo -e "${YELLOW}jq not found. Please manually merge this config:${NC}"
            echo ""
            echo "$CONFIG_JSON"
            echo ""
            echo "Into: $CLAUDE_CONFIG"
        fi
    else
        echo ""
        echo "Add this to $CLAUDE_CONFIG:"
        echo ""
        echo "$CONFIG_JSON"
    fi
else
    echo ""
    echo "Claude config not found. Creating: $CLAUDE_CONFIG"
    mkdir -p "$(dirname "$CLAUDE_CONFIG")"
    echo "$CONFIG_JSON" > "$CLAUDE_CONFIG"
    echo -e "${GREEN}✅ Config created!${NC}"
fi

echo ""
echo -e "${GREEN}✅ ChromaDB MCP Server installed successfully!${NC}"
echo ""
echo "Next step: Restart Claude Code or Claude Desktop to load the MCP server"
echo ""
