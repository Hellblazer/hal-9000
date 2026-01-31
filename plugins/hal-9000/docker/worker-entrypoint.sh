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
#   WORKER_NAME       - Name of this worker (for logging)
#
# Secret Files (SECURITY: preferred over environment variables):
#   /run/secrets/anthropic_key     - Anthropic API key (mounted read-only)
#   /run/secrets/chromadb_api_key  - ChromaDB API key (mounted read-only)
#   /run/secrets/chromadb_token    - ChromaDB auth token (mounted read-only)
#
# SECURITY NOTE: API keys should be passed via secret files, NOT environment variables.
# Environment variables are visible via 'docker inspect' and /proc/1/environ.
# Secret files mounted read-only are much more secure.

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
# RESILIENCE FUNCTIONS
# ============================================================================

# retry_with_backoff: Execute command with exponential backoff
# Usage: retry_with_backoff "command" [max_retries]
# Default: 3 retries with backoff of 1s, 2s, 4s
retry_with_backoff() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local attempt=1
    local wait_time=1

    while [[ $attempt -le $max_retries ]]; do
        if eval "$cmd"; then
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            log_warn "Command failed (attempt $attempt/$max_retries), retrying in ${wait_time}s: $cmd"
            sleep "$wait_time"
            wait_time=$((wait_time * 2))
        else
            log_error "Command failed after $max_retries attempts: $cmd"
            return 1
        fi

        ((attempt++))
    done

    return 1
}

# circuit_breaker: Track failures and open circuit after threshold
# Global circuit state: CIRCUIT_BREAKER_STATE and CIRCUIT_BREAKER_FAILURES
declare -gA CIRCUIT_BREAKER_STATE
declare -gA CIRCUIT_BREAKER_FAILURES
declare -gA CIRCUIT_BREAKER_LAST_ATTEMPT

circuit_breaker() {
    local service_name="$1"
    local cmd="$2"
    local failure_threshold="${3:-5}"
    local half_open_wait="${4:-30}"

    local state="${CIRCUIT_BREAKER_STATE[$service_name]:-closed}"
    local failures="${CIRCUIT_BREAKER_FAILURES[$service_name]:-0}"
    local last_attempt="${CIRCUIT_BREAKER_LAST_ATTEMPT[$service_name]:-0}"
    local now
    now=$(date +%s)

    # OPEN: Circuit is open, reject immediately
    if [[ "$state" == "open" ]]; then
        local elapsed=$((now - last_attempt))
        if [[ $elapsed -ge $half_open_wait ]]; then
            log_warn "Circuit breaker transitioning to half-open ($service_name)"
            CIRCUIT_BREAKER_STATE[$service_name]="half-open"
            state="half-open"
        else
            log_error "Circuit breaker OPEN ($service_name) - rejecting request (wait ${half_open_wait}s)"
            return 1
        fi
    fi

    # HALF-OPEN or CLOSED: Try to execute command
    if eval "$cmd"; then
        # Success: reset failures and close circuit
        CIRCUIT_BREAKER_FAILURES[$service_name]=0
        CIRCUIT_BREAKER_STATE[$service_name]="closed"
        if [[ "$state" == "half-open" ]]; then
            log_success "Circuit breaker CLOSED ($service_name) - service recovered"
        fi
        return 0
    else
        # Failure: increment counter
        ((failures++))
        CIRCUIT_BREAKER_FAILURES[$service_name]=$failures

        if [[ $failures -ge $failure_threshold ]]; then
            log_error "Circuit breaker OPEN ($service_name) - $failures failures reached threshold ($failure_threshold)"
            CIRCUIT_BREAKER_STATE[$service_name]="open"
            CIRCUIT_BREAKER_LAST_ATTEMPT[$service_name]=$now
            return 1
        else
            log_warn "Circuit breaker failure count: $failures/$failure_threshold ($service_name)"
            return 1
        fi
    fi
}

# ============================================================================
# CONFIGURATION
# ============================================================================

CLAUDE_HOME="${CLAUDE_HOME:-/home/claude/.claude}"
WORKSPACE="${WORKSPACE:-/workspace}"
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/data/memory-bank}"

