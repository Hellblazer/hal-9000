#!/usr/bin/env bash
# spawn-worker.sh - Spawn a Claude worker container
#
# Usage:
#   spawn-worker.sh [options] [project_dir]
#
# Options:
#   -n, --name NAME       Worker name (default: auto-generated)
#   -d, --detach          Run in background (default: interactive)
#   -i, --image IMAGE     Worker image (default: $WORKER_IMAGE)
#   --rm                  Remove container on exit (default: true)
#   --no-rm               Keep container after exit
#   -h, --help            Show this help
#
# The worker container:
# - Shares parent's network namespace (--network=container:PARENT)
# - Can access localhost services (MCP servers on host)
# - Mounts project directory at /workspace
# - Has Claude CLI pre-installed

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[spawn]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[spawn]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[spawn]${NC} %s\n" "$1"; }

# ============================================================================
# CONFIGURATION
# ============================================================================

WORKER_NAME=""
DETACH=false
REMOVE_ON_EXIT=true
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"
PROJECT_DIR=""
PARENT_CONTAINER="${HAL9000_PARENT:-hal9000-parent}"

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_help() {
    cat <<EOF
Usage: spawn-worker.sh [options] [project_dir]

Spawn a Claude worker container that shares parent's network namespace.

Options:
  -n, --name NAME       Worker name (default: hal9000-worker-TIMESTAMP)
  -d, --detach          Run in background (returns container ID)
  -i, --image IMAGE     Worker image (default: $WORKER_IMAGE)
  --rm                  Remove container on exit (default)
  --no-rm               Keep container after exit
  -h, --help            Show this help

Examples:
  spawn-worker.sh                           # Interactive worker in /workspace
  spawn-worker.sh /path/to/project          # Worker with project mounted
  spawn-worker.sh -d -n my-worker           # Background worker with custom name
  spawn-worker.sh --no-rm -n persistent     # Keep container after exit

Network:
  Worker shares parent's network namespace via --network=container:$PARENT_CONTAINER
  This allows workers to access localhost:PORT services (e.g., MCP servers on host)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                WORKER_NAME="$2"
                shift 2
                ;;
            -d|--detach)
                DETACH=true
                shift
                ;;
            -i|--image)
                WORKER_IMAGE="$2"
                shift 2
                ;;
            --rm)
                REMOVE_ON_EXIT=true
                shift
                ;;
            --no-rm)
                REMOVE_ON_EXIT=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_warn "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                PROJECT_DIR="$1"
                shift
                ;;
        esac
    done
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_parent() {
    # Check if parent container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_warn "Parent container '$PARENT_CONTAINER' not running"
        log_warn "Workers will use bridge network instead of shared namespace"
        PARENT_CONTAINER=""
    fi
}

generate_worker_name() {
    if [[ -z "$WORKER_NAME" ]]; then
        WORKER_NAME="hal9000-worker-$(date +%s)"
    fi
}

# ============================================================================
# SPAWN WORKER
# ============================================================================

spawn_worker() {
    local docker_args=()

    # Base docker run arguments
    docker_args+=(docker run)

    # Interactive or detached
    if [[ "$DETACH" == "true" ]]; then
        docker_args+=(-d)
    else
        docker_args+=(-it)
    fi

    # Container cleanup
    if [[ "$REMOVE_ON_EXIT" == "true" ]]; then
        docker_args+=(--rm)
    fi

    # Container name
    docker_args+=(--name "$WORKER_NAME")

    # Network namespace sharing
    if [[ -n "$PARENT_CONTAINER" ]]; then
        docker_args+=(--network "container:${PARENT_CONTAINER}")
        log_info "Sharing network with parent: $PARENT_CONTAINER"
    else
        log_warn "Running with default bridge network"
    fi

    # Mount project directory if specified
    if [[ -n "$PROJECT_DIR" ]]; then
        if [[ -d "$PROJECT_DIR" ]]; then
            docker_args+=(-v "${PROJECT_DIR}:/workspace")
            log_info "Mounting project: $PROJECT_DIR -> /workspace"
        else
            log_warn "Project directory not found: $PROJECT_DIR"
        fi
    fi

    # Mount Claude home for session persistence
    local claude_home="${HAL9000_HOME:-/root/.hal9000}/workers/${WORKER_NAME}"
    mkdir -p "$claude_home"
    docker_args+=(-v "${claude_home}:/root/.claude")

    # Pass through API key if set
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        docker_args+=(-e ANTHROPIC_API_KEY)
    fi

    # Working directory
    docker_args+=(-w /workspace)

    # Image
    docker_args+=("$WORKER_IMAGE")

    log_info "Spawning worker: $WORKER_NAME"
    log_info "Image: $WORKER_IMAGE"

    # Record session metadata
    record_session_metadata

    # Execute docker run
    if [[ "$DETACH" == "true" ]]; then
        local container_id
        container_id=$("${docker_args[@]}")
        log_success "Worker started: $container_id"
        echo "$container_id"
    else
        "${docker_args[@]}"
    fi
}

record_session_metadata() {
    local session_file="${HAL9000_HOME:-/root/.hal9000}/sessions/${WORKER_NAME}.json"

    cat > "$session_file" <<EOF
{
    "name": "$WORKER_NAME",
    "image": "$WORKER_IMAGE",
    "parent": "$PARENT_CONTAINER",
    "project_dir": "$PROJECT_DIR",
    "created_at": "$(date -Iseconds)",
    "detached": $DETACH,
    "remove_on_exit": $REMOVE_ON_EXIT
}
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    validate_parent
    generate_worker_name
    spawn_worker
}

main "$@"
