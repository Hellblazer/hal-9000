#!/usr/bin/env bash
# aod.sh - Manage multiple hal9000 instances with git worktrees
#
# Integrates hal9000 containers with aod-style workflow:
# - Creates git worktrees for different branches
# - Launches isolated hal9000 containers per worktree
# - Manages tmux sessions for easy switching
#
# Usage: ./aod.sh [config_file]

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly AOD_DIR="$HOME/.aod"
readonly LOCKFILE="$AOD_DIR/aod.lock"

# Source shared library for common functions
# shellcheck source=../lib/container-common.sh
source "${SCRIPT_DIR}/../lib/container-common.sh"

# Check prerequisites (extends common prerequisites)
check_prerequisites() {
    # Use common prerequisite check for git, tmux, docker
    check_container_prerequisites git tmux docker

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        die "Not in a git repository"
    fi
}

# Initialize aod directory
init_aod_dir() {
    if [[ ! -d "$AOD_DIR" ]]; then
        mkdir -p "$AOD_DIR"
        info "Initialized aod directory: $AOD_DIR"
    fi

    # Ensure sessions.log has restrictive permissions
    if [[ ! -f "$AOD_DIR/sessions.log" ]]; then
        touch "$AOD_DIR/sessions.log"
    fi
    chmod 600 "$AOD_DIR/sessions.log"
}

# Cleanup on exit (uses release_lock from container-common.sh)
cleanup() {
    release_lock "$LOCKFILE"
}

trap cleanup EXIT INT TERM

# Parse configuration file (supports YAML and simple formats)
parse_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        die "Configuration file not found: $config_file"
    fi

    # Check if YAML format (by extension or content)
    if [[ "$config_file" =~ \.(yml|yaml)$ ]] || grep -q "^tasks:" "$config_file" 2>/dev/null; then
        parse_yaml_config "$config_file"
    else
        parse_simple_config "$config_file"
    fi
}

# Parse YAML format configuration
parse_yaml_config() {
    local config_file="$1"

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        warn "YAML config detected but 'yq' not found. Install with: brew install yq"
        die "Cannot parse YAML config without 'yq'. Use simple format or install yq."
    fi

    # Parse YAML and convert to simple format
    local tasks=()
    local count
    count=$(yq eval '.tasks | length' "$config_file" 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]]; then
        die "No tasks found in YAML config"
    fi

    for ((i=0; i<count; i++)); do
        local branch profile description
        branch=$(yq eval ".tasks[$i].branch" "$config_file" 2>/dev/null || echo "")
        profile=$(yq eval ".tasks[$i].profile" "$config_file" 2>/dev/null || echo "")
        description=$(yq eval ".tasks[$i].description" "$config_file" 2>/dev/null || echo "")

        if [[ -n "$branch" ]]; then
            # Convert to simple format: branch:profile:description
            tasks+=("${branch}:${profile}:${description}")
        fi
    done

    printf '%s\n' "${tasks[@]}"
}

