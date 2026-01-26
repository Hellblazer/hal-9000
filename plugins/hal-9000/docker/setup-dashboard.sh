#!/usr/bin/env bash
# setup-dashboard.sh - Set up HAL-9000 tmux dashboard
#
# Creates a multi-pane dashboard for monitoring HAL-9000 workers.
#
# Layout:
# +---------------------------+---------------------------+
# |                           |      Worker List          |
# |     Status Overview       |                           |
# |                           +---------------------------+
# |                           |      Docker Stats         |
# +---------------------------+---------------------------+
# |                   Command Prompt                      |
# +-------------------------------------------------------+

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[dashboard]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[dashboard]${NC} %s\n" "$1"; }

TMUX_SOCKET="${TMUX_SOCKET:-hal9000}"
SESSION_NAME="${SESSION_NAME:-hal9000-dashboard}"

setup_dashboard() {
    log_info "Setting up HAL-9000 dashboard..."

    # Kill existing session if present
    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true

    # Create new session with first window
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "dashboard"

    # Load custom config if available
    if [[ -f /scripts/tmux-dashboard.conf ]]; then
        tmux -L "$TMUX_SOCKET" source-file /scripts/tmux-dashboard.conf
    fi

    # Split into panes
    # First, split horizontally (left/right)
    tmux -L "$TMUX_SOCKET" split-window -h -t "$SESSION_NAME:dashboard"

    # Split right side vertically (top-right / bottom-right)
    tmux -L "$TMUX_SOCKET" split-window -v -t "$SESSION_NAME:dashboard.1"

    # Split bottom horizontally for command prompt
    tmux -L "$TMUX_SOCKET" split-window -v -t "$SESSION_NAME:dashboard.0"

    # Set up each pane
    # Pane 0 (top-left): Status overview
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:dashboard.0" \
        'watch -n 5 "/scripts/coordinator.sh status 2>/dev/null || echo No coordinator"' Enter

    # Pane 1 (bottom-left): Command prompt
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:dashboard.1" \
        'echo "HAL-9000 Command Prompt"; echo "Type commands or use prefix+w to spawn worker"' Enter

    # Pane 2 (top-right): Worker list
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:dashboard.2" \
        'watch -n 2 "docker ps --filter name=hal9000-worker --format \"table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\" 2>/dev/null || echo No workers"' Enter

    # Pane 3 (bottom-right): Docker stats
    tmux -L "$TMUX_SOCKET" send-keys -t "$SESSION_NAME:dashboard.3" \
        'docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker ps --filter name=hal9000 -q 2>/dev/null) 2>/dev/null || watch -n 5 "echo Waiting for containers..."' Enter

    # Resize panes for better layout
    tmux -L "$TMUX_SOCKET" resize-pane -t "$SESSION_NAME:dashboard.0" -y 15
    tmux -L "$TMUX_SOCKET" resize-pane -t "$SESSION_NAME:dashboard.1" -y 5

    # Select command prompt pane
    tmux -L "$TMUX_SOCKET" select-pane -t "$SESSION_NAME:dashboard.1"

    log_success "Dashboard ready!"
    log_info "Attach with: tmux -L $TMUX_SOCKET attach -t $SESSION_NAME"
}

attach_dashboard() {
    if tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux -L "$TMUX_SOCKET" attach -t "$SESSION_NAME"
    else
        log_info "Dashboard not found, creating..."
        setup_dashboard
        tmux -L "$TMUX_SOCKET" attach -t "$SESSION_NAME"
    fi
}

show_help() {
    cat <<EOF
HAL-9000 Dashboard Setup

Usage: setup-dashboard.sh [command]

Commands:
  setup     Create the dashboard (default)
  attach    Attach to existing dashboard (or create if missing)
  kill      Kill the dashboard session
  help      Show this help

Environment:
  TMUX_SOCKET    tmux socket name (default: hal9000)
  SESSION_NAME   tmux session name (default: hal9000-dashboard)
EOF
}

main() {
    case "${1:-setup}" in
        setup)
            setup_dashboard
            ;;
        attach)
            attach_dashboard
            ;;
        kill)
            tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
            log_success "Dashboard killed"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_info "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
