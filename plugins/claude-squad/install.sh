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
echo -e "${BLUE}║           Claude Squad Installer                 ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# GitHub repository
GITHUB_REPO="Hellblazer/claude-squad"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/smtg-ai/claude-squad/main/install.sh"

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

# Preflight check for dependencies
echo -e "${BLUE}Preflight Check${NC}"
echo ""

# Check tmux
echo -e "${BLUE}Checking tmux...${NC}"
TMUX_MISSING=false
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | cut -d' ' -f2)
    echo -e "${GREEN}✓ tmux $TMUX_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ tmux not found${NC}"
    TMUX_MISSING=true
fi

# Check GitHub CLI
echo ""
echo -e "${BLUE}Checking GitHub CLI (gh)...${NC}"
GH_MISSING=false
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n1 | cut -d' ' -f3)
    echo -e "${GREEN}✓ gh $GH_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ gh not found${NC}"
    GH_MISSING=true
fi

# Installation method selection
echo ""
echo -e "${BLUE}Choose Installation Method${NC}"
echo ""
echo "1) Homebrew (recommended, auto-installs dependencies)"
echo "2) Official installer script (auto-installs dependencies)"
echo ""

if $TMUX_MISSING || $GH_MISSING; then
    echo -e "${YELLOW}Note: Missing dependencies will be installed automatically${NC}"
    echo ""
fi

read -p "Select method [1]: " INSTALL_METHOD
INSTALL_METHOD=${INSTALL_METHOD:-1}

case $INSTALL_METHOD in
    1)
        # Homebrew installation
        if ! $HAS_BREW; then
            echo -e "${RED}Homebrew not found. Please choose another method or install Homebrew first.${NC}"
            echo "Visit: https://brew.sh"
            exit 1
        fi

        echo ""
        echo -e "${BLUE}Homebrew Installation${NC}"
        echo ""

        # Install dependencies first
        if $TMUX_MISSING; then
            echo "Installing tmux..."
            brew install tmux
        fi

        if $GH_MISSING; then
            echo "Installing GitHub CLI..."
            brew install gh
        fi

        # Check for homebrew tap
        echo "Checking for claude-squad in Homebrew..."
        if brew search claude-squad | grep -q "claude-squad"; then
            echo "Installing claude-squad from Homebrew..."
            brew install claude-squad

            # Create cs symlink
            BREW_PREFIX=$(brew --prefix)
            if [ ! -L "$BREW_PREFIX/bin/cs" ]; then
                echo "Creating 'cs' symlink..."
                ln -sf "$BREW_PREFIX/bin/claude-squad" "$BREW_PREFIX/bin/cs"
            fi
        else
            echo -e "${YELLOW}claude-squad not found in Homebrew repositories${NC}"
            echo "Falling back to official installer..."
            curl -fsSL "$INSTALL_SCRIPT_URL" | bash
        fi
        ;;

    2)
        # Official installer script
        echo ""
        echo -e "${BLUE}Official Installer${NC}"
        echo ""
        echo "This will download and run the official install script from GitHub."
        echo "The script will:"
        echo "  - Detect your platform and architecture"
        echo "  - Download the latest release"
        echo "  - Install to ~/.local/bin/cs"
        echo "  - Auto-install tmux and gh if missing"
        echo "  - Update your PATH if needed"
        echo ""

        read -p "Continue? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi

        echo ""
        echo "Downloading and running installer..."
        curl -fsSL "$INSTALL_SCRIPT_URL" | bash
        ;;

    *)
        echo -e "${RED}Invalid selection${NC}"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo -e "${BLUE}Verifying installation...${NC}"

# Check for cs command
if command -v cs &> /dev/null; then
    echo -e "${GREEN}✓ cs installed${NC}"
    CS_VERSION=$(cs version 2>/dev/null || echo "installed")
    echo "  Version: $CS_VERSION"
else
    # Check if claude-squad is installed but cs symlink missing
    if command -v claude-squad &> /dev/null; then
        echo -e "${YELLOW}⚠ claude-squad found but 'cs' symlink missing${NC}"
        echo ""
        echo "Create symlink with:"
        if $HAS_BREW; then
            BREW_PREFIX=$(brew --prefix)
            echo "  ln -sf $BREW_PREFIX/bin/claude-squad $BREW_PREFIX/bin/cs"
        else
            echo "  ln -sf ~/.local/bin/claude-squad ~/.local/bin/cs"
        fi
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        echo ""
        echo "Expected command 'cs' not found in PATH"

        # Check if installed to ~/.local/bin but not in PATH
        if [ -f "$HOME/.local/bin/cs" ]; then
            echo ""
            echo -e "${YELLOW}Found cs at ~/.local/bin/cs but not in PATH${NC}"
            echo "Add to your PATH by adding this to ~/.bashrc or ~/.zshrc:"
            echo ""
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "Then restart your shell or run: source ~/.bashrc"
        fi
        exit 1
    fi
fi

# Verify dependencies
echo ""
echo -e "${BLUE}Verifying dependencies...${NC}"

if command -v tmux &> /dev/null; then
    echo -e "${GREEN}✓ tmux installed${NC}"
else
    echo -e "${RED}✗ tmux not found${NC}"
    echo "Claude Squad requires tmux to function"
fi

if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓ gh (GitHub CLI) installed${NC}"
else
    echo -e "${RED}✗ gh not found${NC}"
    echo "Claude Squad requires GitHub CLI for PR management"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║     ✓ Claude Squad installed successfully!       ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Quick Start:"
echo "  cs                              # Launch Claude Squad"
echo "  cs -p \"aider\"                   # Launch with Aider"
echo "  cs -p \"codex\"                   # Launch with Codex"
echo "  cs -y                           # Auto-accept mode (experimental)"
echo ""
echo "Inside Claude Squad:"
echo "  n         - Create new session"
echo "  N         - Create new session with prompt"
echo "  ↵/o       - Attach to selected session"
echo "  ctrl-q    - Detach from session"
echo "  s         - Commit and push to GitHub"
echo "  c         - Checkout (pause session)"
echo "  r         - Resume paused session"
echo "  D         - Kill selected session"
echo "  tab       - Switch between preview/diff tabs"
echo "  q         - Quit"
echo ""
echo "Configuration:"
echo "  cs debug                        # Show config paths"
echo "  cs reset                        # Reset all instances"
echo ""
echo "Documentation:"
echo "  https://smtg-ai.github.io/claude-squad/"
echo "  https://github.com/$GITHUB_REPO"
echo ""
echo "Prerequisites verified:"
if command -v tmux &> /dev/null && command -v gh &> /dev/null; then
    echo -e "  ${GREEN}✓ All prerequisites installed${NC}"
    echo ""
    echo "You're ready to use Claude Squad!"
    echo "Run 'cs' to get started."
else
    if ! command -v tmux &> /dev/null; then
        echo -e "  ${RED}✗ tmux is required but not installed${NC}"
    fi
    if ! command -v gh &> /dev/null; then
        echo -e "  ${RED}✗ GitHub CLI (gh) is required but not installed${NC}"
    fi
    echo ""
    echo "Please install missing dependencies and try again."
fi
echo ""
