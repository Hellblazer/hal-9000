#!/usr/bin/env bash
# aod.sh - Manage multiple ClaudeBox instances with git worktrees
# 
# Integrates ClaudeBox with claude-aod-style workflow:
# - Creates git worktrees for different branches
# - Launches isolated ClaudeBox containers per worktree
# - Manages tmux sessions for easy switching
#
# Usage: ./aod.sh [config_file]

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly AOD_DIR="$HOME/.aod"
readonly LOCKFILE="$AOD_DIR/aod.lock"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    printf '%s [%s] %s\n' "$(date +%FT%T%z)" "$1" "$2" >&2
}

info() {
    printf "${CYAN}ℹ${NC} %s\n" "$1" >&2
}

success() {
    printf "${GREEN}✓${NC} %s\n" "$1" >&2
}

warn() {
    printf "${YELLOW}⚠${NC} %s\n" "$1" >&2
}

error() {
    printf "${RED}✗${NC} %s\n" "$1" >&2
}

die() {
    error "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    
    command -v git >/dev/null || missing+=("git")
    command -v tmux >/dev/null || missing+=("tmux")
    command -v docker >/dev/null || missing+=("docker")
    
    # Check if claudebox is available
    if ! command -v claudebox >/dev/null && [[ ! -x "$SCRIPT_DIR/claudebox.sh" ]]; then
        missing+=("claudebox")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required tools: ${missing[*]}"
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        die "Not in a git repository"
    fi
}

# Initialize squad directory
init_squad_dir() {
    if [[ ! -d "$AOD_DIR" ]]; then
        mkdir -p "$AOD_DIR"
        info "Initialized squad directory: $AOD_DIR"
    fi
}

# Acquire lock or fail
acquire_lock() {
    # Use mkdir for atomic lock creation
    if ! mkdir "$LOCKFILE" 2>/dev/null; then
        die "Another instance is already running (lockfile: $LOCKFILE)"
    fi
}

# Release lock
release_lock() {
    rmdir "$LOCKFILE" 2>/dev/null || true
}

# Cleanup on exit
cleanup() {
    release_lock
}

trap cleanup EXIT INT TERM

# Parse configuration file
parse_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        die "Configuration file not found: $config_file"
    fi
    
    # Simple key=value parser (Bash 3.2 compatible)
    # Format: branch:profile:description
    local tasks=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        
        tasks+=("$line")
    done < "$config_file"
    
    printf '%s\n' "${tasks[@]}"
}

# Get next available slot number
get_next_slot() {
    local max_slot=0
    local slot
    
    # Check running ClaudeBox containers
    while IFS= read -r container; do
        if [[ "$container" =~ -slot([0-9]+) ]]; then
            slot="${BASH_REMATCH[1]}"
            if [[ $slot -gt $max_slot ]]; then
                max_slot=$slot
            fi
        fi
    done < <(docker ps --filter "name=claudebox" --format "{{.Names}}" 2>/dev/null || true)
    
    printf '%d\n' "$((max_slot + 1))"
}

# Create git worktree
create_worktree() {
    local branch="$1"
    local worktree_dir="$2"
    
    info "Creating worktree for branch: $branch"
    
    # Check if branch exists
    if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
        # Create branch from current HEAD
        git branch "$branch"
        info "Created new branch: $branch"
    fi
    
    # Create worktree
    if [[ -d "$worktree_dir" ]]; then
        warn "Worktree directory already exists: $worktree_dir"
        return 1
    fi
    
    git worktree add "$worktree_dir" "$branch"
    success "Worktree created: $worktree_dir"
}

