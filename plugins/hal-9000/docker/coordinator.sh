#!/usr/bin/env bash
# coordinator.sh - HAL-9000 Worker Coordination Functions
#
# This script provides functions for managing worker containers.
# It can be sourced or run directly for specific operations.
#
# Usage:
#   coordinator.sh list                    # List active workers
#   coordinator.sh count                   # Count active workers
#   coordinator.sh stop <worker_name>      # Stop a specific worker
#   coordinator.sh stop-all                # Stop all workers
#   coordinator.sh logs <worker_name>      # View worker logs
#   coordinator.sh attach <worker_name>    # Attach to worker (via tmux)
#   coordinator.sh status                  # Show status summary

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[coord]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[coord]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[coord]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[coord]${NC} %s\n" "$1" >&2; }

# Source audit logging library
if [[ -f "/scripts/lib/audit-log.sh" ]]; then
    source /scripts/lib/audit-log.sh
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
fi

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
# VALIDATION
# ============================================================================

validate_worker_name() {
    local worker_name="$1"

    # Empty check
    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # Only allow alphanumeric, dash, underscore
    # Prevents: path traversal (..), command injection ($(), ``), shell metacharacters
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid worker name: $worker_name (contains invalid characters)"
        return 1
    fi

    return 0
}

# ============================================================================
# WORKER MANAGEMENT
# ============================================================================

list_workers() {
    docker ps \
        --filter "name=hal9000-worker" \
        --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}"
}

count_workers() {
    docker ps \
        --filter "name=hal9000-worker" \
        --format "{{.Names}}" | wc -l | tr -d ' '
}

get_worker_ids() {
    docker ps \
        --filter "name=hal9000-worker" \
        --format "{{.ID}}"
}

cleanup_session_metadata() {
    local worker_name="$1"
    local session_dir="${HAL9000_HOME:-/root/.hal9000}/sessions"
    local metadata_file="$session_dir/${worker_name}.json"

    # Ensure session directory exists
    mkdir -p "$session_dir" 2>/dev/null || true

    # Check if metadata file exists before removal
    if [[ -f "$metadata_file" ]]; then
        if rm -f "$metadata_file"; then
            log_info "Cleaned up session metadata: $worker_name"

            # Audit log session cleanup
            if command -v audit_session_cleanup >/dev/null 2>&1; then
                audit_session_cleanup "$worker_name" "true"
            fi

            return 0
        else
            log_warn "Failed to remove session metadata: $metadata_file"

            # Audit log failed cleanup
            if command -v audit_session_cleanup >/dev/null 2>&1; then
                audit_session_cleanup "$worker_name" "false"
            fi

            return 1
        fi
    else
        log_info "Session metadata not found: $worker_name (already cleaned)"

        # Audit log (already cleaned)
        if command -v audit_session_cleanup >/dev/null 2>&1; then
            audit_session_cleanup "$worker_name" "already_cleaned"
        fi

        return 0
    fi
}

cleanup_stale_metadata() {
    local session_dir="${HAL9000_HOME:-/root/.hal9000}/sessions"
    local stale_days="${1:-7}"  # Default: 7 days old
    local count=0

    # Ensure session directory exists
    if [[ ! -d "$session_dir" ]]; then
        log_info "Session directory does not exist: $session_dir"
        return 0
    fi

    log_info "Cleaning up stale session metadata (older than $stale_days days)..."

    # Find and remove files older than specified days
    while IFS= read -r -d '' file; do
        if rm -f "$file"; then
            log_info "Removed stale session metadata: $(basename "$file")"
            ((count++))
        else
            log_warn "Failed to remove stale metadata: $file"
        fi
    done < <(find "$session_dir" -name "*.json" -type f -mtime "+$stale_days" -print0 2>/dev/null)

    if [[ $count -gt 0 ]]; then
        log_success "Cleaned up $count stale session metadata files"
    else
        log_info "No stale session metadata found"
    fi
}

stop_worker() {
    local worker_name="$1"

    validate_worker_name "$worker_name" || return 1

    log_info "Stopping worker: $worker_name"

    # Use circuit breaker for Docker stop operation (can fail transiently)
    if circuit_breaker "docker-stop" \
        "docker stop '$worker_name' >/dev/null 2>&1" \
        3 15; then
        log_success "Worker stopped: $worker_name"

        # Audit log worker stop
        if command -v audit_worker_stop >/dev/null 2>&1; then
            audit_worker_stop "$worker_name" "user_request" "0"
        fi

        # Clean up session metadata with retry
        if retry_with_backoff "cleanup_session_metadata '$worker_name'" 2; then
            log_success "Session metadata cleaned up"
        else
            log_warn "Failed to clean up session metadata for $worker_name"
        fi
    else
        log_error "Failed to stop worker: $worker_name"

        # Audit log failed stop attempt
        if command -v audit_worker_stop >/dev/null 2>&1; then
            audit_worker_stop "$worker_name" "stop_failed" "1"
        fi

        return 1
    fi
}

