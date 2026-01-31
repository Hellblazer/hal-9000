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
# - Uses independent bridge network (network isolation)
# - Accesses parent services (ChromaDB) via parent IP address
# - Mounts shared CLAUDE_HOME volume (marketplace installations persist)
# - Mounts shared TMUX sockets volume (for inter-process communication)
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

# Source audit logging library
if [[ -f "/scripts/lib/audit-log.sh" ]]; then
    source /scripts/lib/audit-log.sh
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
fi

# Issue #9: Error handling resilience
# Retry logic for transient failures with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_wait="${2:-1}"
    local description="${3:-operation}"
    shift 3
    local -a cmd=("$@")

    local attempt=1
    local wait_time=$initial_wait

    while [ $attempt -le $max_attempts ]; do
        log_info "Attempting $description (attempt $attempt/$max_attempts)..."

        if "${cmd[@]}"; then
            return 0
        fi

        local exit_code=$?

        if [ $attempt -lt $max_attempts ]; then
            log_warn "Command failed with exit code $exit_code, retrying in ${wait_time}s..."
            sleep "$wait_time"
            # Exponential backoff: double the wait time (1s, 2s, 4s, ...)
            wait_time=$((wait_time * 2))
        else
            log_error "Command failed after $max_attempts attempts"
            return $exit_code
        fi

        ((attempt++))
    done

    return 1
}

cleanup_on_error() {
    local worker_name="$1"

    log_warn "Cleaning up due to error..."

    # Attempt to remove container if it was created
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${worker_name}$"; then
        log_info "Removing failed container: $worker_name"
        docker rm -f "$worker_name" 2>/dev/null || log_warn "Could not remove container: $worker_name"
    fi

    # Remove session metadata
    local session_file="${HAL9000_HOME:-$HOME/.hal9000}/sessions/${worker_name}.json"
    if [ -f "$session_file" ]; then
        rm -f "$session_file" 2>/dev/null || log_warn "Could not remove session file: $session_file"
    fi

    log_info "Cleanup completed"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

WORKER_NAME=""
DETACH=false
REMOVE_ON_EXIT=true
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker-v3.0.0}"
PROJECT_DIR=""
PARENT_CONTAINER="${HAL9000_PARENT:-hal9000-parent}"

# Resource limits (can be overridden via environment or arguments)
WORKER_MEMORY="${WORKER_MEMORY:-4g}"
WORKER_CPUS="${WORKER_CPUS:-2}"
WORKER_PIDS_LIMIT="${WORKER_PIDS_LIMIT:-100}"

# SECURITY: Seccomp profile for syscall filtering
# Profile must be on HOST filesystem (Docker reads it before container starts)
# Blocks dangerous syscalls like mount, ptrace, setns, bpf, kexec_load
SECCOMP_PROFILE="${HAL9000_HOME:-$HOME/.hal9000}/seccomp/hal9000.json"

# ============================================================================
# USER IDENTITY AND VOLUME ISOLATION
# ============================================================================

# SECURITY: Per-user volume isolation
# Each user gets their own isolated volumes to prevent cross-user attacks:
# - Malicious plugin installation affecting other users
# - Memory bank poisoning across users
# - TMUX socket hijacking

# Cache for user hash (computed once per session)
_CACHED_USER_HASH=""

# Generate user hash for volume isolation
# Uses $USER if available, falls back to UID for containerized environments
generate_user_hash() {
    local user_id

    # Prefer $USER environment variable (human-readable, stable across sessions)
    if [[ -n "${USER:-}" ]]; then
        user_id="$USER"
    # Fall back to username from id command
    elif user_id=$(id -un 2>/dev/null); then
        : # user_id already set
    # Last resort: use numeric UID
    else
        user_id="uid-$(id -u 2>/dev/null || echo "unknown")"
    fi

    # Generate 8-character hash for volume naming
    # SHA-256 ensures consistent, collision-resistant hash
    echo -n "$user_id" | sha256sum | cut -c1-8
}

