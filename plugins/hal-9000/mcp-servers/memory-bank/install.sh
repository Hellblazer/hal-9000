#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Memory Bank MCP Server...${NC}"
echo ""

# Check if Memory Bank MCP is already installed
if command -v claude &> /dev/null && claude mcp list 2>/dev/null | grep -q "memory-bank\|allPepper-memory-bank"; then
    echo -e "${YELLOW}⚠️  Memory Bank MCP server is already configured${NC}"
    echo ""
    read -p "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping Memory Bank installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
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

echo -e "${BLUE}Memory Bank Configuration${NC}"
echo ""
read -p "Memory bank directory [$HOME/memory-bank]: " MEMORY_BANK_DIR
MEMORY_BANK_DIR=${MEMORY_BANK_DIR:-$HOME/memory-bank}

# Create memory bank directory if it doesn't exist
if [ ! -d "$MEMORY_BANK_DIR" ]; then
    echo "Creating memory bank directory at $MEMORY_BANK_DIR..."
    mkdir -p "$MEMORY_BANK_DIR"
else
    echo "Using existing directory: $MEMORY_BANK_DIR"
fi

# Install the package
echo ""
echo "Installing @allpepper/memory-bank-mcp..."
npm install -g @allpepper/memory-bank-mcp@latest

# Create config snippet
CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "allPepper-memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp@latest"],
      "env": {
        "MEMORY_BANK_ROOT": "$MEMORY_BANK_DIR"
      }
    }
  }
}
EOF
)

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
    read -p "Automatically merge Memory Bank config into Claude? (y/N): " AUTO_MERGE

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
echo -e "${GREEN}✅ Memory Bank MCP Server installed successfully!${NC}"
echo ""
echo "Memory bank directory: $MEMORY_BANK_DIR"
echo ""
echo "Next step: Restart Claude Code or Claude Desktop to load the MCP server"
echo ""
