#!/usr/bin/env bash
set -Eeuo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${BLUE}Installing Beads (bd) Issue Tracker...${NC}"
echo ""

# Install bd CLI via Homebrew
if command -v brew &> /dev/null; then
    if ! command -v bd &> /dev/null; then
        echo "Installing bd CLI via Homebrew..."
        brew tap steveyegge/beads
        brew install bd
        echo -e "${GREEN}✓ bd CLI installed${NC}"
    else
        BD_VERSION=$(bd --version 2>/dev/null || echo 'version unknown')
        echo -e "${GREEN}✓ bd CLI already installed ($BD_VERSION)${NC}"
    fi
else
    echo -e "${YELLOW}Homebrew not found. Install bd manually:${NC}"
    echo "  Option 1: brew tap steveyegge/beads && brew install bd"
    echo "  Option 2: curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
    echo ""
    read -rp "Continue without bd CLI? (y/N): " continue_without_bd
    if [[ ! "$continue_without_bd" =~ ^[Yy]$ ]]; then
        echo "Aborted. Install bd CLI first."
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✓ Beads (bd) installed successfully!${NC}"
echo ""
echo "Quick Start:"
echo "  1. cd your-project"
echo "  2. bd init"
echo "  3. bd create \"First task\" -t task"
echo "  4. bd ready  # Show work ready to do"
echo "  5. bd onboard  # Get Claude integration guide"
echo ""
