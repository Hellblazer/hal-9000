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
#   CLAUDE_HOME       - Claude config directory (default: /home/claude/.claude)
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

CLAUDE_HOME="${CLAUDE_HOME:-/home/claude/.claude}"
WORKSPACE="${WORKSPACE:-/workspace}"
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/data/memory-bank}"

# ChromaDB configuration
# If PARENT_IP is set (network decoupling mode), use it as ChromaDB host
# Otherwise, fall back to CHROMADB_HOST or localhost
CHROMADB_HOST="${CHROMADB_HOST:-}"
if [[ -z "$CHROMADB_HOST" && -n "${PARENT_IP:-}" ]]; then
    CHROMADB_HOST="${PARENT_IP}"
fi
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

    # Log ChromaDB configuration with network mode info
    if [[ -n "${PARENT_IP:-}" ]]; then
        log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT} (via PARENT_IP)"
    else
        log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT}"
    fi

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
    echo "  Add more via: claude plugin install <plugin>"
    echo "============================================"
    echo
    echo "Session State:"
    echo "  Session runs in TMUX (independent process manager)"
    echo "  State persists across detach/attach cycles"
    echo "  Use tmux-attach.sh to reconnect to session"
    echo
}

# ============================================================================
# SESSION STATE MANAGEMENT
# ============================================================================

# Session state with TMUX-based architecture:
# - Claude runs in TMUX pane, maintaining own session state
# - TMUX session persists across container operations
# - State file location: /home/claude/.claude/session.json (managed by Claude)
# - No need for external save/restore - TMUX handles persistence
# - For cross-container persistence, use Memory Bank MCP

ensure_session_persistence() {
    local session_dir="$CLAUDE_HOME"

    # Ensure session directory exists and is writable
    if [[ ! -d "$session_dir" ]]; then
        mkdir -p "$session_dir"
        chmod 0700 "$session_dir"
    fi

    # Session state will be managed by Claude CLI within TMUX
    # No action needed here - TMUX handles session persistence
    log_info "Session persistence configured (TMUX-based)"
}

# ============================================================================
# TMUX SESSION MANAGEMENT
# ============================================================================

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
TMUX_ENABLED="${TMUX_ENABLED:-true}"

init_tmux_sockets_dir() {
    if [[ "$TMUX_ENABLED" != "true" ]]; then
        log_info "TMUX disabled (TMUX_ENABLED=false)"
        return 0
    fi

    log_info "Initializing TMUX socket directory: $TMUX_SOCKET_DIR"

    mkdir -p "$TMUX_SOCKET_DIR"
    chmod 0777 "$TMUX_SOCKET_DIR"

    log_success "TMUX socket directory ready"
}

start_tmux_session() {
    if [[ "$TMUX_ENABLED" != "true" ]]; then
        log_info "TMUX disabled - starting Claude directly"
        return 1
    fi

    local tmux_socket="$TMUX_SOCKET_DIR/worker-${WORKER_NAME}.sock"
    local session_name="worker-${WORKER_NAME}"

    log_info "Starting TMUX session: $session_name"
    log_info "Socket path: $tmux_socket"

    # Kill any stale TMUX server with this socket
    tmux -S "$tmux_socket" kill-server 2>/dev/null || true
    sleep 0.5

    # Create TMUX session with Claude in first window
    tmux -S "$tmux_socket" new-session -d -s "$session_name" -x 120 -y 30 \
        "exec claude" 2>/dev/null || {
        log_error "Failed to create TMUX session"
        return 1
    }

    log_success "TMUX session created: $session_name"

    # Create additional shell window for debugging
    tmux -S "$tmux_socket" new-window -t "$session_name" -n "shell" -c "$WORKSPACE" \
        "exec bash" 2>/dev/null || {
        log_warn "Failed to create shell window"
    }

    log_success "Added shell debug window"

    # Export socket path for later use
    export TMUX_SOCKET="$tmux_socket"

    return 0
}

# ============================================================================
# SIGNAL HANDLING
# ============================================================================

cleanup_on_exit() {
    log_info "Worker shutting down..."

    if [[ "$TMUX_ENABLED" == "true" && -n "${TMUX_SOCKET:-}" ]]; then
        log_info "Cleaning up TMUX server..."
        tmux -S "$TMUX_SOCKET" kill-server 2>/dev/null || true
    fi

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
    init_tmux_sockets_dir
    ensure_session_persistence

    print_worker_info

    # Handle command
    case "${1:-claude}" in
        claude)
            log_info "Starting Claude..."
            if start_tmux_session; then
                log_success "TMUX session ready - keeping worker alive"
                # Keep worker process alive (TMUX session is managing Claude)
                exec tail -f /dev/null
            else
                log_warn "TMUX failed - falling back to direct execution"
                exec claude
            fi
            ;;
        claude-*)
            # For non-standard Claude modes, run directly
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
