#!/usr/bin/env bash
# attach-worker.sh - Attach to a HAL-9000 worker via tmux
#
# Creates a new tmux window for the worker or attaches to existing one.
#
# Usage:
#   attach-worker.sh <worker_name>     # Attach to worker in new tmux window
#   attach-worker.sh -l                # List available workers
#   attach-worker.sh -s                # Select worker interactively
#
# The script:
# - Creates a new tmux window named after the worker
# - Runs docker exec to attach to the worker
# - Reuses existing window if already open for that worker

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[attach]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[attach]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[attach]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[attach]${NC} %s\n" "$1" >&2; }

TMUX_SOCKET="${TMUX_SOCKET:-hal9000}"
SESSION_NAME="${SESSION_NAME:-hal9000}"

# ============================================================================
# FUNCTIONS
# ============================================================================

list_workers() {
    echo "Available workers:"
    docker ps \
        --filter "name=hal9000-worker" \
        --format "  {{.Names}} ({{.Status}})"

    if [[ $(docker ps --filter "name=hal9000-worker" -q | wc -l) -eq 0 ]]; then
        echo "  (no workers running)"
    fi
}

select_worker() {
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}")

    if [[ -z "$workers" ]]; then
        log_error "No workers running"
        exit 1
    fi

    echo "Select a worker:"
    local i=1
    local worker_array=()
    while IFS= read -r worker; do
        echo "  $i) $worker"
        worker_array+=("$worker")
        ((i++))
    done <<< "$workers"

    read -p "Enter number: " selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#worker_array[@]} ]]; then
        echo "${worker_array[$((selection-1))]}"
    else
        log_error "Invalid selection"
        exit 1
    fi
}

get_window_name() {
    local worker_name="$1"
    # Shorten worker name for tmux window (remove hal9000-worker- prefix)
    echo "${worker_name#hal9000-worker-}"
}

window_exists() {
    local window_name="$1"
    tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" 2>/dev/null \
        | grep -q ":${window_name}\*\?\s"
}

create_worker_window() {
    local worker_name="$1"
    local window_name
    window_name=$(get_window_name "$worker_name")

    # Check if tmux session exists
    if ! tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_info "Creating tmux session: $SESSION_NAME"
        tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "$window_name"
        tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:$window_name" \
            "docker exec -it $worker_name bash" Enter
        return 0
    fi

    # Check if window already exists for this worker
    if window_exists "$window_name"; then
        log_info "Window already exists for $worker_name"
        tmux -L "$TMUX_SOCKET" select-window -t "$SESSION_NAME:$window_name"
        return 0
    fi

    # Create new window
    log_info "Creating window for: $worker_name"
    tmux -L "$TMUX_SOCKET" new-window -t "$SESSION_NAME" -n "$window_name"
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:$window_name" \
        "docker exec -it $worker_name bash" Enter
}

attach_to_worker() {
    local worker_name="$1"

    # Verify worker exists
    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
        log_error "Worker not found: $worker_name"
        log_info "Use 'attach-worker.sh -l' to list available workers"
        exit 1
    fi

    local window_name
    window_name=$(get_window_name "$worker_name")

    # Create window if needed
    create_worker_window "$worker_name"

    # Check if we're already in tmux
    if [[ -n "${TMUX:-}" ]]; then
        # Already in tmux, switch to window
        tmux -L "$TMUX_SOCKET" select-window -t "$SESSION_NAME:$window_name"
        log_success "Switched to worker: $worker_name"
    else
        # Not in tmux, attach to session
        log_success "Attaching to worker: $worker_name"
        tmux -L "$TMUX_SOCKET" attach -t "$SESSION_NAME:$window_name"
    fi
}

direct_attach() {
    local worker_name="$1"

    # Verify worker exists
    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_name}$"; then
        log_error "Worker not found: $worker_name"
        exit 1
    fi

    log_info "Direct attach to: $worker_name"
    docker exec -it "$worker_name" bash
}

show_help() {
    cat <<EOF
Attach to HAL-9000 Worker

Usage: attach-worker.sh [options] [worker_name]

Options:
  -l, --list        List available workers
  -s, --select      Interactive worker selection
  -d, --direct      Direct docker exec (no tmux)
  -h, --help        Show this help

Examples:
  attach-worker.sh hal9000-worker-1234567890
  attach-worker.sh -l
  attach-worker.sh -s
  attach-worker.sh -d hal9000-worker-1234567890

tmux Integration:
  When attaching via tmux, each worker gets its own window.
  Use Ctrl-B + n/p to switch between worker windows.
  Use Ctrl-B + 1-9 to jump to specific window numbers.

Environment:
  TMUX_SOCKET     tmux socket name (default: hal9000)
  SESSION_NAME    tmux session name (default: hal9000)
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local direct=false
    local worker_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)
                list_workers
                exit 0
                ;;
            -s|--select)
                worker_name=$(select_worker)
                shift
                ;;
            -d|--direct)
                direct=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                worker_name="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$worker_name" ]]; then
        log_error "Worker name required"
        echo
        show_help
        exit 1
    fi

    if [[ "$direct" == "true" ]]; then
        direct_attach "$worker_name"
    else
        attach_to_worker "$worker_name"
    fi
}

main "$@"
