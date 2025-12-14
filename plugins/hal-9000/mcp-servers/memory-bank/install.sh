#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${BLUE}Installing Memory Bank MCP Server...${NC}"
echo ""

# Check Node version
check_node_version || exit 1

# Get Claude config path
CLAUDE_CONFIG=$(get_claude_config_path) || exit 1

# Check if already configured
if is_mcp_server_configured "$CLAUDE_CONFIG" "memory-bank"; then
    echo -e "${YELLOW}Memory Bank MCP server is already configured${NC}"
    echo ""
    read -rp "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping Memory Bank installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
fi

# Configure memory bank location
echo "Memory bank location configuration:"
echo ""
read -rp "Memory bank directory [$HOME/memory-bank]: " MEMORY_BANK_ROOT
MEMORY_BANK_ROOT=${MEMORY_BANK_ROOT:-$HOME/memory-bank}

# Create memory bank directory
mkdir -p "$MEMORY_BANK_ROOT"
echo "Memory bank will be stored at: $MEMORY_BANK_ROOT"
echo ""

# Create config snippet
CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp@latest"],
      "env": {
        "MEMORY_BANK_ROOT": "$MEMORY_BANK_ROOT"
      }
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
    read -rp "Automatically merge Memory Bank config into Claude? (y/N): " AUTO_MERGE

    if [[ "$AUTO_MERGE" =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_PATH=$(backup_config "$CLAUDE_CONFIG")
        if [[ -n "$BACKUP_PATH" ]]; then
            echo "Backed up to: $BACKUP_PATH"
        fi

        # Merge configs using deep merge
        if merge_mcp_config "$CLAUDE_CONFIG" "$CONFIG_JSON" "memory-bank"; then
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
echo -e "${GREEN}✓ Memory Bank MCP Server installed successfully!${NC}"
echo ""
echo "Memory bank directory: $MEMORY_BANK_ROOT"
echo ""
echo "Next step: Restart Claude Code or Claude Desktop to load the MCP server"
echo ""
echo -e "${YELLOW}Note: This uses npx and doesn't require local installation${NC}"
echo ""
