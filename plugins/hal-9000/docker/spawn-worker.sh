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
    # In DinD mode, the path is a host path but we're running inside a container
    # Docker daemon is on the host, so paths must be host paths
    if [[ -n "$PROJECT_DIR" ]]; then
        # In DinD mode, we can't check if directory exists from inside container
        # because it's a host path. Just mount it and let docker fail if invalid.
        docker_args+=(-v "${PROJECT_DIR}:/workspace")
        log_info "Mounting project: $PROJECT_DIR -> /workspace"
    fi

    # Mount Claude home for session persistence
    # Detect Docker-in-Docker mode (running inside a container)
    local in_container=false
    if [[ -f "/.dockerenv" ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        in_container=true
    fi

    if [[ "$in_container" == "true" ]]; then
        # Inside container - use named volumes (host paths won't work)
        local volume_name="hal9000-claude-${WORKER_NAME}"
        docker volume create "$volume_name" >/dev/null 2>&1 || true
        docker_args+=(-v "${volume_name}:/root/.claude")
        log_info "DinD mode: using named volume $volume_name"
    else
        # Running on host - use host directory
        local hal9000_home="${HAL9000_HOME:-$HOME/.hal9000}"
        local claude_home="${hal9000_home}/workers/${WORKER_NAME}"
        mkdir -p "$claude_home" 2>/dev/null || true
        docker_args+=(-v "${claude_home}:/root/.claude")
    fi

    # Mount shared data volumes (if they exist)
    if docker volume inspect "hal9000-chromadb" >/dev/null 2>&1; then
        docker_args+=(-v "hal9000-chromadb:/data/chromadb")
        log_info "Mounting shared ChromaDB volume"
    fi

    if docker volume inspect "hal9000-memorybank" >/dev/null 2>&1; then
        docker_args+=(-v "hal9000-memorybank:/data/membank")
        log_info "Mounting shared Memory Bank volume"
    fi

    if docker volume inspect "hal9000-plugins" >/dev/null 2>&1; then
        docker_args+=(-v "hal9000-plugins:/data/plugins")
        log_info "Mounting shared Plugins volume"
    fi

    # Pass through API key if set
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        docker_args+=(-e ANTHROPIC_API_KEY)
    fi

    # Pass through ChromaDB cloud credentials if set
    if [[ -n "${CHROMADB_TENANT:-}" ]]; then
        docker_args+=(-e CHROMADB_TENANT)
    fi
    if [[ -n "${CHROMADB_API_KEY:-}" ]]; then
        docker_args+=(-e CHROMADB_API_KEY)
    fi

    # Working directory
    docker_args+=(-w /workspace)

    # Image
    docker_args+=("$WORKER_IMAGE")

    # For detached mode, override command to keep container running
    # Default entrypoint is bash which exits without TTY
    if [[ "$DETACH" == "true" ]]; then
        docker_args+=(bash -c "sleep infinity")
    fi

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
