#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Prompt for installation mode
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║         HAL-9000 Installation                     ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Choose installation mode:"
echo ""
echo "1. Complete Installation (recommended)"
echo "   - Host: MCP servers, session commands, tmux-cli,"
echo "     aod, ClaudeBox, safety hooks"
echo "   - ClaudeBox Shared: MCP servers and tools at ~/.claudebox/hal-9000"
echo "     (inherited by all ClaudeBox containers)"
echo ""
echo "2. Host Only"
echo "   - Only install on host machine (no ClaudeBox shared setup)"
echo ""
echo "3. ClaudeBox Shared Only"
echo "   - Only install to ClaudeBox shared location"
echo "   - For manual/custom ClaudeBox setups"
echo ""
read -p "Select mode [1-3] (default: 1): " mode_choice

# Installation targets
INSTALL_HOST="true"
INSTALL_CLAUDEBOX_SHARED="true"
SKIP_HOST_ORCHESTRATION="false"

case "$mode_choice" in
    2)
        # Host only
        INSTALL_CLAUDEBOX_SHARED="false"
        ;;
    3)
        # ClaudeBox shared only
        INSTALL_HOST="false"
        SKIP_HOST_ORCHESTRATION="true"
        ;;
    *)
        # Default: Complete installation (mode 1)
        INSTALL_HOST="true"
        INSTALL_CLAUDEBOX_SHARED="true"
        ;;
esac

# Support legacy --claudebox flag
if [[ "${1:-}" == "--claudebox" ]]; then
    INSTALL_HOST="false"
    INSTALL_CLAUDEBOX_SHARED="true"
    SKIP_HOST_ORCHESTRATION="true"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ClaudeBox shared directory
CLAUDEBOX_SHARED_DIR="$HOME/.claudebox/hal-9000"

if [[ "$INSTALL_HOST" == "true" ]]; then
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║         HAL-9000 Host Installation                ║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Installing to host machine:"
    echo "  • MCP Servers (ChromaDB, Memory Bank, Sequential Thinking, DEVONthink)"
    echo "  • Session Management Commands"
    echo "  • Claude Code Tools (tmux-cli, vault, env-safe, hooks)"
    if [[ "$SKIP_HOST_ORCHESTRATION" == "false" ]]; then
        echo "  • ClaudeBox (Docker development environments)"
        echo "  • aod (multi-branch parallel development)"
    fi
    echo ""
fi

