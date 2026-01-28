#!/bin/bash
# install-hal-9000.sh - Installation script for hal-9000
# Installs hal-9000 to system PATH
# Works whether run directly or via: curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash

set -Eeuo pipefail

readonly REPO_OWNER="Hellblazer"
readonly REPO_NAME="hal-9000"
readonly GITHUB_RAW="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main"
readonly INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
readonly INSTALL_DIR="$INSTALL_PREFIX/bin"
readonly HAL9000_DEST="$INSTALL_DIR/hal-9000"
readonly TEMP_DIR=$(mktemp -d)

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Cleanup temp directory on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

#==============================================================================
# Helper functions
#==============================================================================

info() {
    echo -e "${BLUE}ℹ $*${NC}"
}

success() {
    echo -e "${GREEN}✓ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

error() {
    echo -e "${RED}✗ Error: $*${NC}" >&2
    exit 1
}

#==============================================================================
# Installation functions
#==============================================================================

download_hal9000() {
    local hal9000_url="$GITHUB_RAW/hal-9000"
    local temp_script="$TEMP_DIR/hal-9000"

    info "Downloading hal-9000 from GitHub..." >&2

    if ! curl -fsSL "$hal9000_url" -o "$temp_script" 2>/dev/null; then
        error "Failed to download hal-9000. Check your internet connection."
    fi

    # Verify the script was downloaded
    if [[ ! -f "$temp_script" ]]; then
        error "hal-9000 script not found after download"
    fi

    # Make it executable
    chmod +x "$temp_script"

    success "hal-9000 downloaded successfully" >&2

    # Return the path to the downloaded script (only stdout, no messages)
    echo "$temp_script"
}

check_prerequisites() {
    info "Checking prerequisites..."

    # Check for write access to install directory
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Install directory does not exist: $INSTALL_DIR"
    fi

    if [[ ! -w "$INSTALL_DIR" ]]; then
        warn "No write access to $INSTALL_DIR (will try with sudo)"
    fi

    # Check for required tools
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker to use hal-9000."
    fi

    if ! command -v curl &> /dev/null; then
        warn "curl not found (needed for installer updates)"
    fi

    success "Prerequisites checked"
}

download_setup_script() {
    local setup_url="$GITHUB_RAW/scripts/setup-foundation-mcp.sh"
    local temp_script="$TEMP_DIR/setup-foundation-mcp.sh"

    if ! curl -fsSL "$setup_url" -o "$temp_script" 2>/dev/null; then
        warn "Failed to download setup-foundation-mcp.sh"
        return 1
    fi

    if [[ ! -f "$temp_script" ]]; then
        warn "setup-foundation-mcp.sh not found after download"
        return 1
    fi

    chmod +x "$temp_script"
    echo "$temp_script"
    return 0
}

install_hal9000() {
    local hal9000_script="$1"

    info "Installing hal-9000 to $HAL9000_DEST..."

    # Check if installation requires sudo
    if [[ ! -w "$INSTALL_DIR" ]]; then
        info "Installation requires elevated privileges"
        if ! sudo -v &> /dev/null; then
            error "sudo access required but not available"
        fi
        sudo cp "$hal9000_script" "$HAL9000_DEST"
        sudo chmod 755 "$HAL9000_DEST"
    else
        cp "$hal9000_script" "$HAL9000_DEST"
        chmod 755 "$HAL9000_DEST"
    fi

    success "hal-9000 installed to $HAL9000_DEST"
}

install_setup_script() {
    local setup_script="$1"
    local scripts_dir="$HOME/.hal9000/scripts"

    # Skip if download failed
    if [[ -z "$setup_script" ]] || [[ ! -f "$setup_script" ]]; then
        warn "Skipping setup-foundation-mcp.sh installation"
        return 0
    fi

    info "Installing setup-foundation-mcp.sh to $scripts_dir..."

    # Create directory if it doesn't exist
    mkdir -p "$scripts_dir"

    cp "$setup_script" "$scripts_dir/setup-foundation-mcp.sh"
    chmod 755 "$scripts_dir/setup-foundation-mcp.sh"

    success "setup-foundation-mcp.sh installed to $scripts_dir"
}

verify_installation() {
    info "Verifying installation..."

    # Check if hal-9000 is executable
    if ! "$HAL9000_DEST" --version &> /dev/null; then
        error "hal-9000 is not working. Try: $HAL9000_DEST --verify"
    fi

    local version
    version=$("$HAL9000_DEST" --version | head -1)
    success "Installed: $version"

    # Check if hal-9000 is in PATH
    if ! command -v hal-9000 &> /dev/null; then
        warn "hal-9000 not in PATH. Add $INSTALL_DIR to your PATH or restart your terminal."
    else
        success "hal-9000 is in PATH"
    fi

    # Run basic verification
    info "Running basic verification..."
    if "$HAL9000_DEST" --verify 2>&1 | grep -q "Prerequisites verified"; then
        success "Verification passed"
    else
        warn "Verification had warnings. Run: hal-9000 --diagnose"
    fi
}

show_post_install() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "You can now use hal-9000:"
    echo ""
    echo -e "${YELLOW}  Quick Start:${NC}"
    echo "    cd ~/your-project"
    echo "    hal-9000"
    echo ""
    echo -e "${YELLOW}  Set Up Foundation MCP Servers:${NC}"
    echo "    ~/.hal9000/scripts/setup-foundation-mcp.sh    Full setup"
    echo "    ~/.hal9000/scripts/setup-foundation-mcp.sh --help   All options"
    echo ""
    echo -e "${YELLOW}  More Options:${NC}"
    echo "    hal-9000 --help              Show all options"
    echo "    hal-9000 --diagnose          Check your setup"
    echo "    hal-9000 --profile python    Force a specific profile"
    echo ""
    echo -e "${YELLOW}  Documentation:${NC}"
    echo "    https://github.com/Hellblazer/hal-9000"
    echo ""
}

