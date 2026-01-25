#!/bin/bash
# install-claudy.sh - Installation script for claudy
# Installs claudy to system PATH and verifies the installation

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CLAUDY_SOURCE="$SCRIPT_DIR/claudy"
readonly INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
readonly INSTALL_DIR="$INSTALL_PREFIX/bin"
readonly CLAUDY_DEST="$INSTALL_DIR/claudy"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

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

check_prerequisites() {
    info "Checking prerequisites..."

    # Check if claudy source exists
    if [[ ! -f "$CLAUDY_SOURCE" ]]; then
        error "claudy script not found at $CLAUDY_SOURCE"
    fi

    # Check if claudy is executable
    if [[ ! -x "$CLAUDY_SOURCE" ]]; then
        error "claudy is not executable. Run: chmod +x $CLAUDY_SOURCE"
    fi

    # Check for write access to install directory
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Install directory does not exist: $INSTALL_DIR"
    fi

    if [[ ! -w "$INSTALL_DIR" ]]; then
        warn "No write access to $INSTALL_DIR (may need sudo)"
    fi

    success "Prerequisites checked"
}

install_claudy() {
    info "Installing claudy to $CLAUDY_DEST..."

    # Check if installation requires sudo
    if [[ ! -w "$INSTALL_DIR" ]]; then
        info "Installation requires elevated privileges"
        if ! sudo -v &> /dev/null; then
            error "sudo access required but not available"
        fi
        sudo cp "$CLAUDY_SOURCE" "$CLAUDY_DEST"
        sudo chmod 755 "$CLAUDY_DEST"
    else
        cp "$CLAUDY_SOURCE" "$CLAUDY_DEST"
        chmod 755 "$CLAUDY_DEST"
    fi

    success "claudy installed to $CLAUDY_DEST"
}

verify_installation() {
    info "Verifying installation..."

    # Check if claudy is in PATH
    if ! command -v claudy &> /dev/null; then
        warn "claudy not in PATH. You may need to restart your terminal."
    else
        success "claudy is in PATH"
    fi

    # Check if claudy is executable
    if ! "$CLAUDY_DEST" --version &> /dev/null; then
        error "claudy is not working. Try: $CLAUDY_DEST --verify"
    fi

    local version
    version=$("$CLAUDY_DEST" --version | head -1)
    success "Installed: $version"

    # Run basic verification
    info "Running basic verification..."
    if "$CLAUDY_DEST" --verify 2>&1 | grep -q "Prerequisites verified"; then
        success "Verification passed"
    else
        warn "Verification had warnings. Run: claudy --diagnose"
    fi
}

show_post_install() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "You can now use claudy:"
    echo ""
    echo -e "${YELLOW}  Quick Start:${NC}"
    echo "    cd ~/your-project"
    echo "    claudy"
    echo ""
    echo -e "${YELLOW}  More Options:${NC}"
    echo "    claudy --help              Show all options"
    echo "    claudy --diagnose          Check your setup"
    echo "    claudy --profile python    Force a specific profile"
    echo ""
    echo -e "${YELLOW}  Documentation:${NC}"
    echo "    https://github.com/hellblazer/hal-9000"
    echo ""
}

uninstall_claudy() {
    info "Uninstalling claudy..."

    if [[ ! -f "$CLAUDY_DEST" ]]; then
        warn "claudy not found at $CLAUDY_DEST"
        return 0
    fi

    # Check if uninstallation requires sudo
    if [[ ! -w "$INSTALL_DIR" ]]; then
        info "Uninstallation requires elevated privileges"
        if ! sudo -v &> /dev/null; then
            error "sudo access required but not available"
        fi
        sudo rm -f "$CLAUDY_DEST"
    else
        rm -f "$CLAUDY_DEST"
    fi

    success "claudy uninstalled"
}

#==============================================================================
# Main entry point
#==============================================================================

main() {
    local action="${1:-install}"

    case "$action" in
        install)
            echo -e "${BLUE}claudy Installation${NC}"
            echo "Destination: $CLAUDY_DEST"
            echo ""
            check_prerequisites
            install_claudy
            verify_installation
            show_post_install
            ;;
        uninstall)
            echo -e "${BLUE}claudy Uninstallation${NC}"
            echo "Target: $CLAUDY_DEST"
            echo ""
            uninstall_claudy
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
            echo "  install    Install claudy to system (default)"
            echo "  uninstall  Remove claudy from system"
            echo "  verify     Check existing installation"
            echo ""
            echo "Examples:"
            echo "  ./install-claudy.sh              # Install claudy"
            echo "  ./install-claudy.sh verify       # Check installation"
            echo "  ./install-claudy.sh uninstall    # Remove claudy"
            exit 1
            ;;
    esac
}

main "$@"
