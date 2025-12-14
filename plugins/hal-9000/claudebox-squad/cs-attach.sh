#!/usr/bin/env bash
# cs-attach.sh - Attach to a ClaudeBox Squad session
#
# Usage: ./cs-attach.sh <session-name>

set -Eeuo pipefail
IFS=$'\n\t'

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

if [[ $# -eq 0 ]]; then
    printf "${RED}✗${NC} Usage: %s <session-name>\n" "$0" >&2
    printf "\n"
    printf "Available sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^squad-" | cut -d':' -f1 || printf "  ${CYAN}(none)${NC}\n"
    exit 1
fi

session_name="$1"

# Check if tmux session exists
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    printf "${RED}✗${NC} Session not found: %s\n" "$session_name" >&2
    printf "\n"
    printf "Available sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^squad-" | cut -d':' -f1 || printf "  ${CYAN}(none)${NC}\n"
    exit 1
fi

printf "${GREEN}✓${NC} Attaching to session: %s\n" "$session_name"
printf "${CYAN}ℹ${NC} Press Ctrl+B then D to detach\n\n"

sleep 1

# Attach to session
tmux attach-session -t "$session_name"
