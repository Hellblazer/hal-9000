#!/usr/bin/env bash
# hal9000-broadcast - Send command to ALL hal9000 sessions
#
# Usage: hal9000-broadcast "command"

set -Eeuo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

if [[ $# -lt 1 ]]; then
    printf "${RED}Usage: hal9000-broadcast \"command\"${NC}\n" >&2
    exit 1
fi

command="$*"

# Get all hal9000 sessions
sessions=$(tmux list-sessions 2>/dev/null | grep "^hal9000-" | cut -d':' -f1 || true)

if [[ -z "$sessions" ]]; then
    printf "${YELLOW}No active hal9000 sessions${NC}\n"
    exit 0
fi

printf "${CYAN}Broadcasting:${NC} $command\n\n"

count=0
while IFS= read -r session_name; do
    [[ -z "$session_name" ]] && continue
    printf "  → $session_name"
    tmux send-keys -t "$session_name" "$command" Enter
    printf " ${GREEN}✓${NC}\n"
    count=$((count + 1))
done <<< "$sessions"

printf "\n${GREEN}✓ Command sent to $count session(s)${NC}\n"
