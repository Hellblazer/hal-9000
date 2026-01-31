#!/usr/bin/env bash
# show-workers.sh - Display HAL-9000 worker status with TMUX socket tracking
#
# Shows active workers with:
# - Container status (running, memory, CPU)
# - TMUX socket health (✓ healthy, ⚠ stale, ○ missing)
# - Session metadata
# - Resource usage
# - Coordinator status
#
# Usage:
#   show-workers.sh              # Full status view
#   show-workers.sh -c           # Compact single-line view
#   show-workers.sh -w           # Watch mode (auto-refresh)
#   show-workers.sh -j           # JSON output

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

TMUX_SOCKET="${TMUX_SOCKET:-hal9000}"
SESSION_NAME="${SESSION_NAME:-hal9000}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# SOCKET-BASED ARCHITECTURE (NEW)
# ============================================================================

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"

worker_has_socket() {
    local worker_name="$1"
    local socket="$TMUX_SOCKET_DIR/worker-${worker_name}.sock"
    [[ -e "$socket" ]]
}

worker_socket_healthy() {
    local worker_name="$1"
    local socket="$TMUX_SOCKET_DIR/worker-${worker_name}.sock"

    if [[ ! -e "$socket" ]]; then
        return 1
    fi

    # Check if TMUX can access the socket
    tmux -S "$socket" list-sessions >/dev/null 2>&1
}

get_tmux_windows() {
    tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" 2>/dev/null \
        | awk -F: '{print $2}' | awk '{print $1}' || true
}

worker_has_window() {
    local worker_name="$1"
    local window_name="${worker_name#hal9000-worker-}"
    get_tmux_windows | grep -q "^${window_name}$"
}

get_worker_session() {
    local worker_name="$1"
    local session_file="${HAL9000_HOME:-/root/.hal9000}/sessions/${worker_name}.json"
    if [[ -f "$session_file" ]]; then
        cat "$session_file"
    fi
}

