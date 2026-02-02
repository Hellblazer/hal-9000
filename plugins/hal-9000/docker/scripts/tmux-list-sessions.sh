#!/bin/bash
# List tmux sessions
# Usage: tmux-list-sessions.sh

set -euo pipefail

# Find tmux socket
TMUX_SOCKET=$(ls /data/tmux-sockets/*.sock 2>/dev/null | head -1)
if [[ -z "$TMUX_SOCKET" ]]; then
    echo "No tmux socket found" >&2
    exit 1
fi

tmux -S "$TMUX_SOCKET" list-sessions
