#!/usr/bin/env bash
# aod-send.sh - Send command to specific aod session
#
# Usage: aod-send <session-name> <command>

set -Eeuo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

if [[ $# -lt 2 ]]; then
    printf "${RED}✗${NC} Usage: %s <session-name> <command>\n" "$(basename "$0")" >&2
    printf "\n"
    printf "Examples:\n"
    printf "  %s aod-feature-auth \"git status\"\n" "$(basename "$0")"
    printf "  %s aod-feature-api \"./mvnw test\"\n" "$(basename "$0")"
    printf "\n"
    printf "Available sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^aod-" | cut -d':' -f1 || printf "  ${CYAN}(none)${NC}\n"
    exit 1
fi

session_name="$1"
shift
command="$*"

# Check if session exists
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    printf "${RED}✗${NC} Session not found: %s\n" "$session_name" >&2
    printf "\n"
    printf "Available sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^aod-" | cut -d':' -f1 || printf "  ${CYAN}(none)${NC}\n"
    exit 1
fi

# Check if tmux-cli is available
if ! command -v tmux-cli &> /dev/null; then
    printf "${RED}✗${NC} tmux-cli not found. Install claude-code-tools:\n" >&2
    printf "  uv tool install claude-code-tools\n" >&2
    exit 1
fi

# Get pane ID for session
pane_id=$(tmux list-panes -t "$session_name" -F '#{pane_id}' | head -1)

if [[ -z "$pane_id" ]]; then
    printf "${RED}✗${NC} Could not get pane ID for session: %s\n" "$session_name" >&2
    exit 1
fi

printf "${GREEN}✓${NC} Sending to %s: %s\n" "$session_name" "$command"

# Send command using tmux-cli
tmux-cli send "$command" --pane="$pane_id"
