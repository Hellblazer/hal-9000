#!/bin/bash
# install-hal-9000.sh - Installation script for hal-9000
# Installs hal-9000 to system PATH and verifies the installation

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly HAL9000_SOURCE="$SCRIPT_DIR/hal-9000"
readonly INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
readonly INSTALL_DIR="$INSTALL_PREFIX/bin"
readonly HAL9000_DEST="$INSTALL_DIR/hal-9000"

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

    # Check if hal-9000 source exists
    if [[ ! -f "$HAL9000_SOURCE" ]]; then
        error "hal-9000 script not found at $HAL9000_SOURCE"
    fi

    # Check if hal-9000 is executable
    if [[ ! -x "$HAL9000_SOURCE" ]]; then
        error "hal-9000 is not executable. Run: chmod +x $HAL9000_SOURCE"
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

install_hal-9000() {
    info "Installing hal-9000 to $HAL9000_DEST..."

    # Check if installation requires sudo
    if [[ ! -w "$INSTALL_DIR" ]]; then
        info "Installation requires elevated privileges"
        if ! sudo -v &> /dev/null; then
            error "sudo access required but not available"
        fi
        sudo cp "$HAL9000_SOURCE" "$HAL9000_DEST"
        sudo chmod 755 "$HAL9000_DEST"
    else
        cp "$HAL9000_SOURCE" "$HAL9000_DEST"
        chmod 755 "$HAL9000_DEST"
    fi

    success "hal-9000 installed to $HAL9000_DEST"
}

verify_installation() {
    info "Verifying installation..."

    # Check if hal-9000 is in PATH
    if ! command -v hal-9000 &> /dev/null; then
        warn "hal-9000 not in PATH. You may need to restart your terminal."
    else
        success "hal-9000 is in PATH"
    fi

    # Check if hal-9000 is executable
    if ! "$HAL9000_DEST" --version &> /dev/null; then
        error "hal-9000 is not working. Try: $HAL9000_DEST --verify"
    fi

    local version
    version=$("$HAL9000_DEST" --version | head -1)
    success "Installed: $version"

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
    echo -e "${YELLOW}  More Options:${NC}"
    echo "    hal-9000 --help              Show all options"
    echo "    hal-9000 --diagnose          Check your setup"
    echo "    hal-9000 --profile python    Force a specific profile"
    echo ""
    echo -e "${YELLOW}  Documentation:${NC}"
    echo "    https://github.com/hellblazer/hal-9000"
    echo ""
}

uninstall_hal-9000() {
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
            install_hal-9000
            verify_installation
            show_post_install
            ;;
        uninstall)
            echo -e "${BLUE}hal-9000 Uninstallation${NC}"
            echo "Target: $HAL9000_DEST"
            echo ""
            uninstall_hal-9000
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
            echo "  ./install-hal-9000.sh              # Install hal-9000"
            echo "  ./install-hal-9000.sh verify       # Check installation"
            echo "  ./install-hal-9000.sh uninstall    # Remove hal-9000"
            exit 1
            ;;
    esac
}

main "$@"
