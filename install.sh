#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup trap
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}Installation failed with error code $exit_code${NC}"
    fi
}
trap cleanup EXIT

# Determine Claude config location based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
else
    echo -e "${RED}Error: Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
BACKUP_DIR="$HOME/.hal-9000-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║        HAL-9000 Claude Marketplace Installer      ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Note: This is a standalone installer for manual use.${NC}"
echo -e "${YELLOW}For Claude Code plugin installation, use the marketplace.${NC}"
echo ""

# Function to backup files
backup_files() {
    echo -e "${YELLOW}Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"

    if [[ -f "$CLAUDE_CONFIG_FILE" ]]; then
        cp "$CLAUDE_CONFIG_FILE" "$BACKUP_DIR/"
        echo "  ✓ Backed up Claude config"
    fi

    if [[ -d "$CLAUDE_COMMANDS_DIR" ]]; then
        cp -r "$CLAUDE_COMMANDS_DIR" "$BACKUP_DIR/"
        echo "  ✓ Backed up commands"
    fi

    echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"
    echo ""
}

# Function to install MCP server
install_mcp_server() {
    local server_name=$1
    local server_dir="$SCRIPT_DIR/plugins/hal-9000/mcp-servers/$server_name"

    if [[ ! -d "$server_dir" ]]; then
        echo -e "${RED}Error: Server directory not found: $server_dir${NC}"
        return 1
    fi

    echo -e "${YELLOW}Installing $server_name...${NC}"

    # Run the install script
    if [[ -f "$server_dir/install.sh" ]]; then
        (cd "$server_dir" && ./install.sh) || {
            echo -e "${RED}Failed to install $server_name${NC}"
            return 1
        }
    else
        echo -e "${RED}No install.sh found for $server_name${NC}"
        return 1
    fi

    # Merge config (manual for now)
    echo -e "${YELLOW}  Note: You'll need to manually merge config.json into Claude's config${NC}"
    echo ""
}

# Function to install commands
install_commands() {
    echo -e "${YELLOW}Installing commands...${NC}"

    local commands_src="$SCRIPT_DIR/plugins/hal-9000/commands"

    if [[ ! -d "$commands_src" ]]; then
        echo -e "${RED}Error: Commands directory not found: $commands_src${NC}"
        return 1
    fi

    mkdir -p "$CLAUDE_COMMANDS_DIR"

    # Copy all .md files except README
    local installed_count=0
    for cmd in "$commands_src"/*.md; do
        if [[ -f "$cmd" && "$(basename "$cmd")" != "README.md" ]]; then
            cp "$cmd" "$CLAUDE_COMMANDS_DIR/"
            echo "  ✓ Installed $(basename "$cmd")"
            installed_count=$((installed_count + 1))
        fi
    done

    if [[ $installed_count -eq 0 ]]; then
        echo -e "${YELLOW}  No commands found to install${NC}"
    else
        echo -e "${GREEN}$installed_count commands installed!${NC}"
    fi
    echo ""
}

# Interactive menu
show_menu() {
    echo "What would you like to install?"
    echo ""
    echo "  1) All MCP servers"
    echo "  2) ChromaDB MCP server"
    echo "  3) Memory Bank MCP server"
    echo "  4) DEVONthink MCP server"
    echo "  5) Commands"
    echo "  6) Everything (MCP servers + commands)"
    echo "  0) Exit"
    echo ""

    local choice
    while true; do
        read -rp "Enter your choice [0-6]: " choice
        choice=${choice:-0}
        if [[ "$choice" =~ ^[0-6]$ ]]; then
            echo "$choice"
            return 0
        fi
        echo -e "${RED}Invalid selection. Please enter 0-6.${NC}"
    done
}

# Main installation logic
main() {
    # Check prerequisites
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        echo -e "${RED}Error: Claude config directory not found at $CLAUDE_CONFIG_DIR${NC}"
        echo "Is Claude Code/Desktop installed?"
        exit 1
    fi

    echo -e "${GREEN}✓ Claude config directory found${NC}"
    echo ""

    # Backup existing config
    backup_files

    # Show menu
    local choice
    choice=$(show_menu)
    echo ""

    case $choice in
        1)
            echo -e "${BLUE}Installing all MCP servers...${NC}"
            echo ""
            install_mcp_server "chromadb"
            install_mcp_server "memory-bank"
            install_mcp_server "devonthink"
            ;;
        2)
            install_mcp_server "chromadb"
            ;;
        3)
            install_mcp_server "memory-bank"
            ;;
        4)
            install_mcp_server "devonthink"
            ;;
        5)
            install_commands
            ;;
        6)
            echo -e "${BLUE}Installing everything...${NC}"
            echo ""
            install_mcp_server "chromadb"
            install_mcp_server "memory-bank"
            install_mcp_server "devonthink"
            install_commands
            ;;
        0)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac

    # Post-installation instructions
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}║             Installation Complete!                ║${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    echo "1. ${BLUE}Merge MCP server configs${NC}"
    echo "   For each installed MCP server, merge its config.json into:"
    echo "   $CLAUDE_CONFIG_FILE"
    echo ""
    echo "2. ${BLUE}Restart Claude${NC}"
    echo "   Restart Claude Code or Claude Desktop to load new configurations"
    echo ""
    echo "3. ${BLUE}Test commands${NC}"
    echo "   In Claude Code, type /help to see your new commands"
    echo ""
    echo "4. ${BLUE}Backup location${NC}"
    echo "   Your original config was backed up to:"
    echo "   $BACKUP_DIR"
    echo ""
    echo -e "${GREEN}Enjoy your enhanced Claude Code experience!${NC}"
}

# Run main
main
