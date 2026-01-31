#!/usr/bin/env bash
# attach-worker.sh - Attach to a HAL-9000 worker via TMUX socket
#
# Attaches directly to worker's internal TMUX session via socket IPC.
#
# Usage:
#   attach-worker.sh <worker_name>     # Attach to worker's TMUX session
#   attach-worker.sh <worker_name> shell # Attach to shell window instead of Claude
#   attach-worker.sh -l                # List available workers
#   attach-worker.sh -s                # Select worker interactively
#   attach-worker.sh -d <worker_name>  # Direct docker exec (fallback)
#
# The script:
# - Discovers worker via TMUX socket in /data/tmux-sockets
# - Attaches directly to worker's internal TMUX session
# - Supports window selection (0=claude, 1=shell)
# - Falls back to docker exec if socket unavailable

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
log_error() { printf "${RED}[attach]${NC} ERROR: %s\n" "$1" >&2; }

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"

# ============================================================================
# FUNCTIONS
# ============================================================================

list_workers() {
    echo "Available workers:"

    if [[ ! -d "$TMUX_SOCKET_DIR" ]]; then
        echo "  (socket directory not found)"
        return 0
    fi

    local found=0
    for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
        [[ ! -e "$socket" ]] && continue
        ((found++))

        local socket_name
        socket_name=$(basename "$socket" .sock)
        local worker_id="${socket_name#worker-}"

        # Check if container is running
        local status="❌ stopped"
        if docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
            status="✓ running"
        fi

        printf "  ${CYAN}%-40s${NC} [%s]\n" "$worker_id" "$status"
    done

    if [[ $found -eq 0 ]]; then
        echo "  (no worker sessions found)"
    fi
}

select_worker() {
    local workers=()

    if [[ ! -d "$TMUX_SOCKET_DIR" ]]; then
        log_error "Socket directory not found: $TMUX_SOCKET_DIR"
        exit 1
    fi

    # Find all worker sockets
    for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
        [[ ! -e "$socket" ]] && continue

        local socket_name
        socket_name=$(basename "$socket" .sock)
        local worker_id="${socket_name#worker-}"

        # Only include running containers
        if docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
            workers+=("$worker_id")
        fi
    done

    if [[ ${#workers[@]} -eq 0 ]]; then
        log_error "No worker sessions found"
        exit 1
    fi

    echo "Select a worker:"
    local i=1
    for worker in "${workers[@]}"; do
        echo "  $i) $worker"
        ((i++))
    done

    read -p "Enter number: " selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#workers[@]} ]]; then
        echo "${workers[$((selection-1))]}"
    else
        log_error "Invalid selection"
        exit 1
    fi
}

socket_exists() {
    local worker_id="$1"
    local socket="$TMUX_SOCKET_DIR/worker-${worker_id}.sock"
    [[ -e "$socket" ]]
}

verify_worker_container() {
    local worker_id="$1"

    if ! docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
        log_error "Container not running: $worker_id"
        return 1
    fi
}

attach_to_worker_socket() {
    local worker_id="$1"
    local window="${2:-0}"  # Default to Claude window (0)

    # Normalize worker ID
    if [[ ! "$worker_id" =~ ^hal9000-worker- ]]; then
        if [[ ! "$worker_id" =~ ^worker- ]]; then
            worker_id="hal9000-worker-${worker_id}"
        fi
    fi

    # Verify container exists
    if ! verify_worker_container "$worker_id"; then
        exit 1
    fi

    # Check socket
    if ! socket_exists "$worker_id"; then
        log_error "TMUX socket not found for worker: $worker_id"
        log_warn "Worker session may not have started yet"
        read -p "Retry? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sleep 2
            attach_to_worker_socket "$worker_id" "$window"
        else
            exit 1
        fi
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

    local socket="$TMUX_SOCKET_DIR/worker-${worker_id}.sock"
    local session="worker-${worker_id}"

    log_info "Attaching to: $worker_id (window $window)"
    log_info "Type: Ctrl+B D to detach"

    # Attach to worker's TMUX socket
    tmux -S "$socket" attach-session -t "$session:$window"
}

direct_attach() {
    local worker_id="$1"

    # Normalize worker ID
    if [[ ! "$worker_id" =~ ^hal9000-worker- ]]; then
        if [[ ! "$worker_id" =~ ^worker- ]]; then
            worker_id="hal9000-worker-${worker_id}"
        fi
    fi

    # Verify container exists
    if ! verify_worker_container "$worker_id"; then
        exit 1
    fi

    log_warn "Using docker exec (legacy fallback)"
    docker exec -it "$worker_id" bash
}

show_help() {
    cat <<EOF
Attach to HAL-9000 Worker

Usage: attach-worker.sh [options] [worker_name] [window]

Options:
  -l, --list        List available workers
  -s, --select      Interactive worker selection
  -d, --direct      Direct docker exec (fallback)
  -h, --help        Show this help

Windows:
  0 or claude       Claude CLI window (default)
  1 or shell        Shell/debug window

Examples:
  attach-worker.sh worker-abc
  attach-worker.sh hal9000-worker-1234567890
  attach-worker.sh worker-abc shell
  attach-worker.sh -l
  attach-worker.sh -s
  attach-worker.sh -d worker-abc

TMUX Commands (while attached):
  Ctrl+B D         Detach and keep session running
  Ctrl+B C         Create new window
  Ctrl+B N / P     Next/Previous window
  Ctrl+B ,         Rename current window

Socket-Based Architecture:
  Each worker has independent TMUX server via socket in $TMUX_SOCKET_DIR
  Attaches directly to worker's session (not via docker exec)
  Enables better isolation and control

Environment:
  TMUX_SOCKET_DIR   Socket directory (default: /data/tmux-sockets)
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local direct=false
    local worker_id=""
    local window=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)
                list_workers
                exit 0
                ;;
            -s|--select)
                worker_id=$(select_worker)
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
                if [[ -z "$worker_id" ]]; then
                    worker_id="$1"
                else
                    window="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$worker_id" ]]; then
        log_error "Worker name required"
        echo
        show_help
        exit 1
    fi

    if [[ "$direct" == "true" ]]; then
        direct_attach "$worker_id"
    else
        attach_to_worker_socket "$worker_id" "$window"
    fi
}

main "$@"
