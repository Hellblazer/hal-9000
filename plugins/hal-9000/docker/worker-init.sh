#!/bin/bash
# HAL-9000 Worker Init Script
# Runs as root to fix volume permissions, then execs entrypoint as claude user

set -e

# Fix tmux-sockets permissions if needed
TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
if [[ -d "$TMUX_SOCKET_DIR" ]]; then
    # Set ownership to claude:claude if not already
    if [[ "$(stat -c '%U' "$TMUX_SOCKET_DIR" 2>/dev/null || stat -f '%Su' "$TMUX_SOCKET_DIR" 2>/dev/null)" != "claude" ]]; then
        chown claude:claude "$TMUX_SOCKET_DIR" 2>/dev/null || true
        chmod 770 "$TMUX_SOCKET_DIR" 2>/dev/null || true
    fi
fi

# Fix memory-bank permissions if needed
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/data/memory-bank}"
if [[ -d "$MEMORY_BANK_ROOT" ]]; then
    if [[ "$(stat -c '%U' "$MEMORY_BANK_ROOT" 2>/dev/null || stat -f '%Su' "$MEMORY_BANK_ROOT" 2>/dev/null)" != "claude" ]]; then
        chown -R claude:claude "$MEMORY_BANK_ROOT" 2>/dev/null || true
    fi
fi

# Export key environment variables for the entrypoint
# These are passed by spawn-worker.sh but need to survive the su switch
export CHROMADB_HOST="${CHROMADB_HOST:-localhost}"
export CHROMADB_PORT="${CHROMADB_PORT:-8000}"
export PARENT_IP="${PARENT_IP:-}"
export PARENT_HOSTNAME="${PARENT_HOSTNAME:-}"
export WORKER_NAME="${WORKER_NAME:-worker}"
export ANTHROPIC_API_KEY_FILE="${ANTHROPIC_API_KEY_FILE:-}"

# Run the actual entrypoint as claude user, preserving environment
exec su -m -s /bin/bash claude -c "/scripts/worker-entrypoint.sh $*"
