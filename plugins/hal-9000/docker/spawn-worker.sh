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
# - Mounts shared CLAUDE_HOME volume (marketplace installations persist)
# - Mounts project directory at /workspace
# - Users install MCP servers via: claude plugin marketplace add / claude plugin install

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[spawn]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[spawn]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[spawn]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[spawn]${NC} ERROR: %s\n" "$1" >&2; }

# ============================================================================
# CONFIGURATION
# ============================================================================

WORKER_NAME=""
DETACH=false
REMOVE_ON_EXIT=true
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"
PROJECT_DIR=""
PARENT_CONTAINER="${HAL9000_PARENT:-hal9000-parent}"

# Resource limits (can be overridden via environment or arguments)
WORKER_MEMORY="${WORKER_MEMORY:-4g}"
WORKER_CPUS="${WORKER_CPUS:-2}"
WORKER_PIDS_LIMIT="${WORKER_PIDS_LIMIT:-100}"

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_help() {
    cat <<EOF
Usage: spawn-worker.sh [options] [project_dir]

Spawn a Claude worker container with marketplace support.

Workers share a persistent CLAUDE_HOME volume, so marketplace installations
(MCP servers, agents, commands) persist across all workers and sessions.

Options:
  -n, --name NAME       Worker name (default: hal9000-worker-TIMESTAMP)
  -d, --detach          Run in background (returns container ID)
  -i, --image IMAGE     Worker image (default: $WORKER_IMAGE)
  --rm                  Remove container on exit (default)
  --no-rm               Keep container after exit
  --memory SIZE         Memory limit (default: $WORKER_MEMORY)
  --cpus N              CPU limit (default: $WORKER_CPUS)
  --pids-limit N        Process limit (default: $WORKER_PIDS_LIMIT)
  --no-limits           Disable resource limits
  -h, --help            Show this help

Examples:
  spawn-worker.sh                           # Interactive worker in /workspace
  spawn-worker.sh /path/to/project          # Worker with project mounted
  spawn-worker.sh -d -n my-worker           # Background worker with custom name

Marketplace:
  Workers support Anthropic marketplace. Install plugins that persist:
    claude plugin marketplace add https://marketplace.url
    claude plugin install plugin-name

  Installations are stored in shared CLAUDE_HOME volume.

Network:
  Worker shares parent's network namespace via --network=container:$PARENT_CONTAINER
  This allows access to parent's services (e.g., ChromaDB on localhost:8000)
EOF
}

parse_args() {
    # Track whether to apply limits (can be disabled with --no-limits)
    APPLY_LIMITS=true

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
            --memory)
                WORKER_MEMORY="$2"
                shift 2
                ;;
            --cpus)
                WORKER_CPUS="$2"
                shift 2
                ;;
            --pids-limit)
                WORKER_PIDS_LIMIT="$2"
                shift 2
                ;;
            --no-limits)
                APPLY_LIMITS=false
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

# SECURITY: Allowlist of trusted worker images
# Using versioned tags for supply chain security (tags won't be reused)
ALLOWED_IMAGES=(
    "ghcr.io/hellblazer/hal-9000:worker"
    "ghcr.io/hellblazer/hal-9000:worker-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:base"
    "ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:python"
    "ghcr.io/hellblazer/hal-9000:python-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:node"
    "ghcr.io/hellblazer/hal-9000:node-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:java"
    "ghcr.io/hellblazer/hal-9000:java-v3.0.0"
)

