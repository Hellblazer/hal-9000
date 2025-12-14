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
echo -e "${BLUE}║            ClaudeBox Installer                    ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# GitHub repository
GITHUB_REPO="Hellblazer/claudebox"
LATEST_RELEASE_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"

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

# Check Docker
echo -e "${BLUE}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    echo -e "${GREEN}✓ Docker $DOCKER_VERSION${NC}"

    # Check if Docker daemon is running
    if ! docker ps &> /dev/null; then
        echo -e "${YELLOW}⚠ Docker daemon not running${NC}"
        echo "Please start Docker and run this installer again."
        read -p "Continue anyway? (y/N): " CONTINUE_WITHOUT_DOCKER
        if [[ ! "$CONTINUE_WITHOUT_DOCKER" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⚠ Docker not found${NC}"
    read -p "Install Docker? (y/N): " INSTALL_DOCKER
    if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
        if $HAS_BREW; then
            echo "Installing Docker Desktop via Homebrew..."
            brew install --cask docker
            echo ""
            echo -e "${YELLOW}Please start Docker Desktop and run this installer again.${NC}"
            exit 0
        else
            echo -e "${YELLOW}Please install Docker manually:${NC}"
            echo "https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        echo -e "${RED}Docker is required for ClaudeBox${NC}"
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
        echo -e "${YELLOW}Note: tmux is required for squad mode${NC}"
    fi
fi

# Check bash
echo ""
echo -e "${BLUE}Checking bash...${NC}"
if command -v bash &> /dev/null; then
    BASH_VERSION=$(bash --version | head -n1 | cut -d' ' -f4)
    echo -e "${GREEN}✓ bash $BASH_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ bash not found${NC}"
    install_package "bash"
fi

# Installation method selection
echo ""
echo -e "${BLUE}Choose Installation Method${NC}"
echo ""
echo "1) Homebrew (recommended, macOS/Linux)"
echo "2) Self-extracting installer (download from GitHub)"
echo "3) Archive installation (tar.gz from GitHub)"
echo ""
read -p "Select method [1]: " INSTALL_METHOD
INSTALL_METHOD=${INSTALL_METHOD:-1}

case $INSTALL_METHOD in
    1)
        # Homebrew installation
        if ! $HAS_BREW; then
            echo -e "${RED}Homebrew not found. Please choose another method.${NC}"
            exit 1
        fi

        echo ""
        echo -e "${BLUE}Homebrew Installation${NC}"
        echo ""
        echo "Choose Homebrew installation source:"
        echo "1) Install from GitHub tap (if available)"
        echo "2) Download formula and install locally"
        echo ""
        read -p "Select [1]: " BREW_METHOD
        BREW_METHOD=${BREW_METHOD:-1}

        if [ "$BREW_METHOD" = "1" ]; then
            # Try to install from tap
            echo "Checking for claudebox tap..."
            if brew tap | grep -q "hellblazer/claudebox"; then
                echo "Installing from hellblazer/claudebox tap..."
                brew install hellblazer/claudebox/claudebox
            else
                echo "Adding hellblazer/claudebox tap..."
                brew tap hellblazer/claudebox
                brew install claudebox
            fi
        else
            # Download formula and install locally
            echo "Downloading formula from GitHub..."
            FORMULA_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/claudebox.rb"
            TEMP_FORMULA=$(mktemp)

            if curl -fsSL "$FORMULA_URL" -o "$TEMP_FORMULA"; then
                echo "Installing from local formula..."
                brew install "$TEMP_FORMULA"
                rm "$TEMP_FORMULA"
            else
                echo -e "${RED}Failed to download formula${NC}"
                exit 1
            fi
        fi
        ;;

    2)
        # Self-extracting installer
        echo ""
        echo -e "${BLUE}Self-Extracting Installer${NC}"
        echo ""

        # Get latest release info
        echo "Fetching latest release info..."
        if ! command -v jq &> /dev/null; then
            echo -e "${YELLOW}jq not found, will use grep to parse release info${NC}"
            DOWNLOAD_URL=$(curl -fsSL "$LATEST_RELEASE_URL" | grep -o 'https://.*claudebox\.run' | head -1)
        else
            DOWNLOAD_URL=$(curl -fsSL "$LATEST_RELEASE_URL" | jq -r '.assets[] | select(.name | endswith(".run")) | .browser_download_url')
        fi

        if [ -z "$DOWNLOAD_URL" ]; then
            echo -e "${RED}Could not find self-extracting installer in latest release${NC}"
            echo "Please choose another installation method."
            exit 1
        fi

        TEMP_INSTALLER=$(mktemp)
        echo "Downloading from: $DOWNLOAD_URL"
        curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_INSTALLER"
        chmod +x "$TEMP_INSTALLER"

        echo "Running installer..."
        "$TEMP_INSTALLER"
        rm "$TEMP_INSTALLER"
        ;;

    3)
        # Archive installation
        echo ""
        echo -e "${BLUE}Archive Installation${NC}"
        echo ""

        # Get latest release info
        echo "Fetching latest release info..."
        if ! command -v jq &> /dev/null; then
            DOWNLOAD_URL=$(curl -fsSL "$LATEST_RELEASE_URL" | grep -o 'https://.*claudebox-.*\.tar\.gz' | head -1)
        else
            DOWNLOAD_URL=$(curl -fsSL "$LATEST_RELEASE_URL" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url')
        fi

        if [ -z "$DOWNLOAD_URL" ]; then
            echo -e "${RED}Could not find archive in latest release${NC}"
            exit 1
        fi

        DEFAULT_INSTALL_DIR="$HOME/.local/share/claudebox"
        read -p "Install directory [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
        INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}

        mkdir -p "$INSTALL_DIR"

        TEMP_ARCHIVE=$(mktemp)
        echo "Downloading from: $DOWNLOAD_URL"
        curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_ARCHIVE"

        echo "Extracting to $INSTALL_DIR..."
        tar -xzf "$TEMP_ARCHIVE" -C "$INSTALL_DIR" --strip-components=1
        rm "$TEMP_ARCHIVE"

        # Create symlink
        BIN_DIR="$HOME/.local/bin"
        mkdir -p "$BIN_DIR"
        ln -sf "$INSTALL_DIR/main.sh" "$BIN_DIR/claudebox"
        chmod +x "$BIN_DIR/claudebox"

        # Create squad scripts symlinks
        for script in claudebox-squad cs-list cs-attach cs-stop cs-cleanup; do
            if [ -f "$INSTALL_DIR/${script}.sh" ]; then
                ln -sf "$INSTALL_DIR/${script}.sh" "$BIN_DIR/$script"
                chmod +x "$BIN_DIR/$script"
            fi
        done

        echo -e "${GREEN}✓ Installed to $INSTALL_DIR${NC}"
        echo "Symlink created at $BIN_DIR/claudebox"

        # Check if in PATH
        if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
            echo ""
            echo -e "${YELLOW}NOTE: $BIN_DIR is not in your PATH${NC}"
            echo "Add this line to your ~/.bashrc or ~/.zshrc:"
            echo ""
            echo "export PATH=\"$BIN_DIR:\$PATH\""
            echo ""
        fi
        ;;

    *)
        echo -e "${RED}Invalid selection${NC}"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo -e "${BLUE}Verifying installation...${NC}"