# ChromaDB configuration with DNS-based service discovery
# Prefer PARENT_HOSTNAME (container name) for Docker DNS resolution - more resilient than IP
# Falls back to PARENT_IP for backward compatibility
# Finally falls back to explicit CHROMADB_HOST or localhost
CHROMADB_HOST="${CHROMADB_HOST:-}"
if [[ -z "$CHROMADB_HOST" ]]; then
    if [[ -n "${PARENT_HOSTNAME:-}" ]]; then
        # Use parent container name - Docker DNS resolves to current IP
        # More resilient: survives parent container restart with new IP
        CHROMADB_HOST="${PARENT_HOSTNAME}"
    elif [[ -n "${PARENT_IP:-}" ]]; then
        # Fallback to IP for backward compatibility (less resilient)
        CHROMADB_HOST="${PARENT_IP}"
    else
        # Default to localhost (for standalone worker or local development)
        CHROMADB_HOST="localhost"
    fi
fi
CHROMADB_PORT="${CHROMADB_PORT:-8000}"

# ChromaDB authentication token file (mounted read-only from parent)
CHROMADB_TOKEN_FILE="/run/secrets/chromadb_token"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_claude_home() {
    log_info "Initializing Claude home: $CLAUDE_HOME"

    # Ensure Claude home structure exists
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$MEMORY_BANK_ROOT"

    # UPGRADE MIGRATION (Issue #8): UID changed from 1000 to 1001
    # For existing volumes created by old image (UID 1000), fix ownership
    if [[ -d "$CLAUDE_HOME" ]] && [[ $(find "$CLAUDE_HOME" -uid 1000 -print -quit 2>/dev/null) ]]; then
        log_info "Migrating volume ownership from UID 1000 to UID 1001 (claude:claude)..."
        find "$CLAUDE_HOME" -uid 1000 -exec chown claude:claude {} + 2>/dev/null || true
        log_success "Volume ownership migrated - credentials and plugins now accessible"
    fi

    # SECURITY: Read API key from secret file, not environment variable
    # Secret files mounted at /run/secrets are not visible via 'docker inspect' or /proc/1/environ
    # This is the secure way to pass credentials to containers
    if [[ -f /run/secrets/anthropic_key ]]; then
        export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_key)
        log_success "Using ANTHROPIC_API_KEY from secret file (secure)"
    fi

    # SECURITY: Read ChromaDB API key from secret file if available
    if [[ -f /run/secrets/chromadb_api_key ]]; then
        export CHROMADB_API_KEY=$(cat /run/secrets/chromadb_api_key)
        log_success "Using CHROMADB_API_KEY from secret file (secure)"
    fi

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

    # Check for ChromaDB authentication token
    local chromadb_auth_env=""
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        # SECURITY: Configure chroma-mcp client to use token authentication
        # The token file path is passed via environment variable
        # chroma-mcp reads the token from file at startup (not stored in settings.json)
        chromadb_auth_env=',
        "CHROMA_CLIENT_AUTH_PROVIDER": "chromadb.auth.token_authn.TokenAuthClientProvider",
        "CHROMA_CLIENT_AUTH_CREDENTIALS_FILE": "'$CHROMADB_TOKEN_FILE'"'
        log_info "ChromaDB authentication configured via token file"
    else
        log_warn "ChromaDB token not found - client will connect without authentication"
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
      ],
      "env": {
        "CHROMA_ANONYMIZED_TELEMETRY": "false"${chromadb_auth_env}
      }
    }
  }
}
EOF

    log_success "Foundation MCP servers configured:"
    log_info "  - memory-bank: ${MEMORY_BANK_ROOT}"

    # Log ChromaDB configuration with network mode info
    local auth_status="without auth"
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        auth_status="with token auth"
    fi

    if [[ -n "${PARENT_HOSTNAME:-}" ]]; then
        log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT} ($auth_status, DNS via PARENT_HOSTNAME: ${PARENT_HOSTNAME})"
    elif [[ -n "${PARENT_IP:-}" ]]; then
        log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT} ($auth_status, fallback IP via PARENT_IP)"
    else
        log_info "  - chromadb: http://${CHROMADB_HOST}:${CHROMADB_PORT} ($auth_status)"
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

