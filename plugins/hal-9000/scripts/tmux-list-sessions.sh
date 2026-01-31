#!/usr/bin/env bash
# tmux-list-sessions.sh - List available worker TMUX sessions
#
# Usage:
#   tmux-list-sessions.sh [options]
#
# Examples:
#   tmux-list-sessions.sh
#   tmux-list-sessions.sh -v
#   tmux-list-sessions.sh --detailed

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[tmux-list]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[tmux-list]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[tmux-list]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[tmux-list]${NC} ERROR: %s\n" "$1" >&2; }

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
VERBOSE=false
DETAILED=false

show_help() {
    cat <<EOF
List available worker TMUX sessions

Usage: tmux-list-sessions.sh [options]

Options:
  -v, --verbose         Show more details (status, windows)
  -d, --detailed        Very detailed output (includes pane info)
  -j, --json            Output as JSON
  -h, --help            Show this help

Examples:
  tmux-list-sessions.sh
  tmux-list-sessions.sh -v
  tmux-list-sessions.sh --detailed
  tmux-list-sessions.sh --json | jq

Environment:
  TMUX_SOCKET_DIR       Socket directory (default: /data/tmux-sockets)
EOF
}

list_sessions_simple() {
    echo "TMUX Sessions:"

    local found=0
    if [[ ! -d "$TMUX_SOCKET_DIR" ]]; then
        log_warn "Socket directory not found: $TMUX_SOCKET_DIR"
        return 0
    fi

    for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
        [[ ! -e "$socket" ]] && continue
        ((found++))

        local socket_name
        socket_name=$(basename "$socket" .sock)
        local worker_id="${socket_name#worker-}"

        # Check if container is running
        local running="❌"
        if docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
            running="✓"
        fi

        printf "  ${BLUE}%s${NC} (socket: %s) [%s]\n" "$worker_id" "$socket" "$running"
    done

    # Also list parent TMUX if it exists
    local parent_socket="$TMUX_SOCKET_DIR/parent.sock"
    if [[ -e "$parent_socket" ]]; then
        printf "  ${CYAN}%s${NC} (coordinator) [socket: %s]\n" "parent" "$parent_socket"
    fi

    if [[ $found -eq 0 ]]; then
        echo "  (no worker sessions)"
    else
        echo
        log_success "Total: $found worker session(s)"
    fi
}

list_sessions_verbose() {
    echo "TMUX Sessions (detailed):"
    echo

    local found=0
    if [[ ! -d "$TMUX_SOCKET_DIR" ]]; then
        log_warn "Socket directory not found: $TMUX_SOCKET_DIR"
        return 0
    fi

    for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
        [[ ! -e "$socket" ]] && continue
        ((found++))

        local socket_name
        socket_name=$(basename "$socket" .sock)
        local worker_id="${socket_name#worker-}"

        echo "Worker: ${BLUE}${worker_id}${NC}"
        echo "  Socket: $socket"

        # Check container status
        if docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
            echo "  ${GREEN}Status: Running${NC}"
            local container_id
            container_id=$(docker ps --filter "name=^${worker_id}$" --format "{{.ID}}" 2>/dev/null)
            local uptime
            uptime=$(docker inspect "$container_id" --format='{{.State.StartedAt}}' 2>/dev/null || echo "unknown")
            echo "  Uptime: $uptime"
        else
            echo "  ${RED}Status: Stopped${NC}"
        fi

        # List windows if TMUX is accessible
        if tmux -S "$socket" list-sessions >/dev/null 2>&1; then
            echo "  Windows:"
            tmux -S "$socket" list-windows -t "worker-${worker_id}" -F "    #{window_index}: #{window_name} (#{window_panes} panes)" 2>/dev/null || true
        fi

        echo
    done

    if [[ $found -eq 0 ]]; then
        echo "  (no worker sessions)"
    else
        log_success "Total: $found worker session(s)"
    fi
}

list_sessions_json() {
    local sessions='{"workers":[],"parent":null}'
    local workers='[]'

    if [[ ! -d "$TMUX_SOCKET_DIR" ]]; then
        echo "$sessions"
        return 0
    fi

    local first=true
    for socket in "$TMUX_SOCKET_DIR"/worker-*.sock; do
        [[ ! -e "$socket" ]] && continue

        local socket_name
        socket_name=$(basename "$socket" .sock)
        local worker_id="${socket_name#worker-}"

        # Check container status
        local status="stopped"
        local container_id=""
        if docker ps --format '{{.Names}}' | grep -q "^${worker_id}$"; then
            status="running"
            container_id=$(docker ps --filter "name=^${worker_id}$" --format "{{.ID}}" 2>/dev/null)
        fi

        # Count windows
        local window_count=0
        if tmux -S "$socket" list-sessions >/dev/null 2>&1; then
            window_count=$(tmux -S "$socket" list-windows -t "worker-${worker_id}" 2>/dev/null | wc -l)
        fi

        if [[ "$first" == "false" ]]; then
            workers="$workers,"
        fi
        first=false

        workers="$workers{\"id\":\"$worker_id\",\"status\":\"$status\",\"socket\":\"$socket\",\"container_id\":\"$container_id\",\"windows\":$window_count}"
    done

    workers="$workers]"
    sessions=$(echo "$sessions" | sed "s/\"workers\":\[\]/\"workers\":[$workers/")

    # Add parent if exists
    local parent_socket="$TMUX_SOCKET_DIR/parent.sock"
    if [[ -e "$parent_socket" ]]; then
        sessions=$(echo "$sessions" | sed "s/\"parent\":null/\"parent\":{\"socket\":\"$parent_socket\"}/")
    fi

    echo "$sessions"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -j|--json)
                list_sessions_json
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ "$DETAILED" == "true" ]]; then
        list_sessions_verbose
    elif [[ "$VERBOSE" == "true" ]]; then
        list_sessions_verbose
    else
        list_sessions_simple
    fi
}

main "$@"
