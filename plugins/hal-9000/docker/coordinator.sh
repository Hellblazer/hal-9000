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

stop_worker() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # SECURITY: Validate worker name format (alphanumeric, dash, underscore only)
    # Prevents command injection via malformed worker names
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid worker name: $worker_name (contains invalid characters)"
        return 1
    fi

    log_info "Stopping worker: $worker_name"

    if docker stop "$worker_name" >/dev/null 2>&1; then
        log_success "Worker stopped: $worker_name"

        # Clean up session metadata
        rm -f "${HAL9000_HOME:-/root/.hal9000}/sessions/${worker_name}.json"
    else
        log_error "Failed to stop worker: $worker_name"
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

    # Clean up all session metadata
    rm -f "${HAL9000_HOME:-/root/.hal9000}/sessions/hal9000-worker-"*.json 2>/dev/null || true

    log_success "All workers stopped"
}

view_worker_logs() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # SECURITY: Validate worker name format (alphanumeric, dash, underscore only)
    # Prevents command injection via malformed worker names
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid worker name: $worker_name (contains invalid characters)"
        return 1
    fi

    docker logs -f "$worker_name"
}

attach_to_worker() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # SECURITY: Validate worker name format (alphanumeric, dash, underscore only)
    # Prevents command injection via malformed worker names
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid worker name: $worker_name (contains invalid characters)"
        return 1
    fi

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
    chmod 0777 "$COORDINATOR_STATE_DIR"
}

update_worker_registry() {
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null)

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

            # Get container info
            local container_id
            container_id=$(docker ps --filter "name=^${worker_name}$" --format "{{.ID}}" 2>/dev/null)

            # Get uptime
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

            # SECURITY: Validate worker name format (alphanumeric, dash, underscore only)
            # Prevents command injection via specially-crafted socket filenames
            if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log_error "Invalid worker name from socket: $worker_name (contains invalid characters)"
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

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # SECURITY: Validate worker name format (alphanumeric, dash, underscore only)
    # Prevents command injection via malformed worker names
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid worker name: $worker_name (contains invalid characters)"
        return 1
    fi

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
  status            Show status summary
  help              Show this help

Examples:
  coordinator.sh list
  coordinator.sh stop hal9000-worker-1234567890
  coordinator.sh attach hal9000-worker-1234567890
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
