#!/usr/bin/env bash
# worker-entrypoint.sh - HAL-9000 Worker Container Entrypoint
#
# Responsibilities:
# 1. Initialize Claude home directory
# 2. Set up MCP server configuration
# 3. Copy authentication from mounted volume
# 4. Launch Claude or passed command
#
# Environment Variables:
#   CLAUDE_HOME      - Claude configuration directory (default: /root/.claude)
#   WORKER_NAME      - Name of this worker (for logging)
#   ANTHROPIC_API_KEY - API key for Claude (optional if using session auth)

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

WORKER_NAME="${WORKER_NAME:-worker-$$}"

log_info() { printf "${CYAN}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[${WORKER_NAME}]${NC} %s\n" "$1" >&2; }

# ============================================================================
# CONFIGURATION
# ============================================================================

CLAUDE_HOME="${CLAUDE_HOME:-/root/.claude}"
WORKSPACE="${WORKSPACE:-/workspace}"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_claude_home() {
    log_info "Initializing Claude home: $CLAUDE_HOME"

    # Create Claude home structure
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$CLAUDE_HOME/agents"
    mkdir -p "$CLAUDE_HOME/commands"

    # Check for mounted authentication
    if [[ -f "$CLAUDE_HOME/.credentials.json" ]]; then
        log_success "Authentication credentials found"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_success "Using ANTHROPIC_API_KEY for authentication"
    else
        log_warn "No authentication found - Claude may prompt for login"
    fi
}

setup_mcp_config() {
    log_info "Setting up MCP configuration..."

    local settings_file="$CLAUDE_HOME/settings.json"

    # If settings.json already exists (mounted), preserve it
    if [[ -f "$settings_file" ]]; then
        log_info "Using mounted settings.json"
        return 0
    fi

    # Create minimal settings.json
    # Note: MCP servers run on HOST, not in container
    # Workers that need MCP should have host's settings mounted
    cat > "$settings_file" <<'EOF'
{
  "theme": "dark",
  "preferredNotificationChannel": "terminal",
  "verbose": false
}
EOF

    log_success "Created minimal settings.json"
    log_warn "Note: MCP servers run on host. Mount host's ~/.claude for MCP access."
}

setup_workspace() {
    log_info "Setting up workspace: $WORKSPACE"

    if [[ ! -d "$WORKSPACE" ]]; then
        mkdir -p "$WORKSPACE"
    fi

    cd "$WORKSPACE"

    # Check for git repository
    if [[ -d ".git" ]]; then
        log_info "Git repository detected"
        # Ensure git is configured for the workspace
        git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true
    fi
}

verify_claude() {
    log_info "Verifying Claude CLI..."

    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI not found in PATH"
        log_error "PATH: $PATH"
        exit 1
    fi

    local version
    version=$(claude --version 2>/dev/null || echo "unknown")
    log_success "Claude CLI version: $version"
}

print_worker_info() {
    echo
    echo "============================================"
    echo "  HAL-9000 Worker: $WORKER_NAME"
    echo "============================================"
    echo "  Claude Home: $CLAUDE_HOME"
    echo "  Workspace:   $WORKSPACE"
    echo "  User:        $(whoami)"
    echo "============================================"
    echo
}

# ============================================================================
# SIGNAL HANDLING
# ============================================================================

cleanup_on_exit() {
    log_info "Worker shutting down..."
    # Add any cleanup logic here
    exit 0
}

trap cleanup_on_exit SIGTERM SIGINT

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "HAL-9000 Worker starting..."

    # Run initialization
    init_claude_home
    setup_mcp_config
    setup_workspace
    verify_claude

    print_worker_info

    # Handle command
    case "${1:-claude}" in
        claude)
            # Default: run Claude interactively
            log_info "Starting Claude..."
            exec claude
            ;;
        claude-*)
            # Claude with subcommand
            exec claude "${1#claude-}" "${@:2}"
            ;;
        bash|sh)
            exec "$@"
            ;;
        sleep)
            # For background/test workers
            exec sleep "${2:-infinity}"
            ;;
        *)
            # Execute passed command
            exec "$@"
            ;;
    esac
}

main "$@"
