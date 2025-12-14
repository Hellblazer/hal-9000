#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: DEVONthink MCP Server only works on macOS${NC}"
    exit 1
fi

echo -e "${BLUE}Installing DEVONthink MCP Server...${NC}"
echo ""

# Check Node version
check_node_version || exit 1

# Get Claude config path
CLAUDE_CONFIG=$(get_claude_config_path) || exit 1

# Check if already configured
if is_mcp_server_configured "$CLAUDE_CONFIG" "devonthink"; then
    echo -e "${YELLOW}DEVONthink MCP server is already configured${NC}"
    echo ""
    read -rp "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping DEVONthink installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
fi

# Check for DEVONthink
if ! osascript -e 'application "DEVONthink 3" is running' 2>/dev/null; then
    echo -e "${YELLOW}Warning: DEVONthink 3 is not running.${NC}"
    echo "Start DEVONthink before using this MCP server."
    echo ""
fi

echo -e "${BLUE}DEVONthink MCP Configuration${NC}"
echo ""
read -rp "dt-mcp repository location [$HOME/git/dt-mcp]: " DT_MCP_DIR
DT_MCP_DIR=${DT_MCP_DIR:-$HOME/git/dt-mcp}

# Check if dt-mcp repository exists
if [[ ! -d "$DT_MCP_DIR" ]]; then
    echo ""
    echo -e "${YELLOW}dt-mcp repository not found at $DT_MCP_DIR${NC}"
    echo ""
    read -rp "Clone dt-mcp repository now? (y/N): " CLONE_REPO

    if [[ "$CLONE_REPO" =~ ^[Yy]$ ]]; then
        read -rp "Repository URL [https://github.com/yourusername/dt-mcp.git]: " REPO_URL
        REPO_URL=${REPO_URL:-https://github.com/yourusername/dt-mcp.git}

        # Validate inputs
        if [[ -z "$REPO_URL" ]]; then
            echo -e "${RED}Error: Repository URL is required${NC}"
            exit 1
        fi

        # Create parent directory if needed
        mkdir -p "$(dirname "$DT_MCP_DIR")"

        echo ""
        echo "Cloning $REPO_URL to $DT_MCP_DIR..."
        if ! git clone "$REPO_URL" "$DT_MCP_DIR"; then
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

# Change to repository directory for npm install
(
    cd "$DT_MCP_DIR" || exit 1

    # Check if dependencies are installed
    if [[ ! -d "node_modules" ]]; then
        echo ""
        echo "Installing dt-mcp dependencies..."
        if ! npm install; then
            echo -e "${RED}Failed to install dependencies${NC}"
            exit 1
        fi
    else
        echo "Dependencies already installed"
    fi
) || exit 1

# Verify server.js exists
SERVER_PATH="$DT_MCP_DIR/server.js"
if [[ ! -f "$SERVER_PATH" ]]; then
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

# Handle Claude config merge
if [[ -f "$CLAUDE_CONFIG" ]]; then
    echo ""
    echo -e "${YELLOW}Found existing Claude configuration${NC}"
    echo ""
    read -rp "Automatically merge DEVONthink config into Claude? (y/N): " AUTO_MERGE

    if [[ "$AUTO_MERGE" =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_PATH=$(backup_config "$CLAUDE_CONFIG")
        if [[ -n "$BACKUP_PATH" ]]; then
            echo "Backed up to: $BACKUP_PATH"
        fi

        # Merge configs using deep merge
        if merge_mcp_config "$CLAUDE_CONFIG" "$CONFIG_JSON" "devonthink"; then
            echo -e "${GREEN}✓ Config merged successfully!${NC}"
        else
            echo -e "${RED}Error: Failed to merge config${NC}"
            echo "Please manually merge this config:"
            echo ""
            echo "$CONFIG_JSON"
            echo ""
            echo "Into: $CLAUDE_CONFIG"
            exit 1
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
    echo -e "${GREEN}✓ Config created!${NC}"
fi

echo ""
echo -e "${GREEN}✓ DEVONthink MCP Server is ready!${NC}"
echo ""
echo "Server location: $SERVER_PATH"
echo ""
echo "Next steps:"
echo "1. Ensure DEVONthink 3 is running"
echo "2. Restart Claude Code or Claude Desktop to load the MCP server"
echo "3. Grant automation permissions if prompted by macOS"
echo ""
