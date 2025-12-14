#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║         Claude Code Tools Installer               ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Detect package manager
HAS_BREW=false
HAS_APT=false
HAS_DNF=false

if command -v brew &> /dev/null; then
    HAS_BREW=true
    PACKAGE_MANAGER="homebrew"
elif command -v apt-get &> /dev/null; then
    HAS_APT=true
    PACKAGE_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    HAS_DNF=true
    PACKAGE_MANAGER="dnf"
else
    PACKAGE_MANAGER="none"
fi

echo -e "${BLUE}Detected package manager: ${PACKAGE_MANAGER}${NC}"
echo ""

# Function to install package
install_package() {
    local package=$1
    local brew_name=${2:-$package}
    local apt_name=${3:-$package}
    local dnf_name=${4:-$package}

    echo -e "${YELLOW}Installing ${package}...${NC}"

    if $HAS_BREW; then
        brew install "$brew_name"
    elif $HAS_APT; then
        sudo apt-get update && sudo apt-get install -y "$apt_name"
    elif $HAS_DNF; then
        sudo dnf install -y "$dnf_name"
    else
        echo -e "${RED}No package manager detected. Please install $package manually.${NC}"
        return 1
    fi
}

# Check Python 3.11+
echo -e "${BLUE}Checking Python...${NC}"
PYTHON_OK=false
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
        echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}"
        PYTHON_OK=true
    else
        echo -e "${YELLOW}⚠ Python $PYTHON_VERSION found, but 3.11+ required${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Python not found${NC}"
fi

if ! $PYTHON_OK; then
    read -p "Install Python 3.11+? (y/N): " INSTALL_PYTHON
    if [[ "$INSTALL_PYTHON" =~ ^[Yy]$ ]]; then
        if $HAS_BREW; then
            brew install python@3.11
        else
            echo -e "${YELLOW}Please install Python 3.11+ manually: https://www.python.org/downloads/${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Python 3.11+ is required${NC}"
        exit 1
    fi
fi

# Check uv
echo ""
echo -e "${BLUE}Checking uv...${NC}"
if command -v uv &> /dev/null; then
    echo -e "${GREEN}✓ uv installed${NC}"
else
    echo -e "${YELLOW}⚠ uv not found${NC}"
    read -p "Install uv? (y/N): " INSTALL_UV
    if [[ "$INSTALL_UV" =~ ^[Yy]$ ]]; then
        if $HAS_BREW; then
            brew install uv
        else
            echo "Installing uv via curl..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            # Add to PATH for this session
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
    else
        echo -e "${RED}uv is required for installation${NC}"
        exit 1
    fi
fi

# Check tmux
echo ""
echo -e "${BLUE}Checking tmux...${NC}"
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | cut -d' ' -f2)
    echo -e "${GREEN}✓ tmux $TMUX_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ tmux not found${NC}"
    read -p "Install tmux? (y/N): " INSTALL_TMUX
    if [[ "$INSTALL_TMUX" =~ ^[Yy]$ ]]; then
        install_package "tmux"
    else
        echo -e "${YELLOW}Note: tmux is required for tmux-cli functionality${NC}"
    fi
fi

# Check SOPS (optional, for vault)
echo ""
echo -e "${BLUE}Checking SOPS (optional, for vault)...${NC}"
if command -v sops &> /dev/null; then
    SOPS_VERSION=$(sops --version 2>&1 | head -n1 | awk '{print $2}')
    echo -e "${GREEN}✓ SOPS $SOPS_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ SOPS not found${NC}"
    read -p "Install SOPS for vault functionality? (y/N): " INSTALL_SOPS
    if [[ "$INSTALL_SOPS" =~ ^[Yy]$ ]]; then
        if $HAS_BREW; then
            brew install sops
        else
            echo -e "${YELLOW}Please install SOPS manually: https://github.com/mozilla/sops${NC}"
        fi
    fi
fi

# Check jq (needed for config merging)
echo ""
echo -e "${BLUE}Checking jq...${NC}"
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq installed${NC}"
else
    echo -e "${YELLOW}⚠ jq not found${NC}"
    read -p "Install jq for automatic config merging? (y/N): " INSTALL_JQ
    if [[ "$INSTALL_JQ" =~ ^[Yy]$ ]]; then
        install_package "jq"
    fi
fi