if command -v claudebox &> /dev/null; then
    echo -e "${GREEN}✓ claudebox installed${NC}"
    claudebox --help &> /dev/null || true
else
    echo -e "${RED}✗ claudebox not found in PATH${NC}"
    echo "Installation may have failed. Please check the output above."
    exit 1
fi

# Check for squad scripts
if command -v claudebox-squad &> /dev/null; then
    echo -e "${GREEN}✓ claudebox-squad installed${NC}"
fi
if command -v cs-list &> /dev/null; then
    echo -e "${GREEN}✓ Squad management scripts installed${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║      ✓ ClaudeBox installed successfully!         ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Quick Start:"
echo "  claudebox run                   # Start ClaudeBox"
echo "  claudebox list                  # List containers"
echo "  claudebox stop                  # Stop containers"
echo "  claudebox profiles              # List available profiles"
echo ""
echo "Squad Mode (Multi-Agent):"
echo "  claudebox-squad <config-file>   # Launch squad"
echo "  cs-list                         # List sessions"
echo "  cs-attach <name>                # Attach to session"
echo "  cs-cleanup                      # Cleanup all sessions"
echo ""
echo "Documentation:"
echo "  https://github.com/$GITHUB_REPO"
echo ""
echo "Next steps:"
echo "1. Ensure Docker is running"
echo "2. Run 'claudebox run' to start"
echo "3. Choose a development profile"
echo ""
