#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing DEVONthink MCP Server...${NC}"
echo ""

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: DEVONthink MCP Server only works on macOS${NC}"
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
    echo -e "${YELLOW}Warning: DEVONthink 3 is not running.${NC}"
    echo "Start DEVONthink before using this MCP server."
    echo ""
fi

echo -e "${BLUE}DEVONthink MCP Configuration${NC}"
echo ""
read -p "dt-mcp repository location [$HOME/git/dt-mcp]: " DT_MCP_DIR
DT_MCP_DIR=${DT_MCP_DIR:-$HOME/git/dt-mcp}

# Check if dt-mcp repository exists
if [ ! -d "$DT_MCP_DIR" ]; then
    echo ""
    echo -e "${YELLOW}dt-mcp repository not found at $DT_MCP_DIR${NC}"
    echo ""
    read -p "Clone dt-mcp repository now? (y/N): " CLONE_REPO

    if [[ "$CLONE_REPO" =~ ^[Yy]$ ]]; then
        read -p "Repository URL [https://github.com/yourusername/dt-mcp.git]: " REPO_URL
        REPO_URL=${REPO_URL:-https://github.com/yourusername/dt-mcp.git}

        # Create parent directory if needed
        mkdir -p "$(dirname "$DT_MCP_DIR")"

        echo ""
        echo "Cloning $REPO_URL to $DT_MCP_DIR..."
        git clone "$REPO_URL" "$DT_MCP_DIR"

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to clone repository${NC}"
            exit 1
        fi
    else
        echo ""
        echo "Please clone the dt-mcp repository manually:"
        echo "  git clone <repository-url> $DT_MCP_DIR"
        echo "  cd $DT_MCP_DIR"
        echo "  npm install"
        echo ""
        echo "Then run this installer again."
        exit 1
    fi
fi

# Check if dependencies are installed
if [ ! -d "$DT_MCP_DIR/node_modules" ]; then
    echo ""
    echo "Installing dt-mcp dependencies..."
    cd "$DT_MCP_DIR"
    npm install

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install dependencies${NC}"
        exit 1
    fi
else
    echo "Dependencies already installed"
fi

# Verify server.js exists
SERVER_PATH="$DT_MCP_DIR/server.js"
if [ ! -f "$SERVER_PATH" ]; then
    echo -e "${RED}Error: server.js not found at $SERVER_PATH${NC}"
    echo "The dt-mcp repository may be incomplete or in the wrong location."
    exit 1
fi

# Create config snippet
CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "devonthink": {
      "command": "node",
      "args": ["$SERVER_PATH"]
    }
  }
}
EOF
)

# Determine Claude config path
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

# Check if Claude config exists
if [ -f "$CLAUDE_CONFIG" ]; then
    echo ""
    echo -e "${YELLOW}Found existing Claude configuration${NC}"
    echo ""
    read -p "Automatically merge DEVONthink config into Claude? (y/N): " AUTO_MERGE

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
echo -e "${GREEN}✅ DEVONthink MCP Server is ready!${NC}"
echo ""
echo "Server location: $SERVER_PATH"
echo ""
echo "Next steps:"
echo "1. Ensure DEVONthink 3 is running"
echo "2. Restart Claude Code or Claude Desktop to load the MCP server"
echo "3. Grant automation permissions if prompted by macOS"
echo ""
