#!/usr/bin/env bash
# worker-entrypoint.sh - HAL-9000 Worker Container Entrypoint
#
# Responsibilities:
# 1. Initialize CLAUDE_HOME (shared volume for marketplace)
# 2. Configure foundation MCP servers (chromadb, memory-bank, sequential-thinking)
# 3. Set up workspace
# 4. Launch Claude or passed command
#
# Environment Variables:
#   CLAUDE_HOME       - Claude config directory (default: /root/.claude)
#   WORKSPACE         - Working directory (default: /workspace)
#   MEMORY_BANK_ROOT  - Memory bank data (default: /data/memory-bank)
#   CHROMADB_HOST     - ChromaDB server host (default: localhost)
#   CHROMADB_PORT     - ChromaDB server port (default: 8000)
#   ANTHROPIC_API_KEY - API key for Claude (optional if using session auth)
#   WORKER_NAME       - Name of this worker (for logging)

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
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/data/memory-bank}"
CHROMADB_HOST="${CHROMADB_HOST:-localhost}"
CHROMADB_PORT="${CHROMADB_PORT:-8000}"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_claude_home() {
    log_info "Initializing Claude home: $CLAUDE_HOME"

    # Ensure Claude home structure exists
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$MEMORY_BANK_ROOT"

    # Check for authentication
    if [[ -f "$CLAUDE_HOME/.credentials.json" ]]; then
        log_success "Authentication credentials found"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_success "Using ANTHROPIC_API_KEY for authentication"
    else
        log_warn "No authentication found - Claude may prompt for login"
    fi
}

setup_foundation_mcp() {
    log_info "Configuring foundation MCP servers..."

    local settings_file="$CLAUDE_HOME/settings.json"

    # If settings.json exists, merge our foundation servers
    # Otherwise create fresh config
    if [[ -f "$settings_file" ]]; then
        log_info "Existing settings.json found - preserving marketplace installs"
        # Check if our foundation servers are already configured
        if grep -q '"memory-bank"' "$settings_file" 2>/dev/null; then
            log_info "Foundation MCP servers already configured"
            return 0
        fi
        # TODO: merge foundation servers into existing config
        # For now, we'll leave existing config alone
        log_warn "Adding foundation servers to existing config not yet implemented"
        return 0
    fi

    # Create settings.json with foundation MCP servers
    cat > "$settings_file" <<EOF
{
  "theme": "dark",
  "preferredNotificationChannel": "terminal",
  "verbose": false,
  "mcpServers": {
    "memory-bank": {
      "command": "mcp-server-memory-bank",
      "args": [],
      "env": {
        "MEMORY_BANK_ROOT": "${MEMORY_BANK_ROOT}"
      }
    },
    "sequential-thinking": {
      "command": "mcp-server-sequential-thinking",
      "args": []
    },
    "chromadb": {
      "command": "chroma-mcp",
      "args": [
        "--client-type", "http",
        "--host", "${CHROMADB_HOST}",
        "--port", "${CHROMADB_PORT}"
      ]
    }
  }
}
EOF

    log_success "Foundation MCP servers configured:"
    log_info "  - memory-bank: ${MEMORY_BANK_ROOT}"
    log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT}"
    log_info "  - sequential-thinking: enabled"
}

setup_workspace() {
    log_info "Setting up workspace: $WORKSPACE"

    if [[ ! -d "$WORKSPACE" ]]; then
        mkdir -p "$WORKSPACE"
    fi

    cd "$WORKSPACE"

    # Configure git safe directory if repo detected
    if [[ -d ".git" ]]; then
        log_info "Git repository detected"
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

verify_mcp_servers() {
    log_info "Verifying foundation MCP servers..."

    local all_ok=true

    if command -v mcp-server-memory-bank &>/dev/null; then
        log_success "  memory-bank: ready"
    else
        log_warn "  memory-bank: not found"
        all_ok=false
    fi

    if command -v mcp-server-sequential-thinking &>/dev/null; then
        log_success "  sequential-thinking: ready"
    else
        log_warn "  sequential-thinking: not found"
        all_ok=false
    fi

    if command -v chroma-mcp &>/dev/null; then
        log_success "  chromadb: ready"
    else
        log_warn "  chromadb: not found"
        all_ok=false
    fi

    if [[ "$all_ok" == "true" ]]; then
        log_success "All foundation MCP servers available"
    fi
}

print_worker_info() {
    echo
    echo "============================================"
    echo "  HAL-9000 Worker: $WORKER_NAME"
    echo "============================================"
    echo "  Claude Home:   $CLAUDE_HOME"
    echo "  Workspace:     $WORKSPACE"
    echo "  Memory Bank:   $MEMORY_BANK_ROOT"
    echo "  ChromaDB:      http://${CHROMADB_HOST}:${CHROMADB_PORT}"
    echo "============================================"
    echo "  Foundation: memory-bank, chromadb, sequential-thinking"
    echo "  Add more via: claude marketplace install <plugin>"
    echo "============================================"
    echo
}

# ============================================================================
# SIGNAL HANDLING
# ============================================================================

cleanup_on_exit() {
    log_info "Worker shutting down..."
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
    setup_foundation_mcp
    setup_workspace
    verify_claude
    verify_mcp_servers

    print_worker_info

    # Handle command
    case "${1:-claude}" in
        claude)
            log_info "Starting Claude..."
            exec claude
            ;;
        claude-*)
            exec claude "${1#claude-}" "${@:2}"
            ;;
        bash|sh)
            exec "$@"
            ;;
        sleep)
            exec sleep "${2:-infinity}"
            ;;
        *)
            exec "$@"
            ;;
    esac
}

main "$@"
