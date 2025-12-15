#!/usr/bin/env bash
# hal9000-stop - Stop a specific hal9000 session
#
# Usage: hal9000-stop <session-name>

set -Eeuo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly HAL9000_DIR="$HOME/.hal9000"

if [[ $# -lt 1 ]]; then
    printf "${RED}Usage: hal9000-stop <session-name>${NC}\n" >&2
    printf "\nAvailable sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^hal9000-" | cut -d':' -f1 || printf "  (none)\n"
    exit 1
fi

session_name="$1"

# Add hal9000- prefix if not present
if [[ ! "$session_name" =~ ^hal9000- ]]; then
    session_name="hal9000-$session_name"
fi

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    printf "${RED}Session not found: $session_name${NC}\n" >&2
    exit 1
fi

printf "${CYAN}Stopping $session_name...${NC}\n"

# Kill tmux session (container will stop due to -it --rm)
tmux kill-session -t "$session_name" 2>/dev/null || true

# Clean up session file
rm -f "$HAL9000_DIR/sessions/${session_name}.json" 2>/dev/null || true

# Clean up claude directory
rm -rf "$HAL9000_DIR/claude/${session_name}" 2>/dev/null || true

printf "${GREEN}✓ Session stopped: $session_name${NC}\n"
