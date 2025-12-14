#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${BLUE}Installing Sequential Thinking MCP Server...${NC}"
echo ""

# Check Node version
check_node_version || exit 1

# Get Claude config path
CLAUDE_CONFIG=$(get_claude_config_path) || exit 1

# Check if already configured
if is_mcp_server_configured "$CLAUDE_CONFIG" "sequential-thinking"; then
    echo -e "${YELLOW}Sequential Thinking MCP server is already configured${NC}"
    echo ""
    read -rp "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping Sequential Thinking installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
fi

# Test installation
echo "Testing sequential-thinking MCP server..."
if npx -y @modelcontextprotocol/server-sequential-thinking --help &> /dev/null; then
    echo -e "${GREEN}✓ Sequential Thinking MCP server is available${NC}"
else
    echo -e "${YELLOW}Note: Will be installed via npx on first use${NC}"
fi

# Create config snippet
CONFIG_JSON=$(cat <<'EOF'
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
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
    read -rp "Automatically merge Sequential Thinking config into Claude? (y/N): " AUTO_MERGE

    if [[ "$AUTO_MERGE" =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_PATH=$(backup_config "$CLAUDE_CONFIG")
        if [[ -n "$BACKUP_PATH" ]]; then
            echo "Backed up to: $BACKUP_PATH"
        fi

        # Merge configs using deep merge
        if merge_mcp_config "$CLAUDE_CONFIG" "$CONFIG_JSON" "sequential-thinking"; then
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
echo -e "${GREEN}✓ Sequential Thinking MCP Server installed successfully!${NC}"
echo ""
echo "Next step: Restart Claude Code or Claude Desktop to load the MCP server"
echo ""
echo -e "${YELLOW}Note: This uses npx and doesn't require local installation${NC}"
echo ""
