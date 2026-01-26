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

    docker logs -f "$worker_name"
}

attach_to_worker() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
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
