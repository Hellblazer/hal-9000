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
#
# Volume Cleanup (LOW-8):
# To clean up orphaned volumes after crashes or incomplete shutdowns:
#   docker volume ls | grep hal9000 | awk '{print $2}' | xargs docker volume rm
# To clean up volumes for a specific user (use user hash from volume name):
#   docker volume ls | grep 'hal9000.*<user_hash>' | awk '{print $2}' | xargs docker volume rm
# To list all hal9000 volumes with their sizes:
#   docker system df -v | grep hal9000

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

# HIGH-4: Hash a secret for safe logging (shows first 16 chars of SHA256)
# Usage: log_info "API key fingerprint: $(hash_for_log "$SECRET")"
# This prevents exposing actual secret values while still allowing correlation
hash_for_log() {
    local secret="$1"
    if [[ -z "$secret" ]]; then
        echo "empty"
        return
    fi
    # Use printf to avoid newline issues, sha256sum for hashing
    # cut -c1-16 provides 64 bits of entropy - sufficient for log correlation
    printf '%s' "$secret" | sha256sum 2>/dev/null | cut -c1-16 || \
    printf '%s' "$secret" | shasum -a 256 2>/dev/null | cut -c1-16 || \
    echo "hash_error"
}

# Source audit logging library
if [[ -f "/scripts/lib/audit-log.sh" ]]; then
    source /scripts/lib/audit-log.sh
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
fi

# ============================================================================
# MEDIUM-1: Certificate Validation
# ============================================================================
# Validates certificate before mounting to ensure:
# 1. File exists and is readable
# 2. Certificate is in valid PEM format
# 3. Certificate has not expired
# 4. Optionally validates fingerprint for pinning

validate_certificate() {
    local cert_file="$1"
    local expected_fingerprint="${2:-}"  # Optional: SHA256 fingerprint for pinning

    # Check file exists
    if [[ ! -f "$cert_file" ]]; then
        log_error "Certificate file not found: $cert_file"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "$cert_file" ]]; then
        log_error "Certificate file not readable: $cert_file"
        return 1
    fi

    # Check openssl is available
    if ! command -v openssl >/dev/null 2>&1; then
        log_warn "openssl not available - skipping certificate validation"
        return 0
    fi

    # Verify it's a valid PEM certificate
    if ! openssl x509 -in "$cert_file" -noout 2>/dev/null; then
        log_error "Invalid certificate format (not valid PEM): $cert_file"
        return 1
    fi

    # Check certificate hasn't expired
    if ! openssl x509 -in "$cert_file" -checkend 0 >/dev/null 2>&1; then
        log_warn "Certificate has expired: $cert_file"
        # Don't fail on expiration - just warn (allows continued operation with expired cert)
        # Remove this line and return 1 if strict expiration enforcement is needed
    fi

    # Check certificate is not expiring soon (7 days warning)
    if ! openssl x509 -in "$cert_file" -checkend 604800 >/dev/null 2>&1; then
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
        log_warn "Certificate expiring soon (within 7 days): $cert_file"
        log_warn "Expiry date: $expiry_date"
    fi

    # Certificate pinning: validate fingerprint if provided
    if [[ -n "$expected_fingerprint" ]]; then
        local actual_fingerprint
        actual_fingerprint=$(openssl x509 -noout -fingerprint -sha256 -in "$cert_file" 2>/dev/null | cut -d= -f2)
        if [[ -z "$actual_fingerprint" ]]; then
            log_error "Failed to compute certificate fingerprint: $cert_file"
            return 1
        fi
        # Normalize fingerprints for comparison (remove colons, lowercase)
        local normalized_expected normalized_actual
        normalized_expected=$(echo "$expected_fingerprint" | tr -d ':' | tr '[:upper:]' '[:lower:]')
        normalized_actual=$(echo "$actual_fingerprint" | tr -d ':' | tr '[:upper:]' '[:lower:]')
        if [[ "$normalized_actual" != "$normalized_expected" ]]; then
            log_error "Certificate fingerprint mismatch (possible MITM attack)!"
            log_error "Expected: $expected_fingerprint"
            log_error "Actual:   $actual_fingerprint"
            return 1
        fi
        log_success "Certificate fingerprint validated: $cert_file"
    fi

    log_info "Certificate validated: $cert_file"
    return 0
}