# Parse simple colon-separated format
parse_simple_config() {
    local config_file="$1"

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

# Get next available slot number (wraps common function for aod containers)
get_next_slot() {
    get_next_container_slot "aod"
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

# Create session-specific CLAUDE.md
create_session_claudemd() {
    local session_name="$1"
    local branch="$2"
    local worktree_dir="$3"
    local profile="$4"

    # Get list of other aod sessions
    local other_sessions
    other_sessions=$(tmux list-sessions 2>/dev/null | grep "^aod-" | cut -d':' -f1 | grep -v "^${session_name}$" || echo "")

    # Create CLAUDE.md in worktree
    cat > "$worktree_dir/CLAUDE.md" <<EOF
# aod Session Context

This is an **aod (Army of Darkness)** session for parallel multi-branch development.

## Current Session

- **Session Name:** \`$session_name\`
- **Branch:** \`$branch\`
- **Worktree:** \`$worktree_dir\`
- **Profile:** \`${profile:-default}\`

## Other Active Sessions

EOF

    if [[ -n "$other_sessions" ]]; then
        while IFS= read -r other_session; do
            [[ -z "$other_session" ]] && continue
            printf -- "- \`%s\`\n" "$other_session" >> "$worktree_dir/CLAUDE.md"
        done <<< "$other_sessions"
    else
        printf "(No other sessions currently active)\n" >> "$worktree_dir/CLAUDE.md"
    fi

    cat >> "$worktree_dir/CLAUDE.md" <<'EOF'

## Available Commands

**Send command to specific session:**
```bash
aod-send SESSION "command"
# Example: aod-send aod-feature-api "git status"
```

**Send command to all sessions:**
```bash
aod-broadcast "command"
# Example: aod-broadcast "git fetch"
```

**List all sessions:**
```bash
aod-list
```

## Session Isolation

Each aod session is completely isolated:
- Separate git worktree (independent working directory)
- Separate tmux session (independent terminal)
- Separate hal9000 container (independent environment)

Changes in this session don't affect other sessions until committed to git.

## MCP Servers Available

- **memory-bank** - Persistent memory in ~/memory-bank (shared across sessions)
- **sequential-thinking** - Step-by-step reasoning for complex problems
- **chromadb** - Vector database for semantic search

## Custom Agents Available

- **Development**: java-developer, java-architect-planner, java-debugger
- **Review**: code-review-expert, plan-auditor, deep-analyst
- **Research**: deep-research-synthesizer, codebase-deep-analyzer

## Common Workflows

**Check status in another branch:**
```bash
aod-send aod-feature-api "git status"
```

**Run tests across all branches:**
```bash
aod-broadcast "./mvnw test"
```

**Sync all branches with upstream:**
```bash
aod-broadcast "git fetch origin"
```

**Switch to another session:**
```bash
# Detach: Ctrl+b d
# Then attach: aod-attach SESSION-NAME
```

## Tips

- Use \`aod-send\` and \`aod-broadcast\` to coordinate without switching sessions
- Each session shares the same git repository (.git) - commits are visible across sessions
- Worktrees are in \`~/.aod/worktrees/\`
- Check current session: \`tmux display-message -p '#S'\`

## Issue Tracking (beads)

Use \`bd\` for ALL task tracking across sessions. Issues are shared via git.

**Quick Commands:**
\`\`\`bash
bd ready                          # Show work ready to do
bd create "Title" -t task -p 1    # Create issue
bd update <id> --status in_progress
bd close <id> --reason "Done"
bd list                           # All issues
\`\`\`

**Cross-Session Coordination:**
- Issues are stored in \`.beads/issues.jsonl\` (git-tracked)
- Use \`bd sync\` to force sync before coordinating
- Other sessions see your changes after you commit
- Use \`discovered-from\` dependency to link discovered work

**Workflow:**
1. Check \`bd ready\` for unblocked work
2. Claim: \`bd update <id> --status in_progress\`
3. Work on it in this session
4. Complete: \`bd close <id> --reason "Done"\`
5. Commit \`.beads/issues.jsonl\` with your changes
EOF
    chmod 600 "$worktree_dir/CLAUDE.md"

    info "Created CLAUDE.md in worktree"
}

# inject_mcp_config is provided by container-common.sh

# Launch Docker container in tmux session
launch_session() {
    local session_name="$1"
    local worktree_dir="$2"
    local slot="$3"
    local profile="$4"
    local branch="$5"

    info "Launching aod session: $session_name (slot $slot)"

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        warn "Tmux session already exists: $session_name"
        return 1
    fi

    # Check for existing container with same slot and stop it
    local container_pattern="aod-.*-slot${slot}"
    local existing_container
    existing_container=$(docker ps -a --filter "name=${container_pattern}" --format "{{.Names}}" 2>/dev/null | head -1 || true)
    if [[ -n "$existing_container" ]]; then
        warn "Found existing container with slot $slot: $existing_container"
        info "Stopping and removing existing container..."
        docker rm -f "$existing_container" >/dev/null 2>&1 || true
    fi

    # Build Docker command with Claude CLI + MCP server access
    # MCP servers run inside container (pre-installed in image)
    local container_name="aod-${session_name}-slot${slot}"
    local image="ghcr.io/hellblazer/hal-9000:latest"

    # Select image based on profile (if profile-specific images exist)
    if [[ -n "$profile" ]]; then
        # Try profile-specific image first, fall back to base
        if docker image inspect "ghcr.io/hellblazer/hal-9000:${profile}" >/dev/null 2>&1; then
            image="ghcr.io/hellblazer/hal-9000:${profile}"
        fi
    fi

    # Create container-specific .claude directory for writable state
    local container_claude_dir="$HOME/.aod/claude/$session_name"
    mkdir -p "$container_claude_dir"

    # Copy host Claude config (for auth/settings) but allow container to write
    if [[ -d ~/.claude ]]; then
        # Copy config files but not session-specific state
        [[ -f ~/.claude/config.json ]] && cp ~/.claude/config.json "$container_claude_dir/" 2>/dev/null || true
        [[ -f ~/.claude/settings.json ]] && cp ~/.claude/settings.json "$container_claude_dir/" 2>/dev/null || true
    fi

    # Inject MCP server configuration into container's settings.json
    inject_mcp_config "$container_claude_dir/settings.json"

    # Ensure memory-bank directory exists
    mkdir -p "$HOME/memory-bank"

    # Build docker command using array for proper quoting
    # SECURITY: Container runs as non-root user 'claude' (UID 1000)
    # Mount paths must match container user home directory
    local -a docker_args=(
        docker run -it --rm
        --name "$container_name"
        -v "$worktree_dir:/workspace"
        -v "$container_claude_dir:/home/claude/.claude"
        -v "hal9000-claude-home:/home/claude/.claude/marketplace"
        -v "$HOME/memory-bank:/home/claude/memory-bank"
        -w /workspace
        -e "AOD_SESSION=$session_name"
        -e "AOD_BRANCH=$branch"
        -e "AOD_SLOT=$slot"
        -e ANTHROPIC_API_KEY
    )

    # Add ChromaDB environment variables if set
    [[ -n "${CHROMADB_TENANT:-}" ]] && docker_args+=(-e CHROMADB_TENANT)
    [[ -n "${CHROMADB_DATABASE:-}" ]] && docker_args+=(-e CHROMADB_DATABASE)
    [[ -n "${CHROMADB_API_KEY:-}" ]] && docker_args+=(-e CHROMADB_API_KEY)

    # Add image as last argument
    docker_args+=("$image")

    # Build properly quoted command string for tmux
    local docker_cmd
    docker_cmd=$(printf '%q ' "${docker_args[@]}")

    # Create tmux session and launch container
    # Container CMD will run setup.sh then start bash (or claude if configured)
    tmux new-session -d -s "$session_name" -c "$worktree_dir" "eval $docker_cmd"

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
    printf "${BLUE}║   aod - Multi-Branch Development      ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n\n"

    check_prerequisites
    init_aod_dir
    acquire_lock "$LOCKFILE"
    
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

        # SECURITY: Validate branch name to prevent command injection
        # Only allow alphanumeric characters, slashes, underscores, hyphens, and dots
        if [[ ! "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
            die "Invalid branch name: '$branch'. Only alphanumeric, slash, underscore, hyphen, and dot allowed."
        fi

        # Generate session name
        local session_name="aod-${branch//\//-}"

        # Generate worktree directory
        local worktree_dir="$HOME/.aod/worktrees/${repo_name}-${branch//\//-}"

        # SECURITY: Validate worktree path to prevent path traversal (fail closed)
        # Require realpath for canonicalization - do not fallback to uncanonicalized path
        if ! command -v realpath >/dev/null 2>&1; then
            die "realpath required for secure path validation"
        fi

        local worktree_canonical
        worktree_canonical="$(realpath -m "$worktree_dir" 2>/dev/null)" || {
            die "Security violation: cannot canonicalize worktree path: $worktree_dir"
        }

        if [[ ! "$worktree_canonical" =~ ^"$HOME"/.aod/worktrees/ ]]; then
            die "Security violation: worktree path '$worktree_canonical' escapes allowed directory"
        fi

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
            # Create session-specific CLAUDE.md
            create_session_claudemd "$session_name" "$branch" "$worktree_dir" "$profile"

            # Launch session
            if launch_session "$session_name" "$worktree_dir" "$slot_num" "$profile" "$branch"; then
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
