#!/usr/bin/env bash
# worker-entrypoint.sh - HAL-9000 Worker Container Entrypoint
#
# Responsibilities:
# 1. Initialize Claude home directory
# 2. Set up MCP server configuration (pre-installed in container)
# 3. Copy authentication from mounted volume
# 4. Launch Claude or passed command
#
# Environment Variables:
#   CLAUDE_HOME       - Claude configuration directory (default: /root/.claude)
#   WORKER_NAME       - Name of this worker (for logging)
#   ANTHROPIC_API_KEY - API key for Claude (optional if using session auth)
#   MEMORY_BANK_ROOT  - Memory bank data directory (default: /root/memory-bank)
#   CHROMADB_HOST     - ChromaDB server host (default: localhost)
#   CHROMADB_PORT     - ChromaDB server port (default: 8000)

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
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/root/memory-bank}"
CHROMADB_HOST="${CHROMADB_HOST:-localhost}"
CHROMADB_PORT="${CHROMADB_PORT:-8000}"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_claude_home() {
    log_info "Initializing Claude home: $CLAUDE_HOME"

    # Create Claude home structure
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$CLAUDE_HOME/agents"
    mkdir -p "$CLAUDE_HOME/commands"
    mkdir -p "$MEMORY_BANK_ROOT"

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

    # Create settings.json with pre-installed MCP servers
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

    log_success "Created settings.json with MCP servers configured"
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

    # Check for git repository
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
    log_info "Verifying MCP servers..."

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
        log_success "  chroma-mcp: ready"
    else
        log_warn "  chroma-mcp: not found"
        all_ok=false
    fi

    if [[ "$all_ok" == "true" ]]; then
        log_success "All MCP servers available"
    fi
}

print_worker_info() {
    echo
    echo "============================================"
    echo "  HAL-9000 Worker: $WORKER_NAME"
    echo "============================================"
    echo "  Claude Home:  $CLAUDE_HOME"
    echo "  Workspace:    $WORKSPACE"
    echo "  Memory Bank:  $MEMORY_BANK_ROOT"
    echo "  ChromaDB:     http://${CHROMADB_HOST}:${CHROMADB_PORT}"
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
    setup_mcp_config
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