# ============================================================================
# MEDIUM-5: Container Detection (cgroups v2 compatible)
# ============================================================================
# Detects if running inside a container (Docker, Podman, Kubernetes, etc.)
# Handles cgroups v1, cgroups v2 (unified hierarchy), and various container runtimes
#
# Returns: 0 if running in container, 1 if running on host

is_running_in_container() {
    # Method 1: Docker's marker file (most reliable for Docker)
    [[ -f "/.dockerenv" ]] && return 0

    # Method 2: Podman container marker file
    [[ -f "/run/.containerenv" ]] && return 0

    # Method 3: Kubernetes environment detection
    [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]] && return 0

    # Method 4: Generic container environment variable
    [[ -n "${container:-}" ]] && return 0

    # Method 5: cgroups v1 - check /proc/1/cgroup for container markers
    if [[ -f /proc/1/cgroup ]]; then
        grep -qE 'docker|containerd|lxc|kubepods|libpod' /proc/1/cgroup 2>/dev/null && return 0
    fi

    # Method 6: cgroups v2 (unified hierarchy) - check mountinfo for container markers
    # In cgroups v2, /proc/1/cgroup just shows "0::/" so we need to check mountinfo
    if [[ -f /proc/1/mountinfo ]]; then
        # Check for overlay filesystem with container-specific paths
        if grep -q 'overlay' /proc/1/mountinfo 2>/dev/null; then
            grep -qE '/docker/|/containerd/|/libpod-|/buildkit/' /proc/1/mountinfo 2>/dev/null && return 0
        fi
        # Check for container-specific mounts
        grep -qE '/var/lib/docker/|/var/lib/containerd/' /proc/1/mountinfo 2>/dev/null && return 0
    fi

    # Method 7: Check if init process is not systemd/init (container PID 1 is usually the app)
    # This is less reliable but can catch edge cases
    if [[ -f /proc/1/comm ]]; then
        local init_comm
        init_comm=$(cat /proc/1/comm 2>/dev/null)
        # If PID 1 is not a typical init system, likely in a container
        case "$init_comm" in
            systemd|init|launchd|upstart) ;;  # Host init systems
            *)
                # Additional check: see if we have very few processes (typical of containers)
                local proc_count
                proc_count=$(find /proc -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | wc -l)
                [[ $proc_count -lt 50 ]] && return 0
                ;;
        esac
    fi

    # Not detected as container
    return 1
}

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

# Retry configuration (STYLE-3: make magic numbers configurable)
DOCKER_RUN_MAX_RETRIES="${DOCKER_RUN_MAX_RETRIES:-3}"
DOCKER_RUN_INITIAL_WAIT="${DOCKER_RUN_INITIAL_WAIT:-2}"

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
# VOLUME MIGRATION (Legacy -> User-Scoped)
# ============================================================================

# MIGRATION: Detect legacy volumes from previous hal-9000 versions
# Old naming conventions that need migration:
# - hal9000-claude-home (no hash suffix)
# - hal9000-memory-bank (no hash suffix)
# - hal9000-tmux-sockets (no hash suffix)
# - hal9000-coordinator-state (no hash suffix)

# Legacy volume base names (without user hash)
readonly LEGACY_VOLUME_BASES=(
    "claude-home"
    "memory-bank"
    "tmux-sockets"
    "coordinator-state"
)

