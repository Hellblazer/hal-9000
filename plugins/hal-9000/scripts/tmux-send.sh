#!/usr/bin/env bash
# tmux-send.sh - Send commands to worker TMUX sessions
#
# Usage:
#   tmux-send.sh <worker-id> <command>
#
# Examples:
#   tmux-send.sh abc123 "bd ready"
#   tmux-send.sh my-worker-1 "pwd"
#   tmux-send.sh worker-123 "echo hello && sleep 1"

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[tmux-send]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[tmux-send]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[tmux-send]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[tmux-send]${NC} ERROR: %s\n" "$1" >&2; }

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
CAPTURE_OUTPUT="${CAPTURE_OUTPUT:-false}"

show_help() {
    cat <<EOF
Send command to worker TMUX session

Usage: tmux-send.sh [options] <worker-id> <command...>

Options:
  -c, --capture         Capture and display output after sending
  -h, --help            Show this help

Examples:
  tmux-send.sh worker-abc "bd ready"
  tmux-send.sh worker-abc "pwd" -c
  tmux-send.sh my-worker "echo 'Hello from TMUX'"

Environment:
  TMUX_SOCKET_DIR       Socket directory (default: /data/tmux-sockets)
  CAPTURE_OUTPUT        Auto-capture output (default: false)
EOF
}

main() {
    if [[ $# -lt 2 ]]; then
        log_error "Missing arguments"
        show_help
        exit 1
    fi

    # Parse options
    local worker_id=""
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--capture)
                CAPTURE_OUTPUT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$worker_id" ]]; then
                    worker_id="$1"
                else
                    command="$command $1"
                fi
                shift
                ;;
        esac
    done

    # Clean up command
    command="${command#${command%%[![:space:]]*}}"

    if [[ -z "$worker_id" ]] || [[ -z "$command" ]]; then
        log_error "Worker ID and command required"
        show_help
        exit 1
    fi

    # Normalize worker ID (add prefix if not present)
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

    log_info "Sending command to: $worker_id"
    log_info "Command: $command"

    # Send command to Claude window (window 0)
    tmux -S "$tmux_socket" send-keys -t "worker-${worker_id}:0" "$command" Enter

    if [[ "$CAPTURE_OUTPUT" == "true" ]]; then
        log_info "Capturing output..."
        sleep 0.5

        # Capture and display output
        tmux -S "$tmux_socket" capture-pane -t "worker-${worker_id}:0" -p
        log_success "Output captured"
    else
        log_success "Command sent (use -c/--capture to see output)"
    fi
}

main "$@"
