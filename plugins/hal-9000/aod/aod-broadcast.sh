#!/usr/bin/env bash
# aod-broadcast.sh - Send command to all aod sessions
#
# Usage: aod-broadcast <command>

set -Eeuo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

if [[ $# -eq 0 ]]; then
    printf "${RED}✗${NC} Usage: %s <command>\n" "$(basename "$0")" >&2
    printf "\n"
    printf "Examples:\n"
    printf "  %s \"git fetch\"\n" "$(basename "$0")"
    printf "  %s \"./mvnw clean\"\n" "$(basename "$0")"
    printf "\n"
    exit 1
fi

command="$*"

# Check if tmux-cli is available
if ! command -v tmux-cli &> /dev/null; then
    printf "${RED}✗${NC} tmux-cli not found. Install claude-code-tools:\n" >&2
    printf "  uv tool install claude-code-tools\n" >&2
    exit 1
fi

# Get all aod sessions (portable - no mapfile for macOS bash 3.2)
sessions=()
while IFS= read -r session; do
    [[ -n "$session" ]] && sessions+=("$session")
done < <(tmux list-sessions 2>/dev/null | grep "^aod-" | cut -d':' -f1 || true)

if [[ ${#sessions[@]} -eq 0 ]]; then
    printf "${YELLOW}⚠${NC} No aod sessions running\n"
    printf "\n"
    printf "Start sessions with:\n"
    printf "  aod aod.conf\n"
    exit 0
fi

printf "${CYAN}Broadcasting to %d session(s):${NC} %s\n" "${#sessions[@]}" "$command"
printf "\n"

# Send to each session
for session in "${sessions[@]}"; do
    # Get pane ID
    pane_id=$(tmux list-panes -t "$session" -F '#{pane_id}' | head -1)

    if [[ -n "$pane_id" ]]; then
        printf "  ${GREEN}→${NC} %s\n" "$session"
        tmux-cli send "$command" --pane="$pane_id"
    else
        printf "  ${RED}✗${NC} %s (no pane found)\n" "$session"
    fi
done

printf "\n${GREEN}✓${NC} Broadcast complete\n"