##############################################################################
# HOST INSTALLATION
##############################################################################
if [[ "$INSTALL_HOST" == "true" ]]; then
    # Run MCP server installers
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing MCP Servers (Host)${NC}"
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

    # Install bd CLI via Homebrew
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
    echo "  4. bd onboard  # Get Claude integration instructions"

    # Install Claude Code Tools
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing Claude Code Tools (Host)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Installing: tmux-cli, find-session, vault, env-safe, safety hooks"
    echo ""

    # Install from PyPI
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

    # Configure ccstatusline in Claude Code settings
    echo ""
    echo "Configuring ccstatusline for Claude Code..."
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"

    # Create settings file if it doesn't exist or contains invalid JSON
    if [[ ! -f "$CLAUDE_SETTINGS" ]] || ! jq . "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
        echo "Creating/resetting Claude settings..."
        echo '{}' > "$CLAUDE_SETTINGS"
    fi

    # Add or update statusLine setting using jq
    if command -v jq &> /dev/null; then
        # Use bunx if available (faster), otherwise npx
        if command -v bun &> /dev/null; then
            STATUS_CMD="bunx -y ccstatusline@latest"
        else
            STATUS_CMD="npx ccstatusline@latest"
        fi

        # Update settings.json with statusLine (object format with quoted keys)
        tmp_file=$(mktemp)
        if jq --arg cmd "$STATUS_CMD" \
           '.statusLine = {"type": "command", "command": $cmd, "padding": 0}' \
           "$CLAUDE_SETTINGS" > "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$CLAUDE_SETTINGS"
            echo -e "${GREEN}✓ Configured ccstatusline in Claude Code settings${NC}"
            echo -e "  Using: ${CYAN}$STATUS_CMD${NC}"
        else
            rm -f "$tmp_file"
            echo -e "${RED}✗ Failed to update Claude settings - check $CLAUDE_SETTINGS${NC}"
            echo -e "${YELLOW}⚠ Continuing with installation...${NC}"
        fi

        # Create ccstatusline widget configuration
        CCSTATUS_CONFIG_DIR="$HOME/.config/ccstatusline"
        CCSTATUS_SETTINGS="$CCSTATUS_CONFIG_DIR/settings.json"

        mkdir -p "$CCSTATUS_CONFIG_DIR"

        cat > "$CCSTATUS_SETTINGS" <<'EOF'
{
  "_comment": "hal-9000 default configuration - edit with 'bunx ccstatusline@latest'",
  "version": 3,
  "lines": [
    [
      {
        "_comment": "Shows context usage % (inverted - shows remaining vs used)",
        "id": "context-percentage-usable-widget",
        "type": "context-percentage-usable",
        "metadata": {
          "inverse": "true"
        }
      },
      {
        "_comment": "Total time in this Claude Code session",
        "id": "session-clock-widget",
        "type": "session-clock",
        "color": "brightCyan"
      }
    ],
    [
      {
        "_comment": "Current git branch name",
        "id": "git-branch-widget",
        "type": "git-branch",
        "color": "brightCyan"
      },
      {
        "_comment": "Git worktree name (shows which aod session you're in)",
        "id": "git-worktree-widget",
        "type": "git-worktree",
        "color": "yellow"
      }
    ],
    []
  ],
  "flexMode": "full-minus-40",
  "compactThreshold": 60,
  "colorLevel": 2,
  "defaultPadding": " ",
  "inheritSeparatorColors": false,
  "globalBold": false,
  "powerline": {
    "enabled": true,
    "separators": [
      ""
    ],
    "separatorInvertBackground": [
      false
    ],
    "startCaps": [],
    "endCaps": [],
    "theme": "custom",
    "autoAlign": true
  }
}
EOF

        echo -e "${GREEN}✓ Configured ccstatusline widgets${NC}"
        echo -e "  Line 1: Context % (usable), Session Clock"
        echo -e "  Line 2: Git Branch, Git Worktree"
        echo -e "  Run ${CYAN}bunx ccstatusline@latest${NC} to customize widgets"
    else
        echo -e "${YELLOW}⚠ jq not found - skipping ccstatusline configuration${NC}"
        echo -e "  Manually add to $CLAUDE_SETTINGS:"
        echo -e '  {"statusLine": {"type": "command", "command": "bunx -y ccstatusline@latest", "padding": 0}}'
    fi

    # Optional tmux configuration
    echo ""
    echo "Install tmux configuration? (includes CPU/RAM monitoring, Catppuccin theme)"
    echo "  - CPU/RAM monitoring in status bar"
    echo "  - Session persistence (tmux-resurrect)"
    echo "  - Mouse support with clipboard integration"
    echo "  - Powerline status bar"
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

    # Optional CLAUDE.md template
    echo ""
    echo "Install hal-9000 CLAUDE.md template? (includes tmux-cli, agents, knowledge management)"
    echo "  - tmux-cli usage patterns"
    echo "  - Agent best practices (12 custom agents)"
    echo "  - ChromaDB/Memory Bank guidance"
    echo "  - aod command reference"
    printf "Install CLAUDE.md template? (y/N): "
    read -r install_claude_md

    if [[ "$install_claude_md" =~ ^[Yy]$ ]]; then
        # Backup existing CLAUDE.md
        if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
            backup_file="$HOME/.claude/CLAUDE.md.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$HOME/.claude/CLAUDE.md" "$backup_file"
            echo -e "${GREEN}✓ Backed up existing CLAUDE.md to${NC} $backup_file"
        fi

        # Install template
        cp "$SCRIPT_DIR/../../templates/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
        echo -e "${GREEN}✓ Installed CLAUDE.md template${NC}"
        echo -e "  ${CYAN}Add your personal preferences below the template marker${NC}"
    else
        echo -e "${YELLOW}⚠ Skipped CLAUDE.md template${NC}"
    fi

    # Install safety hooks (bundled locally)
    HOOKS_DIR="$HOME/.claude/hooks/claude-code-tools"
    mkdir -p "$HOOKS_DIR"

    echo "Installing safety hooks..."
    cp "$SCRIPT_DIR/hooks"/* "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR"/*.py 2>/dev/null || true

    # Install custom agents
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing Custom Agents (Host)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    AGENTS_DIR="$HOME/.claude/agents"
    mkdir -p "$AGENTS_DIR"

    # Check for existing agents and backup if needed
    EXISTING_AGENTS=()
    for agent in "$SCRIPT_DIR/agents"/*.md; do
        agent_name=$(basename "$agent")
        if [ -f "$AGENTS_DIR/$agent_name" ]; then
            EXISTING_AGENTS+=("$agent_name")
        fi
    done

    if [ ${#EXISTING_AGENTS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Found ${#EXISTING_AGENTS[@]} existing agent configurations${NC}"
        BACKUP_DIR="$HOME/.claude/agents.backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        for agent in "${EXISTING_AGENTS[@]}"; do
            cp "$AGENTS_DIR/$agent" "$BACKUP_DIR/"
        done
        echo "Backed up to: $BACKUP_DIR"
        echo ""
    fi

    # Copy agent configurations
    echo "Installing custom agent configurations..."
    cp "$SCRIPT_DIR/agents"/*.md "$AGENTS_DIR/"
    AGENT_COUNT=$(ls -1 "$SCRIPT_DIR/agents"/*.md 2>/dev/null | wc -l | xargs)
    echo -e "${GREEN}Installed $AGENT_COUNT custom agents to ~/.claude/agents/${NC}"

# Install ClaudeBox (host only, skip if orchestration disabled)
if [[ "$SKIP_HOST_ORCHESTRATION" == "false" ]]; then
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing ClaudeBox${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    if command -v brew &> /dev/null; then
        if brew search claudebox | grep -q "claudebox"; then
            brew install claudebox
        else
            echo "Downloading ClaudeBox installer..."
            curl -fsSL https://github.com/Hellblazer/claudebox/releases/latest/download/claudebox.run -o /tmp/claudebox.run
            chmod +x /tmp/claudebox.run
            /tmp/claudebox.run
            rm /tmp/claudebox.run
        fi
    else
        echo "Installing ClaudeBox from GitHub releases..."
        curl -fsSL https://github.com/Hellblazer/claudebox/releases/latest/download/claudebox.run -o /tmp/claudebox.run
        chmod +x /tmp/claudebox.run
        /tmp/claudebox.run
        rm /tmp/claudebox.run
    fi
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
    echo "Installing aod (Army of Darkness) scripts to $INSTALL_BIN..."
    cp "$SCRIPT_DIR/aod/aod.sh" "$INSTALL_BIN/aod"
    cp "$SCRIPT_DIR/aod/aod-init.sh" "$INSTALL_BIN/aod-init"
    cp "$SCRIPT_DIR/aod/aod-list.sh" "$INSTALL_BIN/aod-list"
    cp "$SCRIPT_DIR/aod/aod-attach.sh" "$INSTALL_BIN/aod-attach"
    cp "$SCRIPT_DIR/aod/aod-stop.sh" "$INSTALL_BIN/aod-stop"
    cp "$SCRIPT_DIR/aod/aod-cleanup.sh" "$INSTALL_BIN/aod-cleanup"
    cp "$SCRIPT_DIR/aod/aod-send.sh" "$INSTALL_BIN/aod-send"
    cp "$SCRIPT_DIR/aod/aod-broadcast.sh" "$INSTALL_BIN/aod-broadcast"
    chmod +x "$INSTALL_BIN"/aod "$INSTALL_BIN"/aod-*

    # Copy example config to user's home
    if [ ! -f "$HOME/aod.conf" ]; then
        cp "$SCRIPT_DIR/aod/aod.conf.example" "$HOME/aod.conf.example"
        echo "Example configuration copied to: $HOME/aod.conf.example"
    fi

    echo -e "${GREEN}aod (Army of Darkness) installed successfully${NC}"
    echo "Commands: aod, aod-init, aod-list, aod-attach, aod-stop, aod-cleanup, aod-send, aod-broadcast"

    # Install hal9000 scripts (containerized Claude without git worktrees)
    echo ""
    echo "Installing hal9000 (containerized Claude) scripts to $INSTALL_BIN..."
    cp "$SCRIPT_DIR/hal9000/hal9000.sh" "$INSTALL_BIN/hal9000"
    cp "$SCRIPT_DIR/hal9000/hal9000-list.sh" "$INSTALL_BIN/hal9000-list"
    cp "$SCRIPT_DIR/hal9000/hal9000-attach.sh" "$INSTALL_BIN/hal9000-attach"
    cp "$SCRIPT_DIR/hal9000/hal9000-stop.sh" "$INSTALL_BIN/hal9000-stop"
    cp "$SCRIPT_DIR/hal9000/hal9000-cleanup.sh" "$INSTALL_BIN/hal9000-cleanup"
    cp "$SCRIPT_DIR/hal9000/hal9000-send.sh" "$INSTALL_BIN/hal9000-send"
    cp "$SCRIPT_DIR/hal9000/hal9000-broadcast.sh" "$INSTALL_BIN/hal9000-broadcast"
    chmod +x "$INSTALL_BIN"/hal9000 "$INSTALL_BIN"/hal9000-*

    echo -e "${GREEN}hal9000 installed successfully${NC}"
    echo "Commands: hal9000 run, hal9000 squad, hal9000-list, hal9000-attach, hal9000-stop, hal9000-cleanup, hal9000-send, hal9000-broadcast"
fi
# End of SKIP_HOST_ORCHESTRATION block

fi
# End of INSTALL_HOST block

##############################################################################
# CLAUDEBOX SHARED INSTALLATION
##############################################################################
if [[ "$INSTALL_CLAUDEBOX_SHARED" == "true" ]]; then
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║      HAL-9000 ClaudeBox Shared Installation       ║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Installing to shared location: $CLAUDEBOX_SHARED_DIR"
    echo "All ClaudeBox containers will inherit these components:"
    echo "  • MCP Servers (ChromaDB, Memory Bank, Sequential Thinking)"
    echo "  • Claude Code Tools (tmux-cli, vault, env-safe)"
    echo "  • Safety Hooks"
    echo ""

    # Create shared directory structure
    mkdir -p "$CLAUDEBOX_SHARED_DIR"/{mcp-servers,tools,hooks,commands}

    # Install MCP servers to shared location
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing MCP Servers (ClaudeBox Shared)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Note: MCP servers installed via npm/npx are globally available"
    echo "      and will work in ClaudeBox containers automatically."
    echo ""

    # Copy MCP server configurations to shared location
    cp -r "$SCRIPT_DIR/mcp-servers"/* "$CLAUDEBOX_SHARED_DIR/mcp-servers/"

    # Download bd (beads) binary for Linux containers
    echo ""
    echo "Downloading bd CLI for Linux containers..."
    BD_VERSION=$(curl -sL https://api.github.com/repos/steveyegge/beads/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "0.30.0")

    # Detect architecture for Linux binary
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) BD_ARCH="amd64" ;;
        aarch64|arm64) BD_ARCH="arm64" ;;
        *) BD_ARCH="amd64" ;;  # Default to amd64
    esac

    BD_URL="https://github.com/steveyegge/beads/releases/download/v${BD_VERSION}/beads_${BD_VERSION}_linux_${BD_ARCH}.tar.gz"
    mkdir -p "$CLAUDEBOX_SHARED_DIR/tools/bin"

    if curl -fsSL "$BD_URL" | tar -xz -C "$CLAUDEBOX_SHARED_DIR/tools/bin" bd 2>/dev/null; then
        chmod +x "$CLAUDEBOX_SHARED_DIR/tools/bin/bd"
        echo -e "${GREEN}✓ bd CLI (v$BD_VERSION, linux_$BD_ARCH) downloaded to shared tools${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to download bd binary - containers will need to install individually${NC}"
    fi

    # Install claude-code-tools to shared location
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing Claude Code Tools (ClaudeBox Shared)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    # Install claude-code-tools once to shared location
    # This is shared across ALL containers - no per-container installation needed
    mkdir -p "$CLAUDEBOX_SHARED_DIR/tools/bin"

    if command -v uv &> /dev/null; then
        echo "Installing claude-code-tools to shared directory (one-time setup)..."
        # Install to shared location using VIRTUAL_ENV trick
        export UV_TOOL_DIR="$CLAUDEBOX_SHARED_DIR/tools"
        export UV_TOOL_BIN_DIR="$CLAUDEBOX_SHARED_DIR/tools/bin"

        if uv tool install claude-code-tools; then
            echo -e "${GREEN}✓ claude-code-tools installed to shared location${NC}"
            echo "  Location: $CLAUDEBOX_SHARED_DIR/tools/bin"
            echo "  All containers will use this single installation"
        else
            echo -e "${YELLOW}Warning: Failed to install claude-code-tools via uv${NC}"
            echo "  Containers will install individually (less efficient)"
        fi

        # Restore environment
        unset UV_TOOL_DIR UV_TOOL_BIN_DIR
    else
        echo -e "${YELLOW}Note: uv not found - claude-code-tools will be installed per-container${NC}"
        echo "  Install uv for optimal performance: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi

    # Create documentation
    cat > "$CLAUDEBOX_SHARED_DIR/tools/README.md" << 'EOF'
# Claude Code Tools for ClaudeBox

**Optimized Installation**: Tools are installed ONCE to this shared directory and reused across all ClaudeBox containers. No per-container downloads!

## Available Tools

- **tmux-cli**: Control interactive CLI apps from Claude Code
- **vault**: Encrypted .env backup (requires SOPS)
- **env-safe**: Safe .env inspection without exposing secrets
- **find-session**: Search across all Claude Code sessions
- **bd**: Beads CLI - AI-optimized issue tracker

## Architecture

```
~/.claudebox/hal-9000/tools/
├── bin/              # Shared tool binaries (tmux-cli, etc.)
└── ...               # uv tool installation data
```

All containers add `/hal-9000/tools/bin` to PATH - instant access, zero downloads.

## Performance Benefits

- **First container**: Instant startup (tools already installed)
- **Nth container**: Instant startup (shares same installation)
- **Bandwidth**: Zero redundant downloads
- **Disk**: Single installation vs. N installations

## Fallback Behavior

If shared installation fails, containers fall back to individual installation.
Setup script handles both scenarios automatically.
EOF

    # Copy hooks to shared location
    echo "Copying safety hooks to shared location..."
    SHARED_HOOKS_DIR="$CLAUDEBOX_SHARED_DIR/hooks"
    mkdir -p "$SHARED_HOOKS_DIR"
    cp "$SCRIPT_DIR/hooks"/* "$SHARED_HOOKS_DIR/"
    chmod +x "$SHARED_HOOKS_DIR"/*.py 2>/dev/null || true

    # Copy session commands to shared location
    echo "Copying session management commands..."
    cp "$SCRIPT_DIR/commands"/*.md "$CLAUDEBOX_SHARED_DIR/commands/" 2>/dev/null || true

    # Copy custom agents to shared location
    echo "Copying custom agent configurations..."
    mkdir -p "$CLAUDEBOX_SHARED_DIR/agents"
    cp "$SCRIPT_DIR/agents"/*.md "$CLAUDEBOX_SHARED_DIR/agents/" 2>/dev/null || true

    # Copy aod (Army of Darkness) scripts to shared location
    echo "Copying aod (Army of Darkness) scripts..."
    mkdir -p "$CLAUDEBOX_SHARED_DIR/aod"
    cp "$SCRIPT_DIR/aod"/*.sh "$SCRIPT_DIR/aod"/aod.conf.example "$CLAUDEBOX_SHARED_DIR/aod/"
    chmod +x "$CLAUDEBOX_SHARED_DIR/aod"/*.sh

    # Copy hal9000 scripts to shared location
    echo "Copying hal9000 scripts..."
    mkdir -p "$CLAUDEBOX_SHARED_DIR/hal9000"
    cp "$SCRIPT_DIR/hal9000"/*.sh "$CLAUDEBOX_SHARED_DIR/hal9000/"
    chmod +x "$CLAUDEBOX_SHARED_DIR/hal9000"/*.sh

    # Copy hal-9000 utility scripts to shared location (if any exist)
    if ls "$SCRIPT_DIR/scripts"/*.sh >/dev/null 2>&1; then
        echo "Copying hal-9000 utility scripts..."
        mkdir -p "$CLAUDEBOX_SHARED_DIR/scripts"
        cp "$SCRIPT_DIR/scripts"/*.sh "$CLAUDEBOX_SHARED_DIR/scripts/"
        chmod +x "$CLAUDEBOX_SHARED_DIR/scripts"/*.sh
    fi

    # Create setup script for ClaudeBox containers
    cat > "$CLAUDEBOX_SHARED_DIR/setup.sh" << 'EOF'
#!/usr/bin/env bash
# This script is run inside ClaudeBox containers to set up HAL-9000 components

# Link hooks to Claude config
mkdir -p ~/.claude/hooks/claude-code-tools
ln -sf /hal-9000/hooks/* ~/.claude/hooks/claude-code-tools/ 2>/dev/null || true

# Link commands
mkdir -p ~/.claude/commands
ln -sf /hal-9000/commands/* ~/.claude/commands/ 2>/dev/null || true

# Link custom agents
mkdir -p ~/.claude/agents
ln -sf /hal-9000/agents/* ~/.claude/agents/ 2>/dev/null || true

# Link aod (Army of Darkness) scripts to user bin
mkdir -p ~/.local/bin
ln -sf /hal-9000/aod/aod.sh ~/.local/bin/aod 2>/dev/null || true
ln -sf /hal-9000/aod/aod-init.sh ~/.local/bin/aod-init 2>/dev/null || true
ln -sf /hal-9000/aod/aod-list.sh ~/.local/bin/aod-list 2>/dev/null || true
ln -sf /hal-9000/aod/aod-attach.sh ~/.local/bin/aod-attach 2>/dev/null || true
ln -sf /hal-9000/aod/aod-stop.sh ~/.local/bin/aod-stop 2>/dev/null || true
ln -sf /hal-9000/aod/aod-cleanup.sh ~/.local/bin/aod-cleanup 2>/dev/null || true
ln -sf /hal-9000/aod/aod-send.sh ~/.local/bin/aod-send 2>/dev/null || true
ln -sf /hal-9000/aod/aod-broadcast.sh ~/.local/bin/aod-broadcast 2>/dev/null || true

# Configure PATH for shared tools (OPTIMIZED: no per-container installation!)
# Add shared tools directory to PATH if not already present
if [[ -d "/hal-9000/tools/bin" ]] && [[ ":$PATH:" != *":/hal-9000/tools/bin:"* ]]; then
    export PATH="/hal-9000/tools/bin:$PATH"

    # Make PATH persistent in .bashrc
    if ! grep -q "/hal-9000/tools/bin" ~/.bashrc 2>/dev/null; then
        echo 'export PATH="/hal-9000/tools/bin:$PATH"' >> ~/.bashrc
    fi

    # Make PATH persistent in .zshrc if zsh is available
    if command -v zsh &> /dev/null && ! grep -q "/hal-9000/tools/bin" ~/.zshrc 2>/dev/null; then
        echo 'export PATH="/hal-9000/tools/bin:$PATH"' >> ~/.zshrc
    fi
fi

# Verify shared tools are available, fallback to individual installation if needed
if command -v tmux-cli &> /dev/null; then
    echo "✓ Using shared claude-code-tools installation (optimized)"
else
    # Fallback: Install individually (only if shared installation failed)
    echo "⚠ Shared tools not found, installing individually..."
    if command -v uv &> /dev/null; then
        uv tool install claude-code-tools
    else
        echo "⚠ uv not available, tmux-cli may not be accessible"
    fi
fi

# Verify beads is available
if command -v bd &> /dev/null; then
    echo "✓ bd (beads) CLI available"
else
    echo "⚠ bd not found in shared tools"
    echo "  Install manually: curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
fi

echo "HAL-9000 components configured for this container"
EOF
    chmod +x "$CLAUDEBOX_SHARED_DIR/setup.sh"

    echo ""
    echo -e "${GREEN}✓ ClaudeBox shared installation complete${NC}"
    echo ""
    echo "Shared directory: $CLAUDEBOX_SHARED_DIR"
    echo ""
    echo "ClaudeBox Configuration:"
    echo "  Mount in containers: -v $CLAUDEBOX_SHARED_DIR:/hal-9000"
    echo "  Run setup in container: /hal-9000/setup.sh"
    echo ""
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
if [[ "$INSTALL_HOST" == "true" ]] && [[ "$INSTALL_CLAUDEBOX_SHARED" == "true" ]]; then
    echo -e "${GREEN}║   ✓ HAL-9000 Complete Installation Finished!     ║${NC}"
elif [[ "$INSTALL_HOST" == "true" ]]; then
    echo -e "${GREEN}║     ✓ HAL-9000 Host Installation Complete!       ║${NC}"
else
    echo -e "${GREEN}║  ✓ HAL-9000 ClaudeBox Shared Install Complete!   ║${NC}"
fi
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$INSTALL_HOST" == "true" ]]; then
    echo "Installed Components (Host):"
    echo ""
    echo "MCP Servers:"
    echo "  • ChromaDB - Vector database for semantic search"
    echo "  • Memory Bank - Persistent memory across sessions"
    echo "  • Sequential Thinking - Advanced reasoning tool"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  • DEVONthink - Document research integration"
    fi
    echo ""
    echo "Issue Tracking:"
    echo "  • bd (beads) - Dependency-aware issue tracking for AI"
    echo "  • Run 'bd init' in your project to get started"
    echo ""
    echo "Session Management:"
    echo "  • /check - Save session context"
    echo "  • /load - Resume session"
    echo "  • /sessions - List all sessions"
    echo "  • /session-delete - Delete session"
    echo ""
    echo "Claude Code Tools:"
    echo "  • tmux-cli - Terminal automation"
    echo "  • find-session - Session search"
    echo "  • vault - Encrypted .env backup"
    echo "  • env-safe - Safe .env inspection"
    echo "  • Safety hooks installed"
    echo ""
    echo "Custom Agents:"
    echo "  • $AGENT_COUNT specialized agents installed to ~/.claude/agents/"
    echo "  • java-developer, java-architect-planner, code-review-expert, and more"
    echo "  • See AGENTS.md for full documentation"
    echo ""
    if [[ "$SKIP_HOST_ORCHESTRATION" == "false" ]]; then
        echo "Development Environments:"
        echo "  • claudebox - Docker-based environments"
        echo "  • aod - Multi-branch parallel development"
        echo ""
    fi
fi

if [[ "$INSTALL_CLAUDEBOX_SHARED" == "true" ]]; then
    echo "ClaudeBox Shared Installation:"
    echo "  Location: $CLAUDEBOX_SHARED_DIR"
    echo "  Components: MCP servers, tools, hooks, commands, agents, beads"
    echo "  All ClaudeBox containers will inherit these"
    echo ""
fi

echo "Next Steps:"
if [[ "$INSTALL_HOST" == "true" ]]; then
    echo "1. Restart Claude Code to load MCP servers and hooks"
    if [[ "$SKIP_HOST_ORCHESTRATION" == "false" ]]; then
        echo "2. Try: tmux-cli --help, vault --help, cs"
        echo "3. Test: /sessions, claudebox run"
    else
        echo "2. Try: tmux-cli --help, vault --help"
        echo "3. Test: /sessions"
    fi
fi
if [[ "$INSTALL_CLAUDEBOX_SHARED" == "true" ]]; then
    echo "• ClaudeBox: Mount $CLAUDEBOX_SHARED_DIR as /hal-9000 in containers"
    echo "• Run /hal-9000/setup.sh inside each container to configure"
fi
echo ""
echo "Documentation:"
echo "  • Main README: $SCRIPT_DIR/README.md"
echo "  • MCP Servers: $SCRIPT_DIR/mcp-servers/README.md"
echo "  • Commands: $SCRIPT_DIR/commands/README.md"
echo ""
