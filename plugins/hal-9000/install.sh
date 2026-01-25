#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║    HAL-9000 Marketplace Installation              ║${NC}"
echo -e "${BLUE}║    (Optional System-Level Dependencies)           ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Marketplace components already installed:${NC}"
echo "  • MCP Servers: ChromaDB, Memory Bank, Sequential Thinking, DEVONthink"
echo "  • Commands: /check, /load, /sessions, /session-delete"
echo "  • Custom Agents: 12 specialized agents"
echo "  • Safety Hooks: Git, file, and environment protection"
echo ""
echo -e "${YELLOW}This script installs optional system-level tools:${NC}"
echo "  • aod (Army of Darkness): Multi-branch parallel development"
echo "  • beads (bd): AI-optimized issue tracking"
echo "  • claude-code-tools: tmux-cli, vault, env-safe"
echo ""
echo "⚠️  IMPORTANT: This script will NOT modify ~/.claude directory"
echo "   (Marketplace handles all agent/hook/command installation)"
echo ""
read -p "Proceed with optional system tool installation? (y/N): " proceed
[[ "$proceed" =~ ^[Yy]$ ]] || exit 0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

##############################################################################
# SYSTEM DEPENDENCIES
##############################################################################

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing MCP Server Dependencies${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

cd "$SCRIPT_DIR/mcp-servers/chromadb"
./install.sh

echo ""
cd "$SCRIPT_DIR/mcp-servers/memory-bank"
./install.sh

echo ""
cd "$SCRIPT_DIR/mcp-servers/sequential-thinking"
./install.sh

echo ""
if [[ "$OSTYPE" == "darwin"* ]]; then
    cd "$SCRIPT_DIR/mcp-servers/devonthink"
    ./install.sh
else
    echo -e "${YELLOW}Skipping DEVONthink (macOS only)${NC}"
fi

# Install beads (bd) - AI-optimized issue tracker
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing beads (bd) Issue Tracker${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

if command -v brew &> /dev/null; then
    if ! command -v bd &> /dev/null; then
        echo "Installing bd CLI via Homebrew..."
        brew tap steveyegge/beads
        brew install bd
        echo -e "${GREEN}✓ bd CLI installed${NC}"
    else
        echo -e "${GREEN}✓ bd CLI already installed ($(bd --version 2>/dev/null || echo 'version unknown'))${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Homebrew not found - install bd manually:${NC}"
    echo "  brew tap steveyegge/beads && brew install bd"
    echo "  Or: curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
fi

echo ""
echo "beads quick start:"
echo "  1. cd your-project && bd init"
echo "  2. bd create \"First task\" -t task"
echo "  3. bd ready  # Show ready work"

# Install Claude Code Tools
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing Claude Code Tools${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    if command -v brew &> /dev/null; then
        brew install uv
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
fi

echo "Installing claude-code-tools from PyPI..."
uv tool install --force claude-code-tools
echo -e "${GREEN}✓ claude-code-tools installed (tmux-cli, vault, env-safe, find-session)${NC}"

# Install aod (Army of Darkness) scripts
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing aod (Army of Darkness)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

# Determine install location
if command -v brew &> /dev/null; then
    INSTALL_BIN="$(brew --prefix)/bin"
else
    INSTALL_BIN="$HOME/.local/bin"
    mkdir -p "$INSTALL_BIN"
fi

# Copy scripts
echo "Installing aod scripts to $INSTALL_BIN..."
cp "$SCRIPT_DIR/aod/aod.sh" "$INSTALL_BIN/aod"
cp "$SCRIPT_DIR/aod/aod-init.sh" "$INSTALL_BIN/aod-init"
cp "$SCRIPT_DIR/aod/aod-list.sh" "$INSTALL_BIN/aod-list"
cp "$SCRIPT_DIR/aod/aod-attach.sh" "$INSTALL_BIN/aod-attach"
cp "$SCRIPT_DIR/aod/aod-stop.sh" "$INSTALL_BIN/aod-stop"
cp "$SCRIPT_DIR/aod/aod-cleanup.sh" "$INSTALL_BIN/aod-cleanup"
cp "$SCRIPT_DIR/aod/aod-send.sh" "$INSTALL_BIN/aod-send"
cp "$SCRIPT_DIR/aod/aod-broadcast.sh" "$INSTALL_BIN/aod-broadcast"
chmod +x "$INSTALL_BIN"/aod "$INSTALL_BIN"/aod-*

# Copy example config
if [ ! -f "$HOME/aod.conf.example" ]; then
    cp "$SCRIPT_DIR/aod/aod.conf.example" "$HOME/aod.conf.example"
    echo "Example configuration: $HOME/aod.conf.example"
fi

echo -e "${GREEN}✓ aod (Army of Darkness) installed${NC}"
echo "Commands: aod, aod-list, aod-attach, aod-stop, aod-cleanup, aod-send, aod-broadcast"

# Install claudy (containerized Claude launcher)
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing claudy (Containerized Claude)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

echo "Installing claudy script to $INSTALL_BIN..."
cp "$SCRIPT_DIR/../claudy" "$INSTALL_BIN/claudy"
chmod +x "$INSTALL_BIN/claudy"
echo -e "${GREEN}✓ claudy installed${NC}"
echo "Usage: cd your-project && claudy"

##############################################################################
# OPTIONAL: tmux configuration
##############################################################################

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Optional: tmux Configuration${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""
echo "Install tmux configuration? (Catppuccin theme, CPU/RAM monitoring, session persistence)"
printf "Install tmux config? (y/N): "
read -r install_tmux

if [[ "$install_tmux" =~ ^[Yy]$ ]]; then
    # Backup existing config
    if [[ -f "$HOME/.tmux.conf" ]]; then
        backup_file="$HOME/.tmux.conf.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.tmux.conf" "$backup_file"
        echo -e "${GREEN}✓ Backed up existing config to${NC} $backup_file"
    fi

    # Install new config
    cp "$SCRIPT_DIR/../../templates/tmux.conf" "$HOME/.tmux.conf"
    echo -e "${GREEN}✓ Installed tmux configuration${NC}"

    # Install TPM if not present
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        echo "Installing Tmux Plugin Manager (TPM)..."
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        echo -e "${GREEN}✓ Installed TPM${NC}"
        echo -e "  ${CYAN}Run 'prefix + I' in tmux to install plugins${NC}"
    fi
    echo -e "  ${CYAN}Reload tmux: tmux source ~/.tmux.conf${NC}"
else
    echo -e "${YELLOW}⚠ Skipped tmux configuration${NC}"
fi

##############################################################################
# Installation Complete
##############################################################################

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║   ✓ System Tools Installation Complete!          ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

echo "✅ Installed:"
echo "  • MCP Server dependencies (ChromaDB, Memory Bank, Sequential Thinking)"
echo "  • beads (bd) - Issue tracking"
echo "  • claude-code-tools (tmux-cli, vault, env-safe, find-session)"
echo "  • aod (Army of Darkness) - Multi-branch development"
echo "  • claudy - Containerized Claude launcher"
if [[ "$install_tmux" =~ ^[Yy]$ ]]; then
    echo "  • tmux configuration"
fi
echo ""

echo "📝 Important:"
echo "  • Agents, commands, and hooks installed via marketplace"
echo "  • No ~/.claude directory modifications made by this script"
echo "  • All your Claude configuration remains untouched"
echo ""

echo "🚀 Next Steps:"
echo "  1. Restart Claude Code to load MCP servers"
echo "  2. Test: tmux-cli --help, aod --help, claudy --help, bd --help"
echo "  3. Try: cd your-project && claudy"
echo ""

echo "📚 Documentation:"
echo "  • README: $SCRIPT_DIR/README.md"
echo "  • Docker Integration: $SCRIPT_DIR/../docs/DOCKER-INTEGRATION.md"
echo "  • MCP Servers: $SCRIPT_DIR/mcp-servers/README.md"
echo ""