verify_chromadb_connectivity() {
    log_info "Verifying ChromaDB connectivity..."

    # Check for authentication token
    local auth_available=false
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        auth_available=true
        log_info "ChromaDB auth token available: $CHROMADB_TOKEN_FILE"
    else
        log_warn "ChromaDB auth token not found - authentication will fail"
    fi

    # Use circuit breaker pattern to prevent cascading failures
    # ChromaDB health check with retry and authentication
    local curl_cmd="curl -s -m 5"
    if [[ "$auth_available" == "true" ]]; then
        # SECURITY: Read token at execution time, not stored in variable
        curl_cmd="curl -s -m 5 -H \"Authorization: Bearer \$(cat $CHROMADB_TOKEN_FILE)\""
    fi

    if retry_with_backoff \
        "$curl_cmd 'http://${CHROMADB_HOST}:${CHROMADB_PORT}/api/v2/heartbeat' >/dev/null 2>&1" \
        3; then
        if [[ "$auth_available" == "true" ]]; then
            log_success "ChromaDB connectivity verified with authentication: http://${CHROMADB_HOST}:${CHROMADB_PORT}"
        else
            log_success "ChromaDB connectivity verified (no auth): http://${CHROMADB_HOST}:${CHROMADB_PORT}"
        fi
        return 0
    fi

    # ChromaDB not responding - log warning but don't fail
    # (ChromaDB may start later, chroma-mcp has its own reconnection logic)
    log_warn "ChromaDB not responding after retries"
    log_warn "ChromaDB configuration: host=${CHROMADB_HOST}, port=${CHROMADB_PORT}"
    if [[ "$auth_available" != "true" ]]; then
        log_warn "Authentication token missing - this may be causing connection failures"
    fi
    log_info "Note: chroma-mcp client will retry automatically when Claude uses ChromaDB"
    return 1  # Warning, not fatal
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
# - TMUX provides terminal multiplexing and process management
# - Claude state persists via file-based storage in CLAUDE_HOME (/home/claude/.claude)
# - State files: session.json, credentials, plugin configs (managed by Claude CLI)
# - TMUX socket persistence: Stored in shared volume, survives container restart
# - For cross-container persistence across attachments: File-based storage in shared volume
# - For cross-session reasoning persistence: Use Memory Bank MCP server

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
    # SECURITY: Use 0770 instead of 0777 (restrict socket access to owner and group, not world)
    chmod 0770 "$TMUX_SOCKET_DIR"

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
# SIGNAL HANDLING & CLEANUP
# ============================================================================

# Cleanup lifecycle:
# 1. Worker process cleanup (THIS function):
#    - Kill TMUX server (graceful session termination)
#    - Container filesystem cleanup happens automatically
# 2. Session metadata cleanup (coordinator.sh):
#    - Triggered on normal shutdown via `coordinator.sh stop <worker>`
#    - Calls cleanup_session_metadata() to remove ${HAL9000_HOME}/sessions/*.json
# 3. Stale metadata cleanup (manual or periodic):
#    - Use `coordinator.sh cleanup-stale [days]` to remove old metadata files
#    - Useful for cleanup after container crashes or timeouts
# Note: Session metadata files are stored on host/shared volume, not in container
# Worker process cannot directly clean up host-side metadata files

cleanup_on_exit() {
    local exit_code=$?
    log_info "Worker shutting down (exit code: $exit_code)..."

    # Graceful TMUX cleanup
    if [[ "$TMUX_ENABLED" == "true" && -n "${TMUX_SOCKET:-}" ]]; then
        log_info "Cleaning up TMUX server..."

        if [[ -S "$TMUX_SOCKET" ]]; then
            # Try graceful shutdown first
            if tmux -S "$TMUX_SOCKET" kill-server 2>/dev/null; then
                log_success "TMUX server stopped gracefully"
            else
                log_warn "Failed to stop TMUX gracefully, forcing shutdown"
            fi
            sleep 1
        fi
    fi

    # Clean up any temporary files created during startup
    if [[ -d "$CLAUDE_HOME/.tmp" ]]; then
        find "$CLAUDE_HOME/.tmp" -type f -mtime +1 -delete 2>/dev/null || true
    fi

    # Cleanup stale background processes
    # Jobs list shows backgrounded processes in this shell
    local jobs_count
    jobs_count=$(jobs -p | wc -l)
    if [[ $jobs_count -gt 0 ]]; then
        log_info "Killing $jobs_count background processes..."
        jobs -p | xargs -r kill -9 2>/dev/null || true
    fi

    log_info "Worker cleanup complete"
    exit "$exit_code"
}

trap cleanup_on_exit SIGTERM SIGINT EXIT

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
    verify_chromadb_connectivity  # Non-fatal: logs warning if ChromaDB unavailable
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