# Check if migration marker exists (indicates migration already done)
migration_marker_exists() {
    local user_hash
    user_hash=$(get_user_hash)
    local marker_file="${HAL9000_HOME:-$HOME/.hal9000}/migration/${user_hash}.migrated"
    [[ -f "$marker_file" ]]
}

# Create migration marker to prevent repeated migration attempts
create_migration_marker() {
    local user_hash
    user_hash=$(get_user_hash)
    local marker_dir="${HAL9000_HOME:-$HOME/.hal9000}/migration"
    local marker_file="${marker_dir}/${user_hash}.migrated"

    # MEDIUM-3: Create directory with restrictive permissions atomically using umask
    (umask 077 && mkdir -p "$marker_dir") 2>/dev/null || true

    # MEDIUM-3: Create migration marker file with restrictive permissions atomically using umask
    (umask 077 && cat > "$marker_file" <<EOF
{
    "user_hash": "$user_hash",
    "user_id": "${USER:-$(id -un 2>/dev/null || echo uid-$(id -u))}",
    "migrated_at": "$(date -Iseconds)",
    "migrated_volumes": $1
}
EOF
    )
    log_info "Migration marker created: $marker_file"
}

# Detect legacy volumes that exist without user hash suffix
# Returns: space-separated list of legacy volume names
detect_legacy_volumes() {
    local legacy_volumes=()

    for base_name in "${LEGACY_VOLUME_BASES[@]}"; do
        local legacy_vol="hal9000-${base_name}"

        # Check if old volume exists (without hash suffix)
        if docker volume inspect "$legacy_vol" &>/dev/null; then
            legacy_volumes+=("$legacy_vol")
        fi
    done

    # Also check for any other hal9000 volumes that don't have our user hash
    local user_hash
    user_hash=$(get_user_hash)

    while IFS= read -r vol; do
        # Skip if already in list
        local already_listed=false
        for existing in "${legacy_volumes[@]}"; do
            if [[ "$vol" == "$existing" ]]; then
                already_listed=true
                break
            fi
        done

        # Skip volumes that already have our user hash
        if [[ "$already_listed" == "false" && "$vol" == hal9000-* && "$vol" != *"-${user_hash}" ]]; then
            # Check if this looks like a legacy volume (matches one of our base patterns)
            for base_name in "${LEGACY_VOLUME_BASES[@]}"; do
                if [[ "$vol" == "hal9000-${base_name}" ]]; then
                    legacy_volumes+=("$vol")
                    break
                fi
            done
        fi
    done < <(docker volume ls -q 2>/dev/null | grep "^hal9000-" || true)

    echo "${legacy_volumes[*]}"
}

# Migrate data from legacy volume to new user-scoped volume
# Args: $1 = legacy volume name, $2 = new volume name
migrate_single_volume() {
    local old_vol="$1"
    local new_vol="$2"

    # Skip if old volume doesn't exist
    if ! docker volume inspect "$old_vol" &>/dev/null; then
        log_info "Legacy volume not found, skipping: $old_vol"
        return 0
    fi

    # Create new volume if it doesn't exist
    if ! docker volume inspect "$new_vol" &>/dev/null; then
        docker volume create "$new_vol" >/dev/null 2>&1 || {
            log_error "Failed to create volume: $new_vol"
            return 1
        }
        log_info "Created new volume: $new_vol"
    else
        log_info "Target volume already exists: $new_vol"
        # Check if target has data - if so, don't overwrite
        local has_data
        has_data=$(docker run --rm -v "${new_vol}:/check:ro" alpine sh -c "ls -A /check 2>/dev/null | head -1" 2>/dev/null || echo "")
        if [[ -n "$has_data" ]]; then
            log_warn "Target volume $new_vol already has data, skipping migration to avoid data loss"
            return 0
        fi
    fi

    log_info "Migrating: $old_vol -> $new_vol"

    # Use alpine container to copy data between volumes
    # Mount old as read-only, new as read-write
    if docker run --rm \
        -v "${old_vol}:/old:ro" \
        -v "${new_vol}:/new" \
        alpine sh -c "cp -a /old/. /new/ 2>/dev/null || true" 2>/dev/null; then
        log_success "Migration complete: $old_vol -> $new_vol"
        return 0
    else
        log_error "Migration failed: $old_vol -> $new_vol"
        return 1
    fi
}