uninstall_hal9000() {
    info "Uninstalling hal-9000..."

    if [[ ! -f "$HAL9000_DEST" ]]; then
        warn "hal-9000 not found at $HAL9000_DEST"
        return 0
    fi

    # Check if uninstallation requires sudo
    if [[ ! -w "$INSTALL_DIR" ]]; then
        info "Uninstallation requires elevated privileges"
        if ! sudo -v &> /dev/null; then
            error "sudo access required but not available"
        fi
        sudo rm -f "$HAL9000_DEST"
    else
        rm -f "$HAL9000_DEST"
    fi

    success "hal-9000 uninstalled"
}

#==============================================================================
# Main entry point
#==============================================================================

main() {
    local action="${1:-install}"

    case "$action" in
        install)
            echo -e "${BLUE}hal-9000 Installation${NC}"
            echo "Destination: $HAL9000_DEST"
            echo ""
            check_prerequisites
            local hal9000_script
            hal9000_script=$(download_hal9000)
            install_hal9000 "$hal9000_script"

            # Download and install Foundation MCP setup script
            local setup_script
            setup_script=$(download_setup_script) || true
            install_setup_script "$setup_script"

            verify_installation
            show_post_install
            ;;
        uninstall)
            echo -e "${BLUE}hal-9000 Uninstallation${NC}"
            echo "Target: $HAL9000_DEST"
            echo ""
            uninstall_hal9000
            ;;
        verify)
            echo -e "${BLUE}Verifying Installation${NC}"
            echo ""
            verify_installation
            ;;
        *)
            echo "Usage: $0 [install|uninstall|verify]"
            echo ""
            echo "Commands:"
            echo "  install    Install hal-9000 to system (default)"
            echo "  uninstall  Remove hal-9000 from system"
            echo "  verify     Check existing installation"
            echo ""
            echo "Examples:"
            echo "  curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash"
            echo "  ./install-hal-9000.sh verify"
            echo "  ./install-hal-9000.sh uninstall"
            exit 1
            ;;
    esac
}

main "$@"
