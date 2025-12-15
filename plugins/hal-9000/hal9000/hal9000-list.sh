#!/usr/bin/env bash
# hal9000-list - List active hal9000 sessions
#
# Usage: hal9000-list

set -Eeuo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly HAL9000_DIR="$HOME/.hal9000"

# Get tmux sessions
sessions=$(tmux list-sessions 2>/dev/null | grep "^hal9000-" || true)

if [[ -z "$sessions" ]]; then
    printf "${YELLOW}No active hal9000 sessions${NC}\n"
    exit 0
fi

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Active hal9000 Sessions${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

printf "%-20s %-12s %-10s %s\n" "SESSION" "PROFILE" "SLOT" "DIRECTORY"
printf "%-20s %-12s %-10s %s\n" "───────" "───────" "────" "─────────"

while IFS= read -r line; do
    session_name=$(echo "$line" | cut -d':' -f1)

    # Try to read session info
    session_file="$HAL9000_DIR/sessions/${session_name}.json"
    if [[ -f "$session_file" ]] && command -v python3 >/dev/null 2>&1; then
        info=$(python3 -c "
import json
with open('$session_file') as f:
    d = json.load(f)
    print(d.get('profile', 'default'))
    print(d.get('slot', '?'))
    print(d.get('directory', '?'))
" 2>/dev/null || echo -e "default\n?\n?")
        profile=$(echo "$info" | sed -n '1p')
        slot=$(echo "$info" | sed -n '2p')
        directory=$(echo "$info" | sed -n '3p')
    else
        profile="default"
        slot="?"
        directory="?"
    fi

    printf "%-20s %-12s %-10s %s\n" "$session_name" "$profile" "$slot" "$directory"
done <<< "$sessions"

printf "\n${CYAN}Commands:${NC}\n"
printf "  hal9000-attach <session>  - Attach to session\n"
printf "  hal9000-send <session> CMD - Send command\n"
printf "  hal9000-broadcast CMD     - Send to all\n"
printf "  hal9000-cleanup           - Stop all sessions\n"