stop_all_workers() {
    local workers
    workers=$(get_worker_ids)

    if [[ -z "$workers" ]]; then
        log_info "No active workers to stop"
        return 0
    fi

    local count
    count=$(echo "$workers" | wc -l)
    log_warn "Stopping $count worker(s)..."

    echo "$workers" | while read -r worker_id; do
        if docker stop "$worker_id" >/dev/null 2>&1; then
            log_success "Stopped: $worker_id"
        else
            log_error "Failed to stop: $worker_id"
        fi
    done

    log_success "All workers stopped"
}

cleanup_all_session_metadata() {
    local session_dir="${HAL9000_HOME:-/root/.hal9000}/sessions"
    local count=0

    # Ensure session directory exists
    mkdir -p "$session_dir" 2>/dev/null || true

    log_info "Cleaning up all session metadata..."

    if [[ ! -d "$session_dir" ]]; then
        log_info "Session directory does not exist: $session_dir"
        return 0
    fi

    # Remove all worker metadata files
    while IFS= read -r -d '' file; do
        if rm -f "$file"; then
            log_info "Removed session metadata: $(basename "$file")"
            ((count++))
        else
            log_warn "Failed to remove session metadata: $file"
        fi
    done < <(find "$session_dir" -name "*.json" -type f -print0 2>/dev/null)

    if [[ $count -gt 0 ]]; then
        log_success "Cleaned up $count session metadata files"
    else
        log_info "No session metadata files found to clean up"
    fi
}

view_worker_logs() {
    local worker_name="$1"

    validate_worker_name "$worker_name" || return 1

    docker logs -f "$worker_name"
}

attach_to_worker() {
    local worker_name="$1"

    validate_worker_name "$worker_name" || return 1

    # Check if worker exists
    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
        log_error "Worker not found: $worker_name"
        return 1
    fi

    log_info "Attaching to worker: $worker_name"
    docker exec -it "$worker_name" bash
}

# ============================================================================
# WORKER REGISTRY (TMUX-BASED)
# ============================================================================

COORDINATOR_STATE_DIR="${COORDINATOR_STATE_DIR:-/data/coordinator-state}"
TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
WORKERS_REGISTRY="${COORDINATOR_STATE_DIR}/workers.json"

init_coordinator_state() {
    mkdir -p "$COORDINATOR_STATE_DIR"
    # SECURITY: Use 0770 instead of 0777 (restrict socket access to owner and group, not world)
    chmod 0770 "$COORDINATOR_STATE_DIR"
    # Set group ownership to hal9000 if available
    if getent group hal9000 >/dev/null 2>&1; then
        chgrp hal9000 "$COORDINATOR_STATE_DIR" 2>/dev/null || true
    fi
}

update_worker_registry() {
    local workers

    # Fetch worker list with retry (Docker daemon might be temporarily unresponsive)
    if ! retry_with_backoff \
        "workers=\$(docker ps --filter 'name=hal9000-worker' --format '{{.Names}}' 2>/dev/null)" \
        2; then
        log_warn "Failed to fetch worker list after retries, using stale registry"
        return 1
    fi

    init_coordinator_state

    # Build workers.json
    local registry='{'
    local first=true

    if [[ -n "$workers" ]]; then
        while IFS= read -r worker_name; do
            [[ -z "$worker_name" ]] && continue

            if [[ "$first" == "false" ]]; then
                registry="$registry,"
            fi
            first=false

            local tmux_socket="$TMUX_SOCKET_DIR/worker-${worker_name}.sock"
            local tmux_ok="false"
            if [[ -e "$tmux_socket" ]]; then
                tmux_ok="true"
            fi

            # Get container info with circuit breaker for transient failures
            local container_id
            if circuit_breaker "docker-inspect" \
                "container_id=\$(docker ps --filter 'name=^${worker_name}\$' --format '{{.ID}}' 2>/dev/null)" \
                3 10; then
                :
            else
                container_id="unknown"
            fi

            # Get uptime - non-critical, use default if fails
            local created_at
            created_at=$(docker inspect "$container_id" --format='{{.Created}}' 2>/dev/null || echo "unknown")

            registry="$registry\"$worker_name\":{\"status\":\"running\",\"tmux_socket\":\"$tmux_socket\",\"tmux_ready\":$tmux_ok,\"container_id\":\"$container_id\",\"created_at\":\"$created_at\"}"
        done <<< "$workers"
    fi

    registry="$registry}"

    # Write registry file (atomic write with temp file)
    local temp_file="${WORKERS_REGISTRY}.tmp"
    echo "$registry" > "$temp_file"
    mv "$temp_file" "$WORKERS_REGISTRY"

    log_info "Worker registry updated: $(echo "$workers" | wc -l) workers"
}

