#!/usr/bin/env bash
# tmux-worker.sh - tmux-integrated worker lifecycle management
#
# Combines spawn-worker.sh with tmux window management:
# - Creates tmux window for each worker
# - Attaches worker to window automatically
# - Cleans up window when worker exits
#
# Usage:
#   tmux-worker.sh spawn [options]      # Spawn worker in new tmux window
#   tmux-worker.sh attach <name>        # Attach to existing worker
#   tmux-worker.sh cleanup              # Clean up orphaned windows
#   tmux-worker.sh sync                 # Sync windows with running workers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[tmux-worker]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[tmux-worker]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[tmux-worker]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[tmux-worker]${NC} %s\n" "$1" >&2; }

TMUX_SOCKET="${TMUX_SOCKET:-hal9000}"
SESSION_NAME="${SESSION_NAME:-hal9000}"

# ============================================================================
# TMUX HELPERS
# ============================================================================

ensure_session() {
    if ! tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_info "Creating tmux session: $SESSION_NAME"
        tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "dashboard"

        # Load custom config if available
        if [[ -f "${SCRIPT_DIR}/tmux-dashboard.conf" ]]; then
            tmux -L "$TMUX_SOCKET" source-file "${SCRIPT_DIR}/tmux-dashboard.conf"
        fi
    fi
}

get_window_name() {
    local worker_name="$1"
    echo "${worker_name#hal9000-worker-}"
}

window_exists() {
    local window_name="$1"
    tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" 2>/dev/null \
        | grep -q ":${window_name}[\* ]*$"
}

create_window() {
    local window_name="$1"
    local command="$2"

    ensure_session

    if window_exists "$window_name"; then
        log_warn "Window already exists: $window_name"
        return 0
    fi

    tmux -L "$TMUX_SOCKET" new-window -t "$SESSION_NAME" -n "$window_name"
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:$window_name" "$command" Enter
}

destroy_window() {
    local window_name="$1"

    if window_exists "$window_name"; then
        tmux -L "$TMUX_SOCKET" kill-window -t "$SESSION_NAME:$window_name" 2>/dev/null || true
        log_info "Destroyed window: $window_name"
    fi
}

# ============================================================================
# WORKER LIFECYCLE
# ============================================================================

spawn_with_window() {
    local spawn_args=()
    local worker_name=""
    local project_dir=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                worker_name="$2"
                spawn_args+=(-n "$2")
                shift 2
                ;;
            -*)
                spawn_args+=("$1")
                shift
                ;;
            *)
                project_dir="$1"
                spawn_args+=("$1")
                shift
                ;;
        esac
    done

    # Generate worker name if not provided
    if [[ -z "$worker_name" ]]; then
        worker_name="hal9000-worker-$(date +%s)"
        spawn_args=(-n "$worker_name" "${spawn_args[@]}")
    fi

    local window_name
    window_name=$(get_window_name "$worker_name")

    # Spawn the worker in detached mode first
    log_info "Spawning worker: $worker_name"
    "${SCRIPT_DIR}/spawn-worker.sh" -d "${spawn_args[@]}" >/dev/null

    # Give it a moment to start
    sleep 1

    # Verify worker is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
        log_error "Worker failed to start: $worker_name"
        return 1
    fi

    # Create tmux window with docker exec
    ensure_session
    create_window "$window_name" "docker exec -it $worker_name bash"

    log_success "Worker ready: $worker_name"
    log_info "tmux window: $window_name"

    # If we're in tmux, switch to the new window
    if [[ -n "${TMUX:-}" ]]; then
        tmux -L "$TMUX_SOCKET" select-window -t "$SESSION_NAME:$window_name"
    else
        log_info "Attach with: tmux -L $TMUX_SOCKET attach -t $SESSION_NAME:$window_name"
    fi
}

attach_worker() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    # Verify worker exists
    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
        log_error "Worker not found: $worker_name"
        return 1
    fi

    local window_name
    window_name=$(get_window_name "$worker_name")

    ensure_session

    # Create window if it doesn't exist
    if ! window_exists "$window_name"; then
        create_window "$window_name" "docker exec -it $worker_name bash"
    fi

    # Switch to or attach to window
    if [[ -n "${TMUX:-}" ]]; then
        tmux -L "$TMUX_SOCKET" select-window -t "$SESSION_NAME:$window_name"
        log_success "Switched to: $window_name"
    else
        tmux -L "$TMUX_SOCKET" attach -t "$SESSION_NAME:$window_name"
    fi
}

cleanup_orphaned_windows() {
    log_info "Cleaning up orphaned windows..."

    local cleaned=0

    # Get list of running workers
    local running_workers
    running_workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null)

    # Get list of tmux windows
    tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" -F "#{window_name}" 2>/dev/null | while read -r window; do
        # Skip dashboard window
        [[ "$window" == "dashboard" ]] && continue

        # Check if corresponding worker exists
        local worker_name="hal9000-worker-${window}"
        if ! echo "$running_workers" | grep -q "^${worker_name}$"; then
            log_info "Removing orphaned window: $window"
            destroy_window "$window"
            ((cleaned++))
        fi
    done

    log_success "Cleanup complete: $cleaned windows removed"
}

sync_windows() {
    log_info "Syncing windows with running workers..."

    ensure_session

    # Get running workers
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$workers" ]]; then
        log_info "No workers running"
        return 0
    fi

    local created=0

    while IFS= read -r worker; do
        [[ -z "$worker" ]] && continue

        local window_name
        window_name=$(get_window_name "$worker")

        if ! window_exists "$window_name"; then
            log_info "Creating window for: $worker"
            create_window "$window_name" "docker exec -it $worker bash"
            ((created++))
        fi
    done <<< "$workers"

    log_success "Sync complete: $created windows created"
}

stop_worker_with_window() {
    local worker_name="$1"

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        return 1
    fi

    local window_name
    window_name=$(get_window_name "$worker_name")

    # Stop the container
    log_info "Stopping worker: $worker_name"
    docker stop "$worker_name" >/dev/null 2>&1 || true

    # Remove the window
    destroy_window "$window_name"

    # Clean up session metadata
    rm -f "${HAL9000_HOME:-/root/.hal9000}/sessions/${worker_name}.json" 2>/dev/null || true

    log_success "Worker stopped: $worker_name"
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat <<EOF
tmux-integrated Worker Management

Usage: tmux-worker.sh <command> [options]

Commands:
  spawn [options]       Spawn worker in new tmux window
  attach <name>         Attach to existing worker
  stop <name>           Stop worker and close window
  cleanup               Remove orphaned windows
  sync                  Create windows for all running workers
  help                  Show this help

Spawn Options:
  -n, --name NAME       Worker name
  [project_dir]         Project directory to mount

Examples:
  tmux-worker.sh spawn                          # Quick spawn
  tmux-worker.sh spawn -n my-worker /path/to/project
  tmux-worker.sh attach hal9000-worker-1234567890
  tmux-worker.sh stop my-worker
  tmux-worker.sh cleanup

Environment:
  TMUX_SOCKET     tmux socket name (default: hal9000)
  SESSION_NAME    tmux session name (default: hal9000)
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        spawn)
            spawn_with_window "$@"
            ;;
        attach)
            attach_worker "$@"
            ;;
        stop)
            stop_worker_with_window "$@"
            ;;
        cleanup)
            cleanup_orphaned_windows
            ;;
        sync)
            sync_windows
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

main "$@"
