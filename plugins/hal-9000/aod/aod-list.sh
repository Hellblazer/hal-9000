#!/usr/bin/env bash
# aod-list.sh - List all active aod sessions

set -Eeuo pipefail
IFS=$'\n\t'

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Table width for formatting
readonly TABLE_WIDTH=70

printf "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}\n"
printf "${BLUE}║         aod - Active Sessions                              ║${NC}\n"
printf "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n\n"

# Check if tmux is running
if ! command -v tmux >/dev/null; then
    printf "${YELLOW}⚠${NC} tmux not found\n" >&2
    exit 1
fi

# Get all aod sessions
sessions=$(tmux list-sessions 2>/dev/null | grep "^aod-" || true)

if [[ -z "$sessions" ]]; then
    printf "${YELLOW}No active aod sessions found.${NC}\n\n"
    printf "Run './aod.sh' to start sessions\n"
    exit 0
fi

printf "${CYAN}%-25s %-15s %-10s %s${NC}\n" "SESSION" "CREATED" "ATTACHED" "WINDOWS"
printf "─%.0s" $(seq 1 "$TABLE_WIDTH")
printf "\n"

while IFS= read -r session_line; do
    # Parse session info: session_name: windows (created date) (attached)
    session_name=$(printf '%s' "$session_line" | cut -d':' -f1)
    windows=$(printf '%s' "$session_line" | grep -oE '[0-9]+ windows' | cut -d' ' -f1 || echo "1")
    
    # Check if attached
    if printf '%s' "$session_line" | grep -q "attached"; then
        attached="${GREEN}yes${NC}"
    else
        attached="no"
    fi
    
    # Extract creation date
    created=$(printf '%s' "$session_line" | grep -oE '\([^)]+\)' | head -1 | tr -d '()' || echo "unknown")
    
    printf "%-25s %-15s %-10b %s\n" "$session_name" "$created" "$attached" "$windows"
done <<< "$sessions"

printf "\n${CYAN}aod Containers:${NC}\n"
printf "─%.0s" $(seq 1 "$TABLE_WIDTH")
printf "\n"

# List aod containers
if docker ps --filter "name=aod-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | grep -q .; then
    docker ps --filter "name=aod-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
else
    printf "${YELLOW}No aod containers running${NC}\n"
fi

printf "\n${CYAN}Commands:${NC}\n"
printf "  ./aod-attach.sh <session-name>  - Attach to a session\n"
printf "  ./aod-stop.sh <session-name>    - Stop a specific session\n"
printf "  ./aod-cleanup.sh                - Stop all sessions and cleanup\n"
printf "\n"