validate_worker_sessions() {
    init_coordinator_state

    local stale_count=0

    # Check TMUX sockets for stale entries
    if [[ -d "$TMUX_SOCKET_DIR" ]]; then
        for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
            [[ ! -e "$socket" ]] && continue

            # Extract worker name from socket path
            local socket_name
            socket_name=$(basename "$socket" .sock)
            local worker_name="${socket_name#worker-}"

            # Validate worker name (prevents command injection via specially-crafted socket filenames)
            if ! validate_worker_name "$worker_name" 2>/dev/null; then
                rm -f "$socket" 2>/dev/null || true
                ((stale_count++))
                continue
            fi

            # Check if corresponding container is running
            if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
                log_warn "Removing stale TMUX socket: $socket"
                rm -f "$socket" 2>/dev/null || true
                ((stale_count++))
            fi
        done
    fi

    if [[ $stale_count -gt 0 ]]; then
        log_info "Cleaned up $stale_count stale TMUX sockets"
    fi
}

get_worker_tmux_socket() {
    local worker_name="$1"

    validate_worker_name "$worker_name" || return 1

    local socket="$TMUX_SOCKET_DIR/worker-${worker_name}.sock"

    if [[ ! -e "$socket" ]]; then
        log_error "TMUX socket not found for worker: $worker_name"
        return 1
    fi

    echo "$socket"
}

# ============================================================================
# STATUS
# ============================================================================

show_status() {
    echo "=== HAL-9000 Coordinator Status ==="
    echo

    # Parent info
    echo "Parent Container:"
    if docker ps --format '{{.Names}}' | grep -q "^hal9000-parent$"; then
        printf "  ${GREEN}●${NC} hal9000-parent (running)\n"
    else
        printf "  ${RED}○${NC} hal9000-parent (not running)\n"
    fi
    echo

    # Worker count
    local worker_count
    worker_count=$(count_workers)
    echo "Active Workers: $worker_count"

    if [[ "$worker_count" -gt 0 ]]; then
        echo
        list_workers
    fi
    echo

    # Session files
    local session_dir="${HAL9000_HOME:-/root/.hal9000}/sessions"
    local session_count
    session_count=$(find "$session_dir" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "Session Records: $session_count"

    # Resource usage
    echo
    echo "Resource Usage (workers):"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null) 2>/dev/null \
        || echo "  No workers running"
}

# ============================================================================
# MAIN
# ============================================================================

show_help() {
    cat <<EOF
HAL-9000 Worker Coordinator

Usage: coordinator.sh <command> [args]

Commands:
  list              List active workers
  count             Count active workers
  stop <name>       Stop a specific worker
  stop-all          Stop all workers
  logs <name>       View worker logs (follow mode)
  attach <name>     Attach to worker shell
  cleanup-metadata <name>     Remove session metadata for specific worker
  cleanup-all-metadata        Remove all session metadata files
  cleanup-stale [days]        Remove stale metadata (default: 7 days old)
  status            Show status summary
  help              Show this help

Metadata Management:
  Session metadata (.json files) are created in ~/.hal9000/sessions/
  when workers are started and removed when workers are stopped.
  Use cleanup commands to manually remove orphaned metadata.

Examples:
  coordinator.sh list
  coordinator.sh stop hal9000-worker-1234567890
  coordinator.sh attach hal9000-worker-1234567890
  coordinator.sh cleanup-metadata hal9000-worker-1234567890
  coordinator.sh cleanup-stale 14          # Remove metadata older than 14 days
  coordinator.sh cleanup-all-metadata
  coordinator.sh stop-all
EOF
}

main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        list)
            list_workers
            ;;
        count)
            count_workers
            ;;
        stop)
            stop_worker "$@"
            ;;
        stop-all)
            stop_all_workers
            ;;
        logs)
            view_worker_logs "$@"
            ;;
        attach)
            attach_to_worker "$@"
            ;;
        cleanup-metadata)
            cleanup_session_metadata "$@"
            ;;
        cleanup-all-metadata)
            cleanup_all_session_metadata
            ;;
        cleanup-stale)
            cleanup_stale_metadata "$@"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