# Get cached user hash (computed once, reused for consistency)
get_user_hash() {
    if [[ -z "$_CACHED_USER_HASH" ]]; then
        _CACHED_USER_HASH=$(generate_user_hash)
    fi
    echo "$_CACHED_USER_HASH"
}

# Get user-scoped volume name
# Usage: get_user_volume <base-name>
# Example: get_user_volume "claude-home" -> "hal9000-claude-home-a1b2c3d4"
get_user_volume() {
    local base_name="$1"
    local user_hash
    user_hash=$(get_user_hash)
    echo "hal9000-${base_name}-${user_hash}"
}

# Ensure user-scoped volume exists
# Creates the volume if it doesn't exist
ensure_user_volume() {
    local volume_name="$1"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        docker volume create "$volume_name" >/dev/null 2>&1 || true
        log_info "Created user-scoped volume: $volume_name"
    fi
}

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
  Workers use independent bridge network for isolation and security.
  They access parent services (e.g., ChromaDB) via parent's IP address.
  Parent IP is automatically detected and passed as PARENT_IP environment variable.
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
# SECURITY: Only allow versioned image tags to prevent supply chain attacks
# Mutable tags (e.g., :worker, :base) are not allowed - pin to specific versions
# This ensures you deploy exactly what you tested, not the latest mutable tag
# To use a new version, update your image specification with the new version tag
ALLOWED_IMAGES=(
    "ghcr.io/hellblazer/hal-9000:worker-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:python-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:node-v3.0.0"
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

    # Network configuration: Use bridge network for isolation
    # Workers no longer share parent's network namespace for better security/isolation
    # Instead, they connect to ChromaDB via HTTP using parent's IP address
    docker_args+=(--network "bridge")

    # Use parent container name for DNS-based service discovery (more resilient than IP)
    # Docker DNS automatically resolves container names to current IPs
    if [[ -n "$PARENT_CONTAINER" ]]; then
        # Pass parent container name instead of IP for DNS resolution
        # This allows parent IP changes (e.g., on restart) without breaking connections
        docker_args+=(-e "PARENT_HOSTNAME=$PARENT_CONTAINER")
        log_info "Parent hostname: $PARENT_CONTAINER (DNS-based service discovery)"

        # Also pass PARENT_IP for backward compatibility (will attempt DNS resolution first)
        local parent_ip
        parent_ip=$(docker inspect "$PARENT_CONTAINER" --format='{{.NetworkSettings.IPAddress}}' 2>/dev/null || echo "")
        if [[ -n "$parent_ip" ]]; then
            docker_args+=(-e "PARENT_IP=$parent_ip")
            log_info "Parent fallback IP: $parent_ip (for backward compatibility)"
        fi
    else
        log_warn "Parent container not specified - workers will need explicit service configuration"
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
        local allowed_prefixes=("/home" "/Users" "/workspace")
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

    # =========================================================================
    # SECURITY: Per-user volume isolation
    # =========================================================================
    # Each user gets their own isolated volumes to prevent cross-user attacks:
    # - Malicious plugin installation affecting other users
    # - Memory bank poisoning across users
    # - TMUX socket hijacking
    #
    # Volume naming: hal9000-<type>-<user_hash>
    # Example: hal9000-claude-home-a1b2c3d4 for user "alice"
    # =========================================================================

    local user_hash
    user_hash=$(get_user_hash)
    log_info "User isolation: hash=${user_hash} (user=${USER:-$(id -un 2>/dev/null || echo uid-$(id -u))})"

    # Detect Docker-in-Docker mode (running inside a container)
    local in_container=false
    if [[ -f "/.dockerenv" ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        in_container=true
    fi

    # SECURITY: User-scoped CLAUDE_HOME volume
    # Each user gets their own CLAUDE_HOME, preventing:
    # - Malicious plugin installation affecting other users
    # - Credential theft via shared config
    # - Settings tampering
    local claude_volume
    claude_volume=$(get_user_volume "claude-home")

    # SECURITY: Workers run as non-root user 'claude' (UID 1001)
    # Mount to /home/claude/.claude instead of /root/.claude
    local claude_home_path="/home/claude/.claude"

    if [[ "$in_container" == "true" ]]; then
        # Inside container - use named volumes (host paths won't work)
        ensure_user_volume "$claude_volume"
        docker_args+=(-v "${claude_volume}:${claude_home_path}")
        log_info "DinD mode: user volume $claude_volume"
    else
        # Running on host - use user-scoped directory
        local hal9000_home="${HAL9000_HOME:-$HOME/.hal9000}"
        local claude_home="${hal9000_home}/users/${user_hash}/claude"
        mkdir -p "$claude_home" 2>/dev/null || true
        # SECURITY: Restrict to owner only
        chmod 700 "$claude_home" 2>/dev/null || true

        # Also create user-scoped TMUX sockets directory
        local tmux_sockets_dir="${hal9000_home}/users/${user_hash}/tmux-sockets"
        mkdir -p "$tmux_sockets_dir" 2>/dev/null || true
        # SECURITY: Restrict to owner only (no group/world access)
        chmod 700 "$tmux_sockets_dir" 2>/dev/null || true

        docker_args+=(-v "${claude_home}:${claude_home_path}")
        log_info "Host mode: user directory $claude_home"
    fi

    log_info "User-isolated CLAUDE_HOME: $claude_volume"

    # OPTIONAL: Shared read-only base plugins for efficiency
    # Base plugins (foundation MCP servers, core commands) can be shared read-only
    # to avoid duplicating large installations across users
    local base_plugins_volume="hal9000-base-plugins"
    if docker volume inspect "$base_plugins_volume" >/dev/null 2>&1; then
        # Mount shared base plugins as read-only overlay
        docker_args+=(-v "${base_plugins_volume}:/home/claude/.claude/base-plugins:ro")
        log_info "Shared base plugins: $base_plugins_volume (read-only)"
    fi

    # SECURITY: User-scoped Memory Bank volume
    # Each user gets their own memory bank to prevent:
    # - Memory bank poisoning across users
    # - Information leakage between users
    local membank_volume
    membank_volume=$(get_user_volume "memory-bank")
    ensure_user_volume "$membank_volume"
    docker_args+=(-v "${membank_volume}:/data/memory-bank")
    log_info "User-isolated Memory Bank: $membank_volume"

    # SECURITY: User-scoped TMUX sockets volume
    # Each user gets their own TMUX sockets to prevent:
    # - TMUX session hijacking
    # - Cross-user command injection
    local tmux_volume
    tmux_volume=$(get_user_volume "tmux-sockets")
    ensure_user_volume "$tmux_volume"
    docker_args+=(-v "${tmux_volume}:/data/tmux-sockets")
    log_info "User-isolated TMUX sockets: $tmux_volume"

    # SECURITY: User-scoped coordinator state volume
    # Each user gets their own coordinator state to prevent:
    # - Session tracking manipulation
    # - Cross-user worker interference
    local coordinator_state_volume
    coordinator_state_volume=$(get_user_volume "coordinator-state")
    ensure_user_volume "$coordinator_state_volume"
    docker_args+=(-v "${coordinator_state_volume}:/data/coordinator-state")
    log_info "User-isolated coordinator state: $coordinator_state_volume"

    # Mount shared ChromaDB data volume (if it exists)
    if docker volume inspect "hal9000-chromadb" >/dev/null 2>&1; then
        docker_args+=(-v "hal9000-chromadb:/data/chromadb")
        log_info "ChromaDB data: shared volume"
    fi

    # SECURITY: Mount ChromaDB authentication token (read-only bind mount)
    # Token is generated by parent and shared via file, NOT environment variable
    # This prevents token exposure via docker inspect or /proc/*/environ
    local chromadb_token_file="/run/secrets/chromadb_token"
    if [[ -f "$chromadb_token_file" ]]; then
        docker_args+=(-v "${chromadb_token_file}:/run/secrets/chromadb_token:ro")
        log_info "ChromaDB auth: token mounted (read-only)"
    else
        log_warn "ChromaDB auth: token file not found at $chromadb_token_file"
        log_warn "Workers will not be able to authenticate with ChromaDB"
    fi

    # SECURITY: Mount ChromaDB TLS certificate (read-only bind mount)
    # Certificate is generated by parent and used by workers to verify server identity
    # This enables encrypted HTTPS connections to ChromaDB
    local chromadb_cert_file="/run/secrets/chromadb.crt"
    if [[ -f "$chromadb_cert_file" ]]; then
        docker_args+=(-v "${chromadb_cert_file}:/run/secrets/chromadb.crt:ro")
        docker_args+=(-e "CHROMADB_TLS_ENABLED=true")
        log_info "ChromaDB TLS: certificate mounted (HTTPS enabled)"
    else
        log_info "ChromaDB TLS: certificate not found (using HTTP)"
        docker_args+=(-e "CHROMADB_TLS_ENABLED=false")
    fi

    # SECURITY: Mount API key as secret file instead of environment variable
    # Environment variables are visible in 'docker inspect' output and /proc/1/environ
    # Secret files mounted read-only are much more secure
    local secrets_dir="${HAL9000_HOME:-$HOME/.hal9000}/secrets"
    if [[ -f "$secrets_dir/anthropic_key" ]]; then
        docker_args+=(-v "${secrets_dir}/anthropic_key:/run/secrets/anthropic_key:ro")
        log_info "SECURITY: Mounting API key as secret file (not env var)"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        # Fallback: If user passes env var but no secret file exists, create one
        log_warn "SECURITY: ANTHROPIC_API_KEY env var detected - storing as secret file"
        mkdir -p "$secrets_dir"
        chmod 700 "$secrets_dir"
        (umask 077 && echo "$ANTHROPIC_API_KEY" > "$secrets_dir/anthropic_key")
        chmod 400 "$secrets_dir/anthropic_key"
        docker_args+=(-v "${secrets_dir}/anthropic_key:/run/secrets/anthropic_key:ro")
        log_success "API key stored securely and mounted as secret file"
    fi

    # Pass worker ID for identification (audit logging, debugging)
    docker_args+=(-e "WORKER_ID=${WORKER_NAME}")
    log_info "Worker ID: ${WORKER_NAME}"

    # NOTE: ChromaDB is intentionally SHARED across all workers
    # This is an architectural decision to enable cross-worker knowledge sharing
    # Workers share the same ChromaDB collections and can search each other's data

    # Pass through ChromaDB cloud credentials if set
    # TODO: Move these to secret files as well in future iteration
    if [[ -n "${CHROMADB_TENANT:-}" ]]; then
        docker_args+=(-e CHROMADB_TENANT)
        log_info "ChromaDB tenant: external configuration"
    fi
    if [[ -n "${CHROMADB_API_KEY:-}" ]]; then
        # SECURITY: Also store ChromaDB API key as secret file
        if [[ ! -f "$secrets_dir/chromadb_api_key" ]]; then
            mkdir -p "$secrets_dir"
            chmod 700 "$secrets_dir"
            (umask 077 && echo "$CHROMADB_API_KEY" > "$secrets_dir/chromadb_api_key")
            chmod 400 "$secrets_dir/chromadb_api_key"
        fi
        docker_args+=(-v "${secrets_dir}/chromadb_api_key:/run/secrets/chromadb_api_key:ro")
        log_info "SECURITY: Mounting ChromaDB API key as secret file"
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

    # SECURITY: Apply seccomp profile to block dangerous syscalls
    # Profile must exist on HOST filesystem (Docker reads it before container starts)
    # Blocks: mount, ptrace, setns, bpf, kexec_load, and other container escape vectors
    if [[ -f "$SECCOMP_PROFILE" ]]; then
        docker_args+=(--security-opt "seccomp=${SECCOMP_PROFILE}")
        log_info "Seccomp profile: $SECCOMP_PROFILE (enforcing)"
    else
        log_warn "Seccomp profile not found: $SECCOMP_PROFILE"
        log_warn "SECURITY: Workers will use Docker's default seccomp profile"
        log_warn "Run 'hal-9000 daemon start' to initialize seccomp profiles"
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
    record_session_metadata || {
        log_error "Failed to record session metadata"
        return 1
    }

    # Execute docker run with retry logic (Issue #9)
    # Transient Docker errors (image pull, network issues) are retried
    if [[ "$DETACH" == "true" ]]; then
        local container_id
        if container_id=$(retry_with_backoff 3 2 "docker run for worker $WORKER_NAME" "${docker_args[@]}"); then
            log_success "Worker started: $container_id"

            # Audit log worker spawn
            if command -v audit_worker_spawn >/dev/null 2>&1; then
                audit_worker_spawn "$WORKER_NAME" "$WORKER_IMAGE" "${canonical_path:-$PROJECT_DIR}"
            fi

            # Security audit: log worker spawn with security context
            if command -v log_security_event >/dev/null 2>&1; then
                local seccomp_status="default"
                [[ -f "$SECCOMP_PROFILE" ]] && seccomp_status="custom"
                log_security_event "WORKER_SPAWN" "name=${WORKER_NAME} image=${WORKER_IMAGE} project=\"${canonical_path:-$PROJECT_DIR}\" seccomp=${seccomp_status}" "INFO"
            fi

            echo "$container_id"
        else
            log_error "Failed to start worker after retries"
            cleanup_on_error "$WORKER_NAME"
            return 1
        fi
    else
        if retry_with_backoff 3 2 "docker run for worker $WORKER_NAME" "${docker_args[@]}"; then
            log_success "Worker started successfully"

            # Audit log worker spawn
            if command -v audit_worker_spawn >/dev/null 2>&1; then
                audit_worker_spawn "$WORKER_NAME" "$WORKER_IMAGE" "${canonical_path:-$PROJECT_DIR}"
            fi

            # Security audit: log worker spawn with security context
            if command -v log_security_event >/dev/null 2>&1; then
                local seccomp_status="default"
                [[ -f "$SECCOMP_PROFILE" ]] && seccomp_status="custom"
                log_security_event "WORKER_SPAWN" "name=${WORKER_NAME} image=${WORKER_IMAGE} project=\"${canonical_path:-$PROJECT_DIR}\" seccomp=${seccomp_status}" "INFO"
            fi
        else
            log_error "Failed to start worker after retries"
            cleanup_on_error "$WORKER_NAME"
            return 1
        fi
    fi
}

record_session_metadata() {
    local user_hash
    user_hash=$(get_user_hash)
    local session_file="${HAL9000_HOME:-$HOME/.hal9000}/sessions/${WORKER_NAME}.json"

    # SECURITY: Create file with restrictive permissions to prevent other users from reading
    (umask 077 && cat > "$session_file" <<EOF
{
    "name": "$WORKER_NAME",
    "image": "$WORKER_IMAGE",
    "parent": "$PARENT_CONTAINER",
    "project_dir": "${canonical_path:-$PROJECT_DIR}",
    "created_at": "$(date -Iseconds)",
    "detached": $DETACH,
    "remove_on_exit": $REMOVE_ON_EXIT,
    "resource_limits": {
        "enabled": $APPLY_LIMITS,
        "memory": "$WORKER_MEMORY",
        "cpus": "$WORKER_CPUS",
        "pids_limit": "$WORKER_PIDS_LIMIT"
    },
    "user_isolation": {
        "user_hash": "$user_hash",
        "user_id": "${USER:-$(id -un 2>/dev/null || echo uid-$(id -u))}",
        "volumes": {
            "claude_home": "hal9000-claude-home-${user_hash}",
            "memory_bank": "hal9000-memory-bank-${user_hash}",
            "tmux_sockets": "hal9000-tmux-sockets-${user_hash}",
            "coordinator_state": "hal9000-coordinator-state-${user_hash}"
        }
    }
}
EOF
    )
    chmod 600 "$session_file"  # Extra safety layer
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
