#!/usr/bin/env bash
# aod-cleanup.sh - Cleanup all aod sessions and worktrees
#
# WARNING: This will stop all aod sessions and remove worktrees!

set -Eeuo pipefail
IFS=$'\n\t'

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly AOD_DIR="$HOME/.aod"

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

printf "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}\n"
printf "${YELLOW}║              aod - Cleanup                                 ║${NC}\n"
printf "${YELLOW}║  WARNING: This will stop all sessions and remove worktrees║${NC}\n"
printf "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}\n\n"

# Confirm
printf "Are you sure you want to cleanup all aod sessions? (y/N): "
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "Cleanup cancelled"
    exit 0
fi

printf "\n"

# Step 1: Kill all aod tmux sessions
info "Killing all aod tmux sessions..."

session_count=0
while IFS= read -r session; do
    session_name=$(printf '%s' "$session" | cut -d':' -f1)
    if tmux kill-session -t "$session_name" 2>/dev/null; then
        success "Killed session: $session_name"
        session_count=$((session_count + 1))
    fi
done < <(tmux list-sessions 2>/dev/null | grep "^aod-" || true)

if [[ $session_count -eq 0 ]]; then
    info "No aod sessions found"
else
    success "Killed $session_count session(s)"
fi

printf "\n"

# Step 2: Force kill any remaining aod containers
info "Checking for remaining aod containers..."

container_count=0
while IFS= read -r container; do
    if docker rm -f "$container" >/dev/null 2>&1; then
        success "Removed container: $container"
        container_count=$((container_count + 1))
    fi
done < <(docker ps -a --filter "name=aod-.*-slot" --format "{{.Names}}" 2>/dev/null || true)

if [[ $container_count -eq 0 ]]; then
    info "No aod containers found"
else
    success "Removed $container_count container(s)"
fi

printf "\n"

# Step 3: Remove git worktrees
info "Removing git worktrees..."

if [[ ! -d "$AOD_DIR/worktrees" ]]; then
    info "No worktree directory found"
else
    worktree_count=0
    while IFS= read -r worktree_dir; do
        if [[ -d "$worktree_dir" ]]; then
            # Get the worktree path for git worktree remove
            if git worktree remove "$worktree_dir" --force 2>/dev/null; then
                success "Removed worktree: $(basename "$worktree_dir")"
                worktree_count=$((worktree_count + 1))
            else
                warn "Could not remove worktree: $(basename "$worktree_dir"), trying prune and force removal..."
                # Fallback: prune the worktree from git's tracking, then remove directory
                git worktree prune 2>/dev/null || true
                if [[ -d "$worktree_dir" ]]; then
                    # Force remove the directory
                    rm -rf "$worktree_dir" 2>/dev/null && success "Force removed: $(basename "$worktree_dir")" || warn "Failed to remove: $worktree_dir (manual cleanup needed)"
                fi
                worktree_count=$((worktree_count + 1))
            fi
        fi
    done < <(find "$AOD_DIR/worktrees" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    if [[ $worktree_count -eq 0 ]]; then
        info "No worktrees found"
    else
        success "Removed $worktree_count worktree(s)"
    fi
    
    # Remove worktree directory if empty
    if [[ -d "$AOD_DIR/worktrees" ]]; then
        rmdir "$AOD_DIR/worktrees" 2>/dev/null || true
    fi
fi

printf "\n"

# Step 4: Clean aod directory
info "Cleaning aod state..."

if [[ -f "$AOD_DIR/sessions.log" ]]; then
    rm -f "$AOD_DIR/sessions.log"
    success "Removed sessions log"
fi

if [[ -d "$AOD_DIR" ]]; then
    # Remove if empty
    rmdir "$AOD_DIR" 2>/dev/null && success "Removed aod directory" || true
fi

printf "\n"
printf "${GREEN}╔════════════════════════════════════════╗${NC}\n"
printf "${GREEN}║        Cleanup complete! ✨             ║${NC}\n"
printf "${GREEN}╚════════════════════════════════════════╝${NC}\n\n"

info "All aod sessions, containers, and worktrees have been cleaned up"
info "You can run './aod.sh' to start new sessions"
printf "\n"