# Check Rust/Cargo (optional, for lmsh)
echo ""
echo -e "${BLUE}Checking Rust (optional, for lmsh)...${NC}"
RUST_AVAILABLE=false
if command -v cargo &> /dev/null; then
    RUST_VERSION=$(rustc --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ Rust $RUST_VERSION${NC}"
    RUST_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ Rust not found${NC}"
    echo "lmsh (natural language shell) requires Rust"
    read -p "Install Rust for lmsh? (y/N): " INSTALL_RUST
    if [[ "$INSTALL_RUST" =~ ^[Yy]$ ]]; then
        if $HAS_BREW; then
            brew install rust
            RUST_AVAILABLE=true
        else
            echo "Installing Rust via rustup..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
            source "$HOME/.cargo/env"
            RUST_AVAILABLE=true
        fi
    fi
fi

# Install claude-code-tools from PyPI
echo ""
echo -e "${BLUE}Installing claude-code-tools from PyPI...${NC}"
uv tool install --force claude-code-tools

# Verify installation
echo ""
echo -e "${BLUE}Verifying installation...${NC}"
TOOLS_INSTALLED=true
for tool in tmux-cli find-session find-claude-session vault env-safe; do
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓ $tool${NC}"
    else
        echo -e "${RED}✗ $tool not found${NC}"
        TOOLS_INSTALLED=false
    fi
done

if ! $TOOLS_INSTALLED; then
    echo ""
    echo -e "${YELLOW}Some tools not found in PATH. Add to your shell config:${NC}"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Optional: Install lmsh
if $RUST_AVAILABLE; then
    echo ""
    read -p "Install lmsh (natural language shell)? (y/N): " INSTALL_LMSH
    if [[ "$INSTALL_LMSH" =~ ^[Yy]$ ]]; then
        echo "Installing lmsh from crates.io..."
        cargo install lmsh
    fi
fi

# Download hooks from GitHub
echo ""
echo -e "${BLUE}Downloading safety hooks from GitHub...${NC}"
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

echo "Downloading hooks to $HOOKS_DIR..."
for hook in "${HOOKS[@]}"; do
    echo "  Downloading $hook..."
    curl -fsSL "$HOOKS_BASE_URL/$hook" -o "$HOOKS_DIR/$hook"
    chmod +x "$HOOKS_DIR/$hook"
done

echo -e "${GREEN}✓ Hooks downloaded${NC}"

# Configure hooks in Claude settings
echo ""
echo -e "${BLUE}Configuring Claude Code Hooks${NC}"
echo ""

# Determine Claude config path
if [[ "$OSTYPE" == "darwin"* ]]; then
    CLAUDE_SETTINGS="$HOME/Library/Application Support/Claude/settings.json"
else
    CLAUDE_SETTINGS="$HOME/.config/Claude/settings.json"
fi

# Create hooks config with actual path
HOOKS_CONFIG=$(cat <<EOF
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/notification_hook.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/bash_hook.py"
          }
        ]
      },
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/file_size_conditional_hook.py"
          }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/pretask_subtask_flag.py"
          }
        ]
      },
      {
        "matcher": "Grep",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/grep_block_hook.py"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/posttask_subtask_flag.py"
          }
        ]
      }
    ]
  }
}
EOF
)

if [ -f "$CLAUDE_SETTINGS" ]; then
    echo -e "${YELLOW}Found existing Claude settings${NC}"
    read -p "Merge hooks into Claude settings? (y/N): " MERGE_HOOKS

    if [[ "$MERGE_HOOKS" =~ ^[Yy]$ ]]; then
        # Backup
        BACKUP_PATH="${CLAUDE_SETTINGS}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$CLAUDE_SETTINGS" "$BACKUP_PATH"
        echo "Backed up to: $BACKUP_PATH"

        if command -v jq &> /dev/null; then
            TMP_CONFIG=$(mktemp)
            jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" <(echo "$HOOKS_CONFIG") > "$TMP_CONFIG"
            mv "$TMP_CONFIG" "$CLAUDE_SETTINGS"
            echo -e "${GREEN}✓ Hooks merged successfully!${NC}"
        else
            echo ""
            echo -e "${YELLOW}jq not found. Please manually merge this config:${NC}"
            echo ""
            echo "$HOOKS_CONFIG"
            echo ""
            echo "Into: $CLAUDE_SETTINGS"
        fi
    fi
else
    echo "Creating Claude settings: $CLAUDE_SETTINGS"
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo "$HOOKS_CONFIG" > "$CLAUDE_SETTINGS"
    echo -e "${GREEN}✓ Settings created!${NC}"
fi

# Add CLAUDE.md snippet
echo ""
echo -e "${BLUE}Global CLAUDE.md Configuration${NC}"
echo ""
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

