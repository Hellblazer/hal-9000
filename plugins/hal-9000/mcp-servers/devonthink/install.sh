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

echo -e "${BLUE}Installing DEVONthink MCP Server (Python)...${NC}"
echo ""

# Check Python version
check_python_version || exit 1

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
    echo -e "${YELLOW}Warning: DEVONthink is not running.${NC}"
    echo "Start DEVONthink before using this MCP server."
    echo ""
fi

# Install Python dependencies
echo "Installing Python dependencies..."
if safe_pip_install --quiet -r "$SCRIPT_DIR/requirements.txt"; then
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${RED}Error: Failed to install dependencies${NC}"
    echo "Try manually: pip3 install mcp"
    exit 1
fi
echo ""

# Make server.py executable
chmod +x "$SCRIPT_DIR/server.py"

# Create config snippet
SERVER_PATH="$SCRIPT_DIR/server.py"
CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "devonthink": {
      "command": "python3",
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
echo -e "${GREEN}✓ DEVONthink MCP Server installed successfully!${NC}"
echo ""
echo "Server location: $SERVER_PATH"
echo ""
echo "Next steps:"
echo "1. Ensure DEVONthink is running"
echo "2. Restart Claude Code or Claude Desktop to load the MCP server"
echo "3. Grant automation permissions if prompted by macOS"
echo ""
echo "Usage:"
echo "  - Search: 'Search my DEVONthink for documents about X'"
echo "  - Import: 'Import this arXiv paper: 2312.03032'"
echo "  - Create: 'Create a note in DEVONthink with this content'"
echo ""