validate_worker_image() {
    local image="$1"
    for allowed in "${ALLOWED_IMAGES[@]}"; do
        if [[ "$image" == "$allowed" ]]; then
            return 0
        fi
    done
    log_error "Security violation: image '$image' not in allowlist"
    log_error "Allowed images: ${ALLOWED_IMAGES[*]}"
    exit 1
}

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
        # SECURITY: Validate PROJECT_DIR using allowlist approach (fail closed)
        # Canonicalize path to resolve symlinks and ..
        if ! command -v realpath >/dev/null 2>&1; then
            log_error "realpath required for path validation"
            exit 1
        fi

        local canonical_path
        canonical_path="$(realpath -m "$PROJECT_DIR" 2>/dev/null)" || {
            log_error "Security violation: cannot canonicalize path: $PROJECT_DIR"
            exit 1
        }

        # SECURITY: Allowlist of permitted path prefixes (more secure than blocklist)
        local allowed_prefixes=("/home" "/Users" "/workspace" "/tmp" "/var/tmp")
        local path_allowed=false
        for prefix in "${allowed_prefixes[@]}"; do
            if [[ "$canonical_path" == "$prefix" || "$canonical_path" == "$prefix/"* ]]; then
                path_allowed=true
                break
            fi
        done

        if [[ "$path_allowed" != "true" ]]; then
            log_error "Security violation: path '$canonical_path' not in allowed directories"
            log_error "Allowed prefixes: ${allowed_prefixes[*]}"
            exit 1
        fi

        # Additional check: reject paths that still contain .. after canonicalization
        # (shouldn't happen with realpath, but defense in depth)
        if [[ "$canonical_path" =~ \.\. ]]; then
            log_error "Security violation: path contains '..' after canonicalization"
            exit 1
        fi

        docker_args+=(-v "${canonical_path}:/workspace")
        log_info "Mounting project: $canonical_path -> /workspace"
    fi

    # Mount shared CLAUDE_HOME volume for marketplace persistence
    # All workers share the same CLAUDE_HOME so marketplace installations persist
    # Detect Docker-in-Docker mode (running inside a container)
    local in_container=false
    if [[ -f "/.dockerenv" ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        in_container=true
    fi

    # Use a single shared volume for all workers
    local claude_volume="hal9000-claude-home"

    # SECURITY: Workers run as non-root user 'claude' (UID 1000)
    # Mount to /home/claude/.claude instead of /root/.claude
    local claude_home_path="/home/claude/.claude"

    if [[ "$in_container" == "true" ]]; then
        # Inside container - use named volumes (host paths won't work)
        docker volume create "$claude_volume" >/dev/null 2>&1 || true
        docker_args+=(-v "${claude_volume}:${claude_home_path}")
        log_info "DinD mode: using shared volume $claude_volume"
    else
        # Running on host - use host directory (shared across all workers)
        local hal9000_home="${HAL9000_HOME:-$HOME/.hal9000}"
        local claude_home="${hal9000_home}/claude"
        mkdir -p "$claude_home" 2>/dev/null || true
        docker_args+=(-v "${claude_home}:${claude_home_path}")
        log_info "Host mode: using shared directory $claude_home"
    fi

    log_info "Marketplace installations will persist in CLAUDE_HOME"

    # Mount shared Memory Bank volume (required for foundation MCP server)
    # Create if doesn't exist - all workers share this for persistent memory
    local membank_volume="hal9000-memory-bank"
    docker volume create "$membank_volume" >/dev/null 2>&1 || true
    docker_args+=(-v "${membank_volume}:/data/memory-bank")
    log_info "Memory Bank: shared volume $membank_volume"

    # Mount shared ChromaDB data volume (if it exists)
    if docker volume inspect "hal9000-chromadb" >/dev/null 2>&1; then
        docker_args+=(-v "hal9000-chromadb:/data/chromadb")
        log_info "ChromaDB data: shared volume"
    fi

    # SECURITY NOTE: Prefer credential files over environment variables
    # Environment variables are visible in 'docker inspect' output
    # Credentials in ~/.claude/.credentials.json are more secure

    # Pass through API key if set (prefer credential files instead)
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        docker_args+=(-e ANTHROPIC_API_KEY)
        log_warn "SECURITY: Using ANTHROPIC_API_KEY env var - prefer credential files"
    fi

    # Pass through ChromaDB cloud credentials if set
    if [[ -n "${CHROMADB_TENANT:-}" ]]; then
        docker_args+=(-e CHROMADB_TENANT)
    fi
    if [[ -n "${CHROMADB_API_KEY:-}" ]]; then
        docker_args+=(-e CHROMADB_API_KEY)
        log_warn "SECURITY: Using CHROMADB_API_KEY env var - visible in docker inspect"
    fi

    # Resource limits (unless disabled)
    if [[ "$APPLY_LIMITS" == "true" ]]; then
        docker_args+=(--memory "$WORKER_MEMORY")
        docker_args+=(--cpus "$WORKER_CPUS")
        docker_args+=(--pids-limit "$WORKER_PIDS_LIMIT")
        log_info "Resource limits: memory=$WORKER_MEMORY, cpus=$WORKER_CPUS, pids=$WORKER_PIDS_LIMIT"
    else
        log_warn "Resource limits disabled"
    fi

    # Working directory
    docker_args+=(-w /workspace)

    # SECURITY: Validate worker image is in allowlist
    validate_worker_image "$WORKER_IMAGE"

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
    "remove_on_exit": $REMOVE_ON_EXIT,
    "resource_limits": {
        "enabled": $APPLY_LIMITS,
        "memory": "$WORKER_MEMORY",
        "cpus": "$WORKER_CPUS",
        "pids_limit": "$WORKER_PIDS_LIMIT"
    }
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
