#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

    # Create settings file if it doesn't exist
    if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
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

        # Update settings.json with statusLine (object format)
        tmp_file=$(mktemp)
        jq --arg cmd "$STATUS_CMD" \
           '.statusLine = {type: "command", command: $cmd, padding: 0}' \
           "$CLAUDE_SETTINGS" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_SETTINGS"

        echo -e "${GREEN}✓ Configured ccstatusline in Claude Code settings${NC}"
        echo -e "  Using: ${CYAN}$STATUS_CMD${NC}"
        echo -e "  Run ${CYAN}bunx ccstatusline@latest${NC} to configure widgets interactively"
    else
        echo -e "${YELLOW}⚠ jq not found - skipping ccstatusline configuration${NC}"
        echo -e "  Manually add to $CLAUDE_SETTINGS:"
        echo -e '  {"statusLine": {"type": "command", "command": "bunx -y ccstatusline@latest", "padding": 0}}'
    fi

    # Download hooks
    HOOKS_DIR="$HOME/.claude/hooks/claude-code-tools"
    mkdir -p "$HOOKS_DIR"

    HOOKS_BASE_URL="https://raw.githubusercontent.com/pchalasani/claude-code-tools/main/hooks"
    HOOKS=(
        "bash_hook.py"
        "env_file_protection_hook.py"
        "file_size_conditional_hook.py"
        "git_add_block_hook.py"
        "git_checkout_safety_hook.py"
        "git_commit_block_hook.py"
        "grep_block_hook.py"
        "notification_hook.sh"
        "posttask_subtask_flag.py"
        "pretask_subtask_flag.py"
        "rm_block_hook.py"
    )

    echo "Downloading safety hooks..."
    for hook in "${HOOKS[@]}"; do
        curl -fsSL "$HOOKS_BASE_URL/$hook" -o "$HOOKS_DIR/$hook"
        chmod +x "$HOOKS_DIR/$hook"
    done

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
    echo "Commands: aod, aod-list, aod-attach, aod-stop, aod-cleanup, aod-send, aod-broadcast"
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

    # Install claude-code-tools to shared location
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installing Claude Code Tools (ClaudeBox Shared)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    # Create a note about tools installation
    cat > "$CLAUDEBOX_SHARED_DIR/tools/README.md" << 'EOF'
# Claude Code Tools for ClaudeBox

These tools are available in ClaudeBox containers:

- **tmux-cli**: Installed via `uv tool install claude-code-tools` in container
- **vault**: Encrypted .env backup (requires SOPS)
- **env-safe**: Safe .env inspection
- **find-session**: Session search

## Installation in Container

Run inside ClaudeBox container:
```bash
uv tool install claude-code-tools
```

This is automatically done if you use the ClaudeBox hal-9000 profile.
EOF

    # Copy hooks to shared location
    echo "Copying safety hooks to shared location..."
    SHARED_HOOKS_DIR="$CLAUDEBOX_SHARED_DIR/hooks"
    mkdir -p "$SHARED_HOOKS_DIR"

    HOOKS_BASE_URL="https://raw.githubusercontent.com/pchalasani/claude-code-tools/main/hooks"
    HOOKS=(
        "bash_hook.py"
        "env_file_protection_hook.py"
        "file_size_conditional_hook.py"
        "git_add_block_hook.py"
        "git_checkout_safety_hook.py"
        "git_commit_block_hook.py"
        "grep_block_hook.py"
        "notification_hook.sh"
        "posttask_subtask_flag.py"
        "pretask_subtask_flag.py"
        "rm_block_hook.py"
    )

    for hook in "${HOOKS[@]}"; do
        curl -fsSL "$HOOKS_BASE_URL/$hook" -o "$SHARED_HOOKS_DIR/$hook"
        chmod +x "$SHARED_HOOKS_DIR/$hook"
    done

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

    # Copy hal-9000 utility scripts to shared location
    echo "Copying hal-9000 utility scripts..."
    mkdir -p "$CLAUDEBOX_SHARED_DIR/scripts"
    cp "$SCRIPT_DIR/scripts"/*.sh "$CLAUDEBOX_SHARED_DIR/scripts/"
    chmod +x "$CLAUDEBOX_SHARED_DIR/scripts"/*.sh

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
ln -sf /hal-9000/aod/aod-list.sh ~/.local/bin/aod-list 2>/dev/null || true
ln -sf /hal-9000/aod/aod-attach.sh ~/.local/bin/aod-attach 2>/dev/null || true
ln -sf /hal-9000/aod/aod-stop.sh ~/.local/bin/aod-stop 2>/dev/null || true
ln -sf /hal-9000/aod/aod-cleanup.sh ~/.local/bin/aod-cleanup 2>/dev/null || true
ln -sf /hal-9000/aod/aod-send.sh ~/.local/bin/aod-send 2>/dev/null || true
ln -sf /hal-9000/aod/aod-broadcast.sh ~/.local/bin/aod-broadcast 2>/dev/null || true


# Install claude-code-tools if not already installed
if ! command -v tmux-cli &> /dev/null; then
    echo "Installing claude-code-tools..."
    uv tool install claude-code-tools
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
    echo "  Components: MCP servers, tools, hooks, commands, agents"
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