format_duration() {
    local seconds="$1"
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        echo "$((seconds / 60))m"
    elif [[ $seconds -lt 86400 ]]; then
        echo "$((seconds / 3600))h"
    else
        echo "$((seconds / 86400))d"
    fi
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

show_header() {
    echo
    printf "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}${CYAN}                    HAL-9000 Worker Status${NC}\n"
    printf "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
    echo
}

show_summary() {
    local worker_count
    worker_count=$(docker ps --filter "name=hal9000-worker" -q 2>/dev/null | wc -l | tr -d ' ')

    local parent_status="${RED}●${NC} stopped"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^hal9000-parent$"; then
        parent_status="${GREEN}●${NC} running"
    fi

    local tmux_status="${RED}●${NC} no session"
    if tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        local window_count
        window_count=$(tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" 2>/dev/null | wc -l)
        tmux_status="${GREEN}●${NC} ${window_count} windows"
    fi

    printf "  ${BOLD}Parent:${NC}  $parent_status    "
    printf "${BOLD}Workers:${NC} ${BLUE}$worker_count${NC}    "
    printf "${BOLD}tmux:${NC} $tmux_status\n"
    echo
}

show_workers_table() {
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$workers" ]]; then
        printf "  ${YELLOW}No active workers${NC}\n"
        echo
        printf "  Start a worker with: ${CYAN}spawn-worker.sh${NC}\n"
        return
    fi

    # Table header
    printf "${BOLD}  %-35s  %-8s  %-10s  %-8s  %-6s${NC}\n" \
        "WORKER" "STATUS" "UPTIME" "MEMORY" "SOCKET"
    printf "  %-35s  %-8s  %-10s  %-8s  %-6s\n" \
        "───────────────────────────────────" "────────" "──────────" "────────" "──────"

    while IFS= read -r worker; do
        [[ -z "$worker" ]] && continue

        # Get container info
        local info
        info=$(docker inspect "$worker" 2>/dev/null \
            | jq -r '.[0] | "\(.State.Status)|\(.State.StartedAt)"' 2>/dev/null) || continue

        local status="${info%%|*}"
        local started="${info##*|}"

        # Calculate uptime
        local uptime="N/A"
        if [[ "$started" != "null" ]] && [[ -n "$started" ]]; then
            local start_epoch
            start_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started%%.*}" +%s 2>/dev/null || echo 0)
            local now_epoch
            now_epoch=$(date +%s)
            if [[ $start_epoch -gt 0 ]]; then
                uptime=$(format_duration $((now_epoch - start_epoch)))
            fi
        fi

        # Get memory usage
        local memory="N/A"
        memory=$(docker stats --no-stream --format "{{.MemUsage}}" "$worker" 2>/dev/null | cut -d'/' -f1 | tr -d ' ') || memory="N/A"

        # Check TMUX socket health (new socket-based architecture)
        local socket_indicator="${RED}○${NC}"
        if worker_has_socket "$worker"; then
            if worker_socket_healthy "$worker"; then
                socket_indicator="${GREEN}✓${NC}"
            else
                socket_indicator="${YELLOW}⚠${NC}"
            fi
        fi

        # Status color
        local status_display
        case "$status" in
            running)
                status_display="${GREEN}running${NC}"
                ;;
            exited)
                status_display="${RED}exited${NC}"
                ;;
            *)
                status_display="${YELLOW}${status}${NC}"
                ;;
        esac

        # Short worker name
        local short_name="${worker#hal9000-worker-}"
        if [[ ${#short_name} -gt 35 ]]; then
            short_name="${short_name:0:32}..."
        fi

        printf "  %-35s  %-17s  %-10s  %-8s  %s\n" \
            "$short_name" "$status_display" "$uptime" "$memory" "$socket_indicator"
    done <<< "$workers"
}

show_footer() {
    echo
    printf "${BOLD}  Quick Actions:${NC}\n"
    printf "    ${CYAN}attach-worker.sh <name>${NC}        - Attach to worker's TMUX session\n"
    printf "    ${CYAN}attach-worker.sh <name> shell${NC} - Attach to shell window\n"
    printf "    ${CYAN}coordinator.sh stop <name>${NC}    - Stop a worker\n"
    printf "    ${CYAN}spawn-worker.sh${NC}               - Create new worker\n"
    echo
    printf "  ${BOLD}Socket Indicators:${NC}\n"
    printf "    ${GREEN}✓${NC} = Socket healthy  ${YELLOW}⚠${NC} = Socket stale  ${RED}○${NC} = Socket missing\n"
    echo
    printf "  ${BOLD}TMUX Keys:${NC} ${MAGENTA}Ctrl-B d${NC}=detach  ${MAGENTA}Ctrl-B n/p${NC}=next/prev  ${MAGENTA}Ctrl-B ,${NC}=rename\n"
    echo
}

show_full_status() {
    show_header
    show_summary
    show_workers_table
    show_footer
}

show_compact() {
    local worker_count
    worker_count=$(docker ps --filter "name=hal9000-worker" -q 2>/dev/null | wc -l | tr -d ' ')

    local parent_status="○"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^hal9000-parent$"; then
        parent_status="●"
    fi

    local coordinator_status="○"
    if [[ -d "$TMUX_SOCKET_DIR" ]] && [[ -n "$(ls -A "$TMUX_SOCKET_DIR"/parent.sock 2>/dev/null)" ]]; then
        coordinator_status="●"
    fi

    printf "HAL-9000: parent=%s coordinator=%s workers=%d" "$parent_status" "$coordinator_status" "$worker_count"

    if [[ $worker_count -gt 0 ]]; then
        printf " ["
        docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null \
            | while IFS= read -r w; do
                # Add socket health indicator
                if worker_has_socket "$w"; then
                    if worker_socket_healthy "$w"; then
                        printf "${GREEN}✓${NC}%s " "${w#hal9000-worker-}"
                    else
                        printf "${YELLOW}⚠${NC}%s " "${w#hal9000-worker-}"
                    fi
                else
                    printf "${RED}○${NC}%s " "${w#hal9000-worker-}"
                fi
            done
        printf "\b]"
    fi
    echo
}

show_json() {
    local workers_json="[]"

    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null)

    if [[ -n "$workers" ]]; then
        workers_json=$(echo "$workers" | while IFS= read -r worker; do
            local has_socket=false
            local socket_healthy=false

            if worker_has_socket "$worker"; then
                has_socket=true
                if worker_socket_healthy "$worker"; then
                    socket_healthy=true
                fi
            fi

            local session_data="{}"
            local session_file="${HAL9000_HOME:-/root/.hal9000}/sessions/${worker}.json"
            if [[ -f "$session_file" ]]; then
                session_data=$(cat "$session_file")
            fi

            docker inspect "$worker" 2>/dev/null | jq --arg name "$worker" --arg socket "$has_socket" --arg healthy "$socket_healthy" --argjson session "$session_data" '
                .[0] | {
                    name: $name,
                    status: .State.Status,
                    started: .State.StartedAt,
                    image: .Config.Image,
                    tmux_socket: {
                        exists: ($socket == "true"),
                        healthy: ($healthy == "true")
                    },
                    session: $session
                }
            '
        done | jq -s '.')
    fi

    local parent_running=false
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^hal9000-parent$" && parent_running=true

    local coordinator_active=false
    if [[ -d "$TMUX_SOCKET_DIR" ]] && [[ -n "$(ls -A "$TMUX_SOCKET_DIR"/parent.sock 2>/dev/null)" ]]; then
        coordinator_active=true
    fi

    jq -n \
        --argjson workers "$workers_json" \
        --argjson parent "$parent_running" \
        --argjson coordinator "$coordinator_active" \
        --arg socket_dir "$TMUX_SOCKET_DIR" \
        '{
            parent_running: $parent,
            coordinator: {
                active: $coordinator,
                socket_dir: $socket_dir
            },
            worker_count: ($workers | length),
            workers: $workers
        }'
}

show_help() {
    cat <<EOF
Show HAL-9000 Worker Status (Socket-Based Architecture)

Usage: show-workers.sh [options]

Options:
  -c, --compact     Compact single-line output
  -w, --watch       Watch mode (refresh every 2 seconds)
  -j, --json        JSON output
  -h, --help        Show this help

Examples:
  show-workers.sh           # Full status display
  show-workers.sh -c        # Compact status line
  show-workers.sh -w        # Live updating view
  show-workers.sh -j | jq   # JSON for scripting

Socket Indicators:
  ✓  = TMUX socket exists and healthy
  ⚠  = TMUX socket exists but stale
  ○  = TMUX socket not found (session not ready)

Architecture:
  Each worker has independent TMUX server via socket in /data/tmux-sockets
  Coordinator monitors workers and maintains socket registry
  Socket health indicates worker session readiness

Environment:
  TMUX_SOCKET_DIR   Socket directory (default: /data/tmux-sockets)
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "${1:-}" in
        -c|--compact)
            show_compact
            ;;
        -w|--watch)
            watch -n 2 -c "$0"
            ;;
        -j|--json)
            show_json
            ;;
        -h|--help)
            show_help
            ;;
        "")
            show_full_status
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