TMUX_CLI_SNIPPET=$(cat <<'EOF'

## tmux-cli: Interactive CLI Control

`tmux-cli` enables Claude Code to control CLI applications in separate tmux panes.
Run `tmux-cli --help` for full documentation.

### Core Commands
- `tmux-cli launch "command"` - Launch application in new pane (returns pane ID)
- `tmux-cli send "text" --pane=ID` - Send input to pane
- `tmux-cli capture --pane=ID` - Get output from pane
- `tmux-cli wait_idle --pane=ID` - Wait for command to finish (avoid polling)
- `tmux-cli kill --pane=ID` - Terminate pane
- `tmux-cli status` - Show all panes and current state

### Critical Pattern: Always Launch Shell First
```bash
tmux-cli launch "zsh"           # Returns pane ID (e.g., 2)
tmux-cli send "python script.py" --pane=2
tmux-cli wait_idle --pane=2
tmux-cli capture --pane=2
```
**Why?** If you launch a command directly and it errors, the pane closes immediately
and you lose all output. Shell keeps pane alive.

### When to Use tmux-cli
- **Interactive debugging**: Python pdb, gdb, interactive REPLs
- **Spawn Claude Code instances**: Parallel analysis/review/debugging
- **Long-running processes**: Monitor output, send signals (Ctrl+C via `interrupt`)
- **Web app testing**: Launch servers, coordinate with browser automation MCPs
- **Scripts waiting for input**: Interactive installers, configuration wizards

### When NOT to Use tmux-cli
- Simple one-shot commands → Use regular `Bash` tool
- Background tasks without interaction → Use `Bash` with `run_in_background`
- File operations → Use dedicated tools (Read, Write, Edit, Grep, Glob)
EOF
)

if [ -f "$CLAUDE_MD" ]; then
    echo -e "${YELLOW}Found existing CLAUDE.md${NC}"
    read -p "Add tmux-cli documentation to CLAUDE.md? (y/N): " ADD_TMUX_DOC
    if [[ "$ADD_TMUX_DOC" =~ ^[Yy]$ ]]; then
        # Check if already exists
        if grep -q "tmux-cli: Interactive CLI Control" "$CLAUDE_MD"; then
            echo "tmux-cli documentation already in CLAUDE.md"
        else
            echo "$TMUX_CLI_SNIPPET" >> "$CLAUDE_MD"
            echo -e "${GREEN}✓ Added tmux-cli documentation${NC}"
        fi
    fi
else
    echo "Creating CLAUDE.md with tmux-cli documentation"
    mkdir -p "$(dirname "$CLAUDE_MD")"
    echo "$TMUX_CLI_SNIPPET" > "$CLAUDE_MD"
    echo -e "${GREEN}✓ CLAUDE.md created${NC}"
fi

# Shell functions
echo ""
echo -e "${BLUE}Shell Functions (Optional)${NC}"
echo ""
echo "Add these functions to your ~/.bashrc or ~/.zshrc for better workflow:"
echo ""
echo -e "${YELLOW}# Find sessions (unified search)${NC}"
cat <<'EOF'
fs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-session --help
        return
    fi
    eval "$(find-session --shell "$@" | sed '/^$/d')"
}
EOF

echo ""
echo -e "${YELLOW}# Find Claude sessions${NC}"
cat <<'EOF'
fcs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-claude-session --help
        return
    fi
    eval "$(find-claude-session --shell "$@" | sed '/^$/d')"
}
EOF

echo ""
read -p "Copy shell functions snippet to clipboard? (requires pbcopy/xclip) (y/N): " COPY_FUNCS
if [[ "$COPY_FUNCS" =~ ^[Yy]$ ]]; then
    SHELL_FUNCS=$(cat <<'EOF'
# Claude Code Tools shell functions
fs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-session --help
        return
    fi
    eval "$(find-session --shell "$@" | sed '/^$/d')"
}

fcs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-claude-session --help
        return
    fi
    eval "$(find-claude-session --shell "$@" | sed '/^$/d')"
}
EOF
)
    if command -v pbcopy &> /dev/null; then
        echo "$SHELL_FUNCS" | pbcopy
        echo -e "${GREEN}✓ Copied to clipboard${NC}"
    elif command -v xclip &> /dev/null; then
        echo "$SHELL_FUNCS" | xclip -selection clipboard
        echo -e "${GREEN}✓ Copied to clipboard${NC}"
    else
        echo -e "${YELLOW}Clipboard tool not found. Functions shown above.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║   ✓ Claude Code Tools installed successfully!    ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed tools:"
echo "  - tmux-cli: Terminal automation for AI agents"
echo "  - find-session: Unified session search"
echo "  - find-claude-session: Claude session finder"
echo "  - vault: Encrypted .env backup"
echo "  - env-safe: Safe .env inspection"
if $RUST_AVAILABLE && command -v lmsh &> /dev/null; then
    echo "  - lmsh: Natural language shell"
fi
echo ""
echo "Hooks installed to: $HOOKS_DIR"
echo ""
echo "Next steps:"
echo "1. Add shell functions to ~/.bashrc or ~/.zshrc (see above)"
echo "2. Restart Claude Code to load hooks"
echo "3. Try: tmux-cli --help, find-session --help, vault --help"
echo "4. Read documentation: https://github.com/pchalasani/claude-code-tools"
echo ""
