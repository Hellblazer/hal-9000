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
if ! safe_pip_install chroma-mcp; then
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

# Check for CHROMA_CLIENT_TYPE environment variable
CHROMA_CLIENT_TYPE="${CHROMA_CLIENT_TYPE:-}"

if [[ -n "$CHROMA_CLIENT_TYPE" ]]; then
    echo -e "${GREEN}Using client type from environment: $CHROMA_CLIENT_TYPE${NC}"
    CLIENT_TYPE="$CHROMA_CLIENT_TYPE"
else
    echo "Choose ChromaDB client type:"
    echo "1) Cloud     - ChromaDB Cloud service (recommended)"
    echo "2) HTTP      - Self-hosted Chroma server"
    echo "3) Persistent - Local file-based storage"
    echo "4) Ephemeral  - In-memory (testing only)"
    echo ""

    CLIENT_TYPE_CHOICE=""
    while true; do
        read -rp "Select [1]: " CLIENT_TYPE_CHOICE
        CLIENT_TYPE_CHOICE=${CLIENT_TYPE_CHOICE:-1}
        if [[ "$CLIENT_TYPE_CHOICE" =~ ^[1234]$ ]]; then
            break
        fi
        echo -e "${RED}Invalid selection. Please enter 1, 2, 3, or 4.${NC}"
    done

    case "$CLIENT_TYPE_CHOICE" in
        1) CLIENT_TYPE="cloud" ;;
        2) CLIENT_TYPE="http" ;;
        3) CLIENT_TYPE="persistent" ;;
        4) CLIENT_TYPE="ephemeral" ;;
    esac
fi

# Configure based on client type
case "$CLIENT_TYPE" in
    cloud)
        echo ""
        echo "Get your ChromaDB Cloud credentials from: https://www.trychroma.com/"
        echo ""

        CHROMADB_TENANT="${CHROMADB_TENANT:-}"
        CHROMADB_DATABASE="${CHROMADB_DATABASE:-}"
        CHROMADB_API_KEY="${CHROMADB_API_KEY:-}"

        if [[ -n "$CHROMADB_TENANT" ]] && [[ -n "$CHROMADB_DATABASE" ]] && [[ -n "$CHROMADB_API_KEY" ]]; then
            echo -e "${GREEN}Using credentials from environment variables${NC}"
        else
            [[ -z "$CHROMADB_TENANT" ]] && read -rp "Tenant ID: " CHROMADB_TENANT
            [[ -z "$CHROMADB_DATABASE" ]] && read -rp "Database name: " CHROMADB_DATABASE
            [[ -z "$CHROMADB_API_KEY" ]] && { read -rsp "API key: " CHROMADB_API_KEY; echo ""; }
        fi

        if [[ -z "$CHROMADB_TENANT" ]] || [[ -z "$CHROMADB_DATABASE" ]] || [[ -z "$CHROMADB_API_KEY" ]]; then
            echo -e "${YELLOW}Cloud credentials not provided - skipping ChromaDB${NC}"
            echo "Set CHROMADB_TENANT, CHROMADB_DATABASE, CHROMADB_API_KEY and re-run"
            exit 0
        fi

        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": ["--client-type", "cloud", "--tenant", "$CHROMADB_TENANT", "--database", "$CHROMADB_DATABASE", "--api-key", "$CHROMADB_API_KEY"]
    }
  }
}
EOF
)
        ;;

    http)
        echo ""
        CHROMADB_HOST="${CHROMADB_HOST:-}"
        CHROMADB_PORT="${CHROMADB_PORT:-}"

        if [[ -n "$CHROMADB_HOST" ]] && [[ -n "$CHROMADB_PORT" ]]; then
            echo -e "${GREEN}Using HTTP config from environment variables${NC}"
        else
            [[ -z "$CHROMADB_HOST" ]] && read -rp "Chroma host [localhost]: " CHROMADB_HOST
            CHROMADB_HOST=${CHROMADB_HOST:-localhost}
            [[ -z "$CHROMADB_PORT" ]] && read -rp "Chroma port [8000]: " CHROMADB_PORT
            CHROMADB_PORT=${CHROMADB_PORT:-8000}
        fi

        if [[ -z "$CHROMADB_HOST" ]] || [[ -z "$CHROMADB_PORT" ]]; then
            echo -e "${YELLOW}HTTP config not provided - skipping ChromaDB${NC}"
            exit 0
        fi

        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": ["--client-type", "http", "--host", "$CHROMADB_HOST", "--port", "$CHROMADB_PORT"]
    }
  }
}
EOF
)
        ;;

    persistent)
        echo ""
        CHROMADB_DATA_DIR="${CHROMADB_DATA_DIR:-}"

        if [[ -n "$CHROMADB_DATA_DIR" ]]; then
            echo -e "${GREEN}Using data directory from environment: $CHROMADB_DATA_DIR${NC}"
        else
            read -rp "Data directory [$HOME/.chromadb]: " CHROMADB_DATA_DIR
            CHROMADB_DATA_DIR=${CHROMADB_DATA_DIR:-$HOME/.chromadb}
        fi

        # Create directory if needed
        mkdir -p "$CHROMADB_DATA_DIR"

        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": ["--client-type", "persistent", "--data-dir", "$CHROMADB_DATA_DIR"]
    }
  }
}
EOF
)
        ;;

    ephemeral)
        echo -e "${YELLOW}Note: Ephemeral mode loses all data on restart${NC}"
        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "chromadb": {
      "command": "$CHROMA_MCP_PATH",
      "args": ["--client-type", "ephemeral"]
    }
  }
}
EOF
)
        ;;

    *)
        echo -e "${RED}Unknown client type: $CLIENT_TYPE${NC}"
        exit 1
        ;;
esac

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
