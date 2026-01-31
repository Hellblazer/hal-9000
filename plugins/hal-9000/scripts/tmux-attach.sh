#!/usr/bin/env bash
# tmux-attach.sh - Attach interactively to worker TMUX session
#
# Usage:
#   tmux-attach.sh <worker-id> [window]
#
# Examples:
#   tmux-attach.sh abc123
#   tmux-attach.sh my-worker-1
#   tmux-attach.sh worker-123 shell

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[tmux-attach]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[tmux-attach]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[tmux-attach]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[tmux-attach]${NC} ERROR: %s\n" "$1" >&2; }

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"

show_help() {
    cat <<EOF
Attach to worker TMUX session

Usage: tmux-attach.sh [options] <worker-id> [window]

Options:
  -l, --list-windows    List available windows before attaching
  -h, --help            Show this help

Windows:
  0 or claude          Claude CLI window (default)
  1 or shell           Shell/debug window

Examples:
  tmux-attach.sh worker-abc
  tmux-attach.sh my-worker claude
  tmux-attach.sh worker-123 shell

Environment:
  TMUX_SOCKET_DIR       Socket directory (default: /data/tmux-sockets)
EOF
}

list_windows() {
    local worker_id="$1"
    local tmux_socket="$2"

    echo "Available windows in $worker_id:"
    tmux -S "$tmux_socket" list-windows -t "worker-${worker_id}" -F "  #{window_index}: #{window_name}" || true
}

main() {
    if [[ $# -lt 1 ]]; then
        log_error "Missing worker ID"
        show_help
        exit 1
    fi

    local worker_id="$1"
    local window="${2:-0}"
    local list_windows_first=false

    # Parse first argument for flags
    if [[ "$worker_id" == "-h" ]] || [[ "$worker_id" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Shift past first argument and parse remaining
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list-windows)
                list_windows_first=true
                shift
                ;;
            *)
                window="$1"
                shift
                ;;
        esac
    done

    # Normalize worker ID
    if [[ ! "$worker_id" =~ ^hal9000-worker- ]]; then
        if [[ ! "$worker_id" =~ ^worker- ]]; then
            worker_id="hal9000-worker-${worker_id}"
        fi
    fi

    local tmux_socket="$TMUX_SOCKET_DIR/${worker_id}.sock"

    # Verify socket exists
    if [[ ! -e "$tmux_socket" ]]; then
        log_error "Worker not found: $worker_id"
        log_error "TMUX socket missing: $tmux_socket"
        exit 1
    fi

    # Verify worker container is still running
    local container_name="${worker_id#worker-}"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warn "Worker container not running: $container_name (but socket exists)"
    fi

    # List windows if requested
    if [[ "$list_windows_first" == "true" ]]; then
        list_windows "$worker_id" "$tmux_socket"
        echo
    fi

    # Normalize window reference
    case "$window" in
        claude)
            window="0"
            ;;
        shell)
            window="1"
            ;;
    esac

    log_info "Attaching to: $worker_id (window $window)"
    log_info "Type: Ctrl+B D to detach and keep session running"

    # Attach to TMUX session
    tmux -S "$tmux_socket" attach-session -t "worker-${worker_id}:${window}"
}

main "$@"
