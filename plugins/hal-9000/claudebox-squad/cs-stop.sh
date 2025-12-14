#!/usr/bin/env bash
# cs-stop.sh - Stop a specific ClaudeBox Squad session
#
# Usage: ./cs-stop.sh <session-name>

set -Eeuo pipefail
IFS=$'\n\t'

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

info() {
    printf "${CYAN}ℹ${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

error() {
    printf "${RED}✗${NC} %s\n" "$1" >&2
}

if [[ $# -eq 0 ]]; then
    error "Usage: $0 <session-name>"
    printf "\n"
    printf "Available sessions:\n"
    tmux list-sessions 2>/dev/null | grep "^squad-" | cut -d':' -f1 || printf "  ${CYAN}(none)${NC}\n"
    exit 1
fi

session_name="$1"

# Check if session exists
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    error "Session not found: $session_name"
    exit 1
fi

info "Stopping session: $session_name"

# Kill tmux session (this will also stop the ClaudeBox container due to --rm)
tmux kill-session -t "$session_name"

success "Session stopped: $session_name"

# Note about worktree
warn "Note: Git worktree was NOT removed. Use './cs-cleanup.sh' to remove all worktrees."
