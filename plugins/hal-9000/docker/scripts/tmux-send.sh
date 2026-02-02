#!/bin/bash
# Send a command to a tmux session
# Usage: tmux-send.sh <session> <command>

set -euo pipefail

SESSION="${1:-}"
COMMAND="${2:-}"

if [[ -z "$SESSION" ]] || [[ -z "$COMMAND" ]]; then
    echo "Usage: tmux-send.sh <session> <command>" >&2
    exit 1
fi

# Find tmux socket
TMUX_SOCKET=$(ls /data/tmux-sockets/*.sock 2>/dev/null | head -1)
if [[ -z "$TMUX_SOCKET" ]]; then
    echo "No tmux socket found" >&2
    exit 1
fi

tmux -S "$TMUX_SOCKET" send-keys -t "$SESSION" "$COMMAND" Enter
