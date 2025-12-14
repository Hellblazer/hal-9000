#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${BLUE}Installing ChromaDB MCP Server...${NC}"
echo ""

# Check Python version
check_python_version || exit 1

# Check for pip
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is required but not installed.${NC}"
    echo -e "${YELLOW}Install with your Python installation${NC}"
    exit 1
fi

# Get Claude config path
CLAUDE_CONFIG=$(get_claude_config_path) || exit 1

# Check if already configured
if is_mcp_server_configured "$CLAUDE_CONFIG" "chromadb"; then
    echo -e "${YELLOW}ChromaDB MCP server is already configured${NC}"
    echo ""
    read -rp "Overwrite existing configuration? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Skipping ChromaDB installation (keeping existing configuration)"
        exit 0
    fi
    echo "Proceeding with installation (will overwrite)..."
    echo ""
fi

# Install chroma-mcp
echo "Installing chroma-mcp via pip..."
if ! pip3 install --user chroma-mcp; then
    echo -e "${RED}Error: Failed to install chroma-mcp${NC}"
    exit 1
fi

# Get the Python bin directory
PYTHON_BIN_DIR=$(get_python_bin_dir)
CHROMA_MCP_PATH="$PYTHON_BIN_DIR/chroma-mcp"

# Verify installation
if [[ ! -f "$CHROMA_MCP_PATH" ]]; then
    echo -e "${RED}Error: chroma-mcp not found at $CHROMA_MCP_PATH${NC}"
    exit 1
fi

# Update PATH if needed
update_path_if_needed "$PYTHON_BIN_DIR"

echo ""
echo -e "${BLUE}ChromaDB Configuration${NC}"
echo ""
echo "Choose ChromaDB client type:"
echo "1) Cloud (ChromaDB Cloud service)"
echo "2) Local (Local ChromaDB instance)"

CLIENT_TYPE_CHOICE=""
while true; do
    read -rp "Select [1]: " CLIENT_TYPE_CHOICE
    CLIENT_TYPE_CHOICE=${CLIENT_TYPE_CHOICE:-1}
    if [[ "$CLIENT_TYPE_CHOICE" =~ ^[12]$ ]]; then
        break
    fi
    echo -e "${RED}Invalid selection. Please enter 1 or 2.${NC}"
done

if [[ "$CLIENT_TYPE_CHOICE" = "1" ]]; then
    # Cloud configuration
    echo ""
    echo "Get your ChromaDB Cloud credentials from: https://www.trychroma.com/"
    echo ""
    read -rp "Tenant ID: " CHROMADB_TENANT
    read -rp "Database name: " CHROMADB_DATABASE
    read -rsp "API key: " CHROMADB_API_KEY
    echo ""  # Newline after password input

    # Validate inputs
    if [[ -z "$CHROMADB_TENANT" ]] || [[ -z "$CHROMADB_DATABASE" ]] || [[ -z "$CHROMADB_API_KEY" ]]; then
        echo -e "${RED}Error: All cloud credentials are required${NC}"
        exit 1
    fi

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
    read -rp "ChromaDB path [$HOME/.chromadb]: " CHROMADB_PATH
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

# Handle Claude config merge
if [[ -f "$CLAUDE_CONFIG" ]]; then
    echo ""
    echo -e "${YELLOW}Found existing Claude configuration${NC}"
    echo ""
    read -rp "Automatically merge ChromaDB config into Claude? (y/N): " AUTO_MERGE

    if [[ "$AUTO_MERGE" =~ ^[Yy]$ ]]; then
        # Backup existing config
        BACKUP_PATH=$(backup_config "$CLAUDE_CONFIG")
        if [[ -n "$BACKUP_PATH" ]]; then
            echo "Backed up to: $BACKUP_PATH"
        fi

        # Merge configs using deep merge
        if merge_mcp_config "$CLAUDE_CONFIG" "$CONFIG_JSON" "chromadb"; then
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
echo -e "${GREEN}✓ ChromaDB MCP Server installed successfully!${NC}"
echo ""
echo "Next step: Restart Claude Code or Claude Desktop to load the MCP server"
echo ""
