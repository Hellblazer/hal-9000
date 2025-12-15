#!/usr/bin/env bash
# hal9000-cleanup - Stop all hal9000 sessions and containers
#
# Usage: hal9000-cleanup [--force]

set -Eeuo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly HAL9000_DIR="$HOME/.hal9000"

force="false"
if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "-f" ]]; then
    force="true"
fi

# Get all hal9000 sessions
sessions=$(tmux list-sessions 2>/dev/null | grep "^hal9000-" | cut -d':' -f1 || true)

if [[ -z "$sessions" ]]; then
    printf "${YELLOW}No active hal9000 sessions${NC}\n"
else
    # Count sessions
    session_count=$(echo "$sessions" | wc -l | tr -d ' ')

    if [[ "$force" != "true" ]]; then
        printf "${YELLOW}This will stop $session_count hal9000 session(s):${NC}\n"
        echo "$sessions" | while read -r s; do printf "  - $s\n"; done
        printf "\n"
        read -p "Continue? (y/N): " -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            printf "${YELLOW}Cancelled${NC}\n"
            exit 0
        fi
    fi

    printf "\n${CYAN}Stopping sessions...${NC}\n"

    while IFS= read -r session_name; do
        [[ -z "$session_name" ]] && continue
        printf "  Stopping $session_name..."

        # Kill tmux session (this will also stop the container due to -it --rm)
        tmux kill-session -t "$session_name" 2>/dev/null || true

        # Clean up session file
        rm -f "$HAL9000_DIR/sessions/${session_name}.json" 2>/dev/null || true

        printf " ${GREEN}✓${NC}\n"
    done <<< "$sessions"
fi

# Clean up any orphaned containers
orphaned=$(docker ps -a --filter "name=hal9000-" --format "{{.Names}}" 2>/dev/null || true)
if [[ -n "$orphaned" ]]; then
    printf "\n${CYAN}Cleaning up orphaned containers...${NC}\n"
    while IFS= read -r container; do
        [[ -z "$container" ]] && continue
        printf "  Removing $container..."
        docker rm -f "$container" >/dev/null 2>&1 || true
        printf " ${GREEN}✓${NC}\n"
    done <<< "$orphaned"
fi

# Clean up claude directories for stopped sessions
if [[ -d "$HAL9000_DIR/claude" ]]; then
    printf "\n${CYAN}Cleaning up session data...${NC}\n"
    # Use nullglob to handle case where no directories match
    nullglob_was_set=false
    shopt -q nullglob && nullglob_was_set=true
    shopt -s nullglob
    for dir in "$HAL9000_DIR/claude"/hal9000-*; do
        [[ -e "$dir" ]] || continue  # Skip if no matches (extra safety)
        session_name=$(basename "$dir")
        if ! tmux has-session -t "$session_name" 2>/dev/null; then
            printf "  Removing $session_name data..."
            rm -rf "$dir"
            printf " ${GREEN}✓${NC}\n"
        fi
    done
    # Restore nullglob to original state
    if [[ "$nullglob_was_set" == "false" ]]; then
        shopt -u nullglob
    fi
fi

printf "\n${GREEN}✓ Cleanup complete${NC}\n"
