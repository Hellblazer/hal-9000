#!/usr/bin/env bash
# hal9000-attach - Attach to a hal9000 session
#
# Usage: hal9000-attach <session-name>

set -Eeuo pipefail

readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

if [[ $# -lt 1 ]]; then
    printf "${RED}Usage: hal9000-attach <session-name>${NC}\n" >&2
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
    printf "\nAvailable sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^hal9000-" | cut -d':' -f1 || printf "  (none)\n"
    exit 1
fi

printf "${CYAN}Attaching to $session_name... (Ctrl+b d to detach)${NC}\n"
tmux attach-session -t "$session_name"