# Launch ClaudeBox in tmux session
launch_session() {
    local session_name="$1"
    local worktree_dir="$2"
    local slot="$3"
    local profile="$4"

    info "Launching ClaudeBox session: $session_name (slot $slot)"

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        warn "Tmux session already exists: $session_name"
        return 1
    fi

    # Check for existing container with same slot and stop it
    local container_name="claudebox-.*-slot${slot}"
    local existing_container
    existing_container=$(docker ps -a --filter "name=${container_name}" --format "{{.Names}}" 2>/dev/null | head -1 || true)
    if [[ -n "$existing_container" ]]; then
        warn "Found existing container with slot $slot: $existing_container"
        info "Stopping and removing existing container..."
        docker rm -f "$existing_container" >/dev/null 2>&1 || true
    fi

    # Determine claudebox command
    local claudebox_cmd
    if command -v claudebox >/dev/null; then
        claudebox_cmd="claudebox"
    else
        claudebox_cmd="$SCRIPT_DIR/claudebox.sh"
    fi

    # Build claudebox command
    local cmd="cd '$worktree_dir' && $claudebox_cmd run --slot $slot"
    if [[ -n "$profile" ]]; then
        cmd="$cmd --profile $profile"
    fi

    # Create tmux session
    tmux new-session -d -s "$session_name" -c "$worktree_dir" "$cmd"

    success "Session launched: $session_name"
    info "  Worktree: $worktree_dir"
    info "  Slot: $slot"
    info "  Profile: ${profile:-default}"
}

# Update state file
update_state() {
    local session_name="$1"
    local branch="$2"
    local worktree_dir="$3"
    local slot="$4"
    local profile="$5"
    
    # Simple JSON update (Bash 3.2 compatible - just append)
    local state_entry
    state_entry=$(cat <<EOF
{
  "session": "$session_name",
  "branch": "$branch",
  "worktree": "$worktree_dir",
  "slot": $slot,
  "profile": "$profile",
  "created": "$(date +%FT%T%z)"
}
EOF
)
    
    printf '%s\n' "$state_entry" >> "$AOD_DIR/sessions.log"
}

# Main execution
main() {
    local config_file="${1:-aod.conf}"
    
    printf "${BLUE}╔════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║   ClaudeBox Squad - Multi-Agent Mode  ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n\n"

    check_prerequisites
    init_squad_dir
    acquire_lock
    
    # Get repository root
    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"
    
    # Get repository name for worktree directory
    local repo_name
    repo_name="$(basename "$repo_root")"
    
    # Parse configuration
    info "Reading configuration: $config_file"
    local tasks
    if ! tasks=$(parse_config "$config_file"); then
        exit 1
    fi
    
    if [[ -z "$tasks" ]]; then
        die "No tasks found in configuration file"
    fi
    
    # Count tasks
    local task_count=0
    while IFS= read -r task; do
        task_count=$((task_count + 1))
    done <<< "$tasks"
    
    info "Found $task_count task(s) to launch\n"

    # Process each task
    while IFS=: read -r branch profile description; do
        # Trim whitespace properly
        branch=$(echo "$branch" | xargs)
        profile=$(echo "$profile" | xargs)
        description=$(echo "$description" | xargs)

        # Generate session name
        local session_name="aod-${branch//\//-}"

        # Generate worktree directory
        local worktree_dir="$HOME/.aod/worktrees/${repo_name}-${branch//\//-}"

        printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        printf "Task: ${GREEN}%s${NC}\n" "${description:-$branch}"
        printf "Branch: %s\n" "$branch"
        printf "Profile: %s\n" "${profile:-default}"
        printf "Session: %s\n" "$session_name"
        printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

        # Get slot number just before launching (avoid race condition)
        local slot_num
        slot_num=$(get_next_slot)

        # Create worktree
        if create_worktree "$branch" "$worktree_dir"; then
            # Launch session
            if launch_session "$session_name" "$worktree_dir" "$slot_num" "$profile"; then
                # Update state
                update_state "$session_name" "$branch" "$worktree_dir" "$slot_num" "$profile"

                printf "\n"
            fi
        fi

    done <<< "$tasks"
    
    printf "\n${GREEN}╔════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║     All sessions launched! 🚀          ║${NC}\n"
    printf "${GREEN}╚════════════════════════════════════════╝${NC}\n\n"
    
    info "Use './aod-list.sh' to see active sessions"
    info "Use './aod-attach.sh <session-name>' to attach to a session"
    info "Use './aod-cleanup.sh' to stop all sessions and cleanup"
}

main "$@"