# Run migration for all legacy volumes
# This is called once per user on first run after upgrade
migrate_legacy_volumes() {
    # Skip if already migrated
    if migration_marker_exists; then
        return 0
    fi

    log_info "Checking for legacy volumes to migrate..."

    local legacy_volumes
    legacy_volumes=$(detect_legacy_volumes)

    if [[ -z "$legacy_volumes" ]]; then
        log_info "No legacy volumes found"
        create_migration_marker "[]"
        return 0
    fi

    log_info "Found legacy volumes: $legacy_volumes"
    log_info ""
    log_info "=== Volume Migration ==="
    log_info "hal-9000 now uses per-user volume isolation for security."
    log_info "Your existing data will be migrated to user-scoped volumes."
    log_info "Original volumes will be preserved as backups."
    log_info "========================"
    log_info ""

    local user_hash
    user_hash=$(get_user_hash)
    local migrated_volumes="["
    local first=true
    local migration_count=0

    # Migrate each legacy volume
    for base_name in "${LEGACY_VOLUME_BASES[@]}"; do
        local old_vol="hal9000-${base_name}"
        local new_vol="hal9000-${base_name}-${user_hash}"

        # Check if this legacy volume exists
        if echo "$legacy_volumes" | grep -q "$old_vol"; then
            if migrate_single_volume "$old_vol" "$new_vol"; then
                ((++migration_count))  # Use pre-increment to avoid set -e exit when count is 0
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    migrated_volumes+=","
                fi
                migrated_volumes+="\"$old_vol\""
            fi
        fi
    done

    migrated_volumes+="]"

    if [[ $migration_count -gt 0 ]]; then
        log_success ""
        log_success "=== Migration Summary ==="
        log_success "Migrated $migration_count volume(s) to user-scoped naming."
        log_success "Original volumes preserved as backups:"
        for vol in $legacy_volumes; do
            log_success "  - $vol (backup)"
        done
        log_success ""
        log_success "To remove old volumes after verifying migration:"
        log_success "  docker volume rm $legacy_volumes"
        log_success "========================="
        log_success ""
    fi

    # Mark migration as complete
    create_migration_marker "$migrated_volumes"
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
#
# MEDIUM-7: How to update this allowlist when new versions are released:
# 1. Verify the new image tag exists: docker pull ghcr.io/hellblazer/hal-9000:<new-tag>
# 2. Verify image integrity: docker inspect --format '{{.RepoDigests}}' <image>
# 3. Update this array with the new versioned tag
# 4. Remove old versions only after confirming new version works
# 5. Consider keeping 1-2 previous versions for rollback capability
# 6. Run security tests with new image before production deployment
#
# Example version bump: v3.0.0 -> v3.1.0
#   - Add "ghcr.io/hellblazer/hal-9000:worker-v3.1.0" to the array
#   - Test with: spawn-worker.sh -i ghcr.io/hellblazer/hal-9000:worker-v3.1.0
#   - Remove v3.0.0 entries after validation (optional, can keep for rollback)
ALLOWED_IMAGES=(
    # Versioned images (pinned for production)
    "ghcr.io/hellblazer/hal-9000:worker-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:python-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:node-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:java-v3.0.0"
    # Unversioned images (for development/latest)
    "ghcr.io/hellblazer/hal-9000:worker"
    "ghcr.io/hellblazer/hal-9000:base"
    "ghcr.io/hellblazer/hal-9000:python"
    "ghcr.io/hellblazer/hal-9000:node"
    "ghcr.io/hellblazer/hal-9000:java"
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

    # HIGH-1: Sanitize WORKER_NAME to prevent log injection via console output
    # Remove ANSI escape sequences and control characters from user-provided names
    # Uses sanitize_log_value() if available (from audit-log.sh), otherwise inline sanitization
    if declare -f sanitize_log_value >/dev/null 2>&1; then
        WORKER_NAME=$(sanitize_log_value "$WORKER_NAME")
    else
        # Fallback: remove ANSI escapes and control characters inline
        WORKER_NAME=$(printf '%s' "$WORKER_NAME" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d '\000-\037\177')
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

        # MEDIUM-4: SECURITY: Allowlist of permitted path prefixes (more secure than blocklist)
        # In DinD mode, paths are HOST paths passed to docker for mounting.
        # We must allow common host path patterns even when running inside a container.
        local allowed_prefixes=()

        # Container paths
        if [[ -n "${HOME:-}" ]]; then
            allowed_prefixes+=("$HOME")
        fi
        allowed_prefixes+=("/workspace")
        allowed_prefixes+=("/tmp")
        allowed_prefixes+=("/root")

        # HOST paths (for DinD mode - paths passed through to docker daemon on host)
        # macOS: /Users/<username>
        # Linux: /home/<username>
        # These are HOST paths that get mounted into the worker container
        allowed_prefixes+=("/Users")
        allowed_prefixes+=("/home")

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

    # MIGRATION: Check for and migrate legacy volumes before using new naming
    # This ensures existing users don't lose their marketplace installations and credentials
    migrate_legacy_volumes

    local user_hash
    user_hash=$(get_user_hash)
    log_info "User isolation: hash=${user_hash} (user=${USER:-$(id -un 2>/dev/null || echo uid-$(id -u))})"

    # MEDIUM-5: Detect Docker-in-Docker mode (running inside a container)
    # Enhanced detection for cgroups v2, Podman, and Kubernetes
    # Uses is_running_in_container() helper for cleaner code
    local in_container
    in_container=$(is_running_in_container && echo "true" || echo "false")

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
        # MEDIUM-3: Create directory with restrictive permissions atomically using umask
        (umask 077 && mkdir -p "$claude_home") 2>/dev/null || true

        # Also create user-scoped TMUX sockets directory
        local tmux_sockets_dir="${hal9000_home}/users/${user_hash}/tmux-sockets"
        # MEDIUM-3: Create directory with restrictive permissions atomically using umask
        (umask 077 && mkdir -p "$tmux_sockets_dir") 2>/dev/null || true

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
    # MEDIUM-1: Validate certificate before mounting
    local chromadb_cert_file="/run/secrets/chromadb.crt"
    if [[ -f "$chromadb_cert_file" ]]; then
        # Validate certificate format and expiration before mounting
        # Optional fingerprint pinning via CHROMADB_CERT_FINGERPRINT env var
        if validate_certificate "$chromadb_cert_file" "${CHROMADB_CERT_FINGERPRINT:-}"; then
            docker_args+=(-v "${chromadb_cert_file}:/run/secrets/chromadb.crt:ro")
            docker_args+=(-e "CHROMADB_TLS_ENABLED=true")
            # Pass fingerprint to worker for its own validation (defense in depth)
            if [[ -n "${CHROMADB_CERT_FINGERPRINT:-}" ]]; then
                docker_args+=(-e "CHROMADB_CERT_FINGERPRINT=${CHROMADB_CERT_FINGERPRINT}")
                log_info "ChromaDB TLS: certificate mounted with fingerprint pinning (HTTPS enabled)"
            else
                log_info "ChromaDB TLS: certificate mounted (HTTPS enabled)"
            fi
        else
            log_error "ChromaDB TLS: certificate validation failed - refusing to mount"
            log_error "Fix the certificate or disable TLS by removing $chromadb_cert_file"
            exit 1
        fi
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
        # SECURITY: Fail if API key is passed via environment variable
        # Environment variables are visible via 'docker inspect' and /proc/1/environ
        log_error "SECURITY VIOLATION: ANTHROPIC_API_KEY environment variable detected"
        log_error "API keys in environment variables are visible via 'docker inspect' and /proc/1/environ"
        log_error ""
        log_error "To fix, use file-based secrets instead:"
        log_error "  1. Store your key: echo 'your-key' > ${secrets_dir}/anthropic_key"
        log_error "  2. Set permissions: chmod 400 ${secrets_dir}/anthropic_key"
        log_error "  3. Remove env var: unset ANTHROPIC_API_KEY"
        log_error "  4. Update your shell profile to not set this variable"
        exit 1
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
    #
    # MEDIUM-10: Fail if seccomp is configured but profile is unavailable
    # If SECCOMP_PROFILE is explicitly set (non-empty), the profile MUST exist
    # This prevents silently falling back to weaker security when hardened profile expected
    if [[ -n "${SECCOMP_PROFILE:-}" ]]; then
        if [[ -f "$SECCOMP_PROFILE" ]]; then
            docker_args+=(--security-opt "seccomp=${SECCOMP_PROFILE}")
            log_info "Seccomp profile: $SECCOMP_PROFILE (enforcing)"
        else
            log_error "Seccomp profile not found: $SECCOMP_PROFILE"
            log_error "SECURITY: Refusing to spawn worker without required seccomp profile"
            log_error ""
            log_error "To fix this issue:"
            log_error "  1. Initialize profiles: hal-9000 daemon start"
            log_error "  2. Or create profile: mkdir -p $(dirname "$SECCOMP_PROFILE")"
            log_error "  3. Or disable seccomp (NOT recommended): unset SECCOMP_PROFILE"
            exit 1
        fi
    else
        log_warn "SECCOMP_PROFILE not set - using Docker's default seccomp profile"
        log_warn "For enhanced security, run 'hal-9000 daemon start' to initialize profiles"
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
    # STYLE-1: Use run_container() helper to reduce code duplication
    run_container "${docker_args[@]}"
}

# run_container: Execute docker run with retry, audit logging, and error handling (STYLE-1)
# Extracts common logic from spawn_worker to reduce duplication
# Uses DOCKER_RUN_MAX_RETRIES and DOCKER_RUN_INITIAL_WAIT for configurable retry (STYLE-3)
# Usage: run_container <docker_args...>
run_container() {
    local -a container_args=("$@")

    # Execute docker run with configurable retry (STYLE-3)
    if [[ "$DETACH" == "true" ]]; then
        local container_id
        if container_id=$(retry_with_backoff "$DOCKER_RUN_MAX_RETRIES" "$DOCKER_RUN_INITIAL_WAIT" "docker run for worker $WORKER_NAME" "${container_args[@]}"); then
            log_success "Worker started: $container_id"
            log_worker_spawn_audit
            echo "$container_id"
        else
            log_error "Failed to start worker after $DOCKER_RUN_MAX_RETRIES retries"
            cleanup_on_error "$WORKER_NAME"
            return 1
        fi
    else
        if retry_with_backoff "$DOCKER_RUN_MAX_RETRIES" "$DOCKER_RUN_INITIAL_WAIT" "docker run for worker $WORKER_NAME" "${container_args[@]}"; then
            log_success "Worker started successfully"
            log_worker_spawn_audit
        else
            log_error "Failed to start worker after $DOCKER_RUN_MAX_RETRIES retries"
            cleanup_on_error "$WORKER_NAME"
            return 1
        fi
    fi
}

# log_worker_spawn_audit: Log worker spawn to audit logs (STYLE-1)
# Extracted from spawn_worker to reduce duplication
log_worker_spawn_audit() {
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
    # MEDIUM-3: Removed redundant chmod - umask 077 already ensures 600 permissions atomically
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
