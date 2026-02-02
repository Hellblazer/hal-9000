#!/bin/bash
# Attach to a tmux session
# Usage: tmux-attach.sh [session]

set -euo pipefail

SESSION="${1:-}"

# Find tmux socket
TMUX_SOCKET=$(ls /data/tmux-sockets/*.sock 2>/dev/null | head -1)
if [[ -z "$TMUX_SOCKET" ]]; then
    echo "No tmux socket found" >&2
    exit 1
fi

if [[ -n "$SESSION" ]]; then
    exec tmux -S "$TMUX_SOCKET" attach -t "$SESSION"
else
    exec tmux -S "$TMUX_SOCKET" attach
fi
