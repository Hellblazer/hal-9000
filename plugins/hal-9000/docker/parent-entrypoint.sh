#!/usr/bin/env bash
# parent-entrypoint.sh - HAL-9000 Parent Container Entrypoint
#
# Responsibilities:
# 1. Verify Docker socket is accessible
# 2. Initialize state directories
# 3. Start tmux server for session management
# 4. Launch coordinator or execute passed command

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[parent]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[parent]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[parent]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[parent]${NC} %s\n" "$1" >&2; }

# ============================================================================
# INITIALIZATION
# ============================================================================

init_directories() {
    log_info "Initializing directories..."

    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/sessions"
    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/logs"
    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/config"

    log_success "Directories initialized"
}

verify_docker_socket() {
    log_info "Verifying Docker socket..."

    if [[ ! -S /var/run/docker.sock ]]; then
        log_error "Docker socket not found at /var/run/docker.sock"
        log_error "Mount Docker socket: -v /var/run/docker.sock:/var/run/docker.sock"
        exit 1
    fi

    if ! docker ps >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon"
        log_error "Ensure Docker socket is mounted and accessible"
        exit 1
    fi

    log_success "Docker socket verified"
}

init_tmux_server() {
    log_info "Initializing tmux server..."

    # Kill any existing tmux server from previous runs
    tmux kill-server 2>/dev/null || true

    # Start tmux server with specific socket
    tmux -L hal9000 new-session -d -s dashboard -n status

    # Create dashboard window content
    tmux -L hal9000 send-keys -t dashboard:status \
        "watch -n 5 'echo \"=== HAL-9000 Parent Dashboard ===\"; echo; docker ps --filter name=hal9000-worker --format \"table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\"'" Enter

    log_success "tmux server initialized (socket: hal9000)"
}

pull_worker_image() {
    local image="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"

    log_info "Checking worker image: $image"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        log_info "Pulling worker image..."
        if docker pull "$image"; then
            log_success "Worker image pulled"
        else
            log_warn "Could not pull worker image (will try local build)"
        fi
    else
        log_success "Worker image available locally"
    fi
}

# ============================================================================
# CHROMADB SERVER
# ============================================================================

start_chromadb_server() {
    log_info "Starting ChromaDB server..."

    local host="${CHROMADB_HOST:-0.0.0.0}"
    local port="${CHROMADB_PORT:-8000}"
    local data_dir="${CHROMADB_DATA_DIR:-/data/chromadb}"

    # Ensure data directory exists
    mkdir -p "$data_dir"

    # Start ChromaDB server in background
    chroma run \
        --host "$host" \
        --port "$port" \
        --path "$data_dir" \
        >> "${HAL9000_LOGS_DIR:-/root/.hal9000/logs}/chromadb.log" 2>&1 &

    local chromadb_pid=$!
    echo "$chromadb_pid" > "${HAL9000_HOME}/chromadb.pid"

    # Wait for server to be ready
    local max_wait=30
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if curl -s "http://localhost:${port}/api/v2/heartbeat" >/dev/null 2>&1; then
            log_success "ChromaDB server started on port $port (PID: $chromadb_pid)"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    log_error "ChromaDB server failed to start within ${max_wait}s"
    return 1
}

stop_chromadb_server() {
    local pid_file="${HAL9000_HOME}/chromadb.pid"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping ChromaDB server (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    fi
}

# ============================================================================
# COORDINATOR MODE
# ============================================================================

run_coordinator() {
    log_info "Starting coordinator mode..."

    # Write PID file
    echo $$ > "${HAL9000_HOME}/coordinator.pid"

    # Trap signals for graceful shutdown
    trap cleanup_on_exit SIGTERM SIGINT

    log_success "Coordinator running (PID: $$)"
    log_info "Use 'docker exec hal9000-parent /scripts/spawn-worker.sh' to spawn workers"
    log_info "Or attach to dashboard: 'docker exec -it hal9000-parent tmux -L hal9000 attach'"

    # Keep container running
    # In production, this would be replaced with actual coordination logic
    while true; do
        sleep 60

        # Periodic health check
        local worker_count
        worker_count=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" | wc -l)
        log_info "Active workers: $worker_count"
    done
}

cleanup_on_exit() {
    log_warn "Shutting down coordinator..."

    # List and optionally stop workers
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" || true)

    if [[ -n "$workers" ]]; then
        log_warn "Active workers that will be orphaned:"
        echo "$workers" | while read -r worker; do
            log_warn "  - $worker"
        done
        # Note: We don't forcefully stop workers - they continue running
        # Use --rm flag when spawning workers for auto-cleanup
    fi

    # Stop ChromaDB server
    stop_chromadb_server

    # Clean up tmux
    tmux -L hal9000 kill-server 2>/dev/null || true

    # Remove PID file
    rm -f "${HAL9000_HOME}/coordinator.pid"

    log_info "Coordinator stopped"
    exit 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "HAL-9000 Parent Container starting..."

    # Run initialization
    init_directories
    verify_docker_socket
    init_tmux_server
    start_chromadb_server
    pull_worker_image

    # Handle command
    case "${1:-coordinator}" in
        coordinator)
            run_coordinator
            ;;
        bash|sh)
            exec "$@"
            ;;
        *)
            # Execute passed command
            exec "$@"
            ;;
    esac
}

main "$@"
