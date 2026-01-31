#!/usr/bin/env bash
# hal9000 - Launch hal-9000 containers with full MCP/agent stack
#
# Usage:
#   hal9000 run [--profile PROFILE] [--slot N] [--name NAME] [DIR]
#   hal9000 squad CONFIG_FILE
#   hal9000 squad --sessions N [--profile PROFILE]
#
# Examples:
#   hal9000 run                          # Launch in current dir
#   hal9000 run --profile python         # With Python profile
#   hal9000 run ~/projects/myapp         # Specific directory
#   hal9000 squad tasks.conf             # Multi-session from config
#   hal9000 squad --sessions 3           # Launch 3 identical sessions

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly HAL9000_DIR="$HOME/.hal9000"
readonly LOCKFILE="$HAL9000_DIR/hal9000.lock"

# Source shared library for common functions
# shellcheck source=../lib/container-common.sh
source "${SCRIPT_DIR}/../lib/container-common.sh"

# Cleanup lock on exit (uses release_lock from container-common.sh)
cleanup_on_exit() {
    release_lock "$LOCKFILE"
}
trap cleanup_on_exit EXIT INT TERM

# Show usage
usage() {
    cat <<EOF
hal9000 - Launch hal-9000 containers with full MCP/agent stack

Usage:
  hal9000 run [OPTIONS] [DIRECTORY]    Launch single container
  hal9000 squad CONFIG_FILE            Launch multiple sessions from config
  hal9000 squad --sessions N           Launch N identical sessions

Options for 'run':
  --profile PROFILE    Use specific profile (python, node, java)
  --slot N             Use specific slot number
  --name NAME          Custom session name (default: hal9000-N)
  --detach             Don't attach to session after launch

Options for 'squad':
  --sessions N         Number of sessions to launch
  --profile PROFILE    Profile for all sessions (with --sessions)

Config file format (for squad):
  name:profile:description

Example config:
  api-dev:node:API development
  ml-work:python:ML experiments
  backend:java:Backend services

Commands:
  hal9000-list         List active sessions
  hal9000-attach NAME  Attach to session
  hal9000-send NAME CMD Send command to session
  hal9000-broadcast CMD Send command to all sessions
  hal9000-cleanup      Stop all sessions

EOF
    exit 0
}

# Check prerequisites (uses common function)
check_prerequisites() {
    check_container_prerequisites tmux docker
}

# Initialize hal9000 directory
init_hal9000_dir() {
    mkdir -p "$HAL9000_DIR/claude" "$HAL9000_DIR/sessions"
}

# Get next available slot number (wraps common function for hal9000 containers)
get_next_slot() {
    get_next_container_slot "hal9000"
}

# inject_mcp_config is provided by container-common.sh

# Create session-specific CLAUDE.md
create_session_claudemd() {
    local session_name="$1"
    local work_dir="$2"
    local profile="$3"

    local other_sessions
    other_sessions=$(tmux list-sessions 2>/dev/null | grep "^hal9000-" | cut -d':' -f1 | grep -v "^${session_name}$" || echo "")

    # Create session context file with restrictive permissions
    (umask 077 && cat > "$work_dir/.hal9000-session.md" <<EOF
# hal9000 Session Context

This is a **hal9000** container session with the full hal-9000 stack.

## Current Session

- **Session Name:** \`$session_name\`
- **Working Directory:** \`$work_dir\`
- **Profile:** \`${profile:-default}\`

## MCP Servers Available

- **memory-bank** - Persistent memory in ~/memory-bank (shared with host)
  - \`mcp__allPepper-memory-bank__list_projects\`
  - \`mcp__allPepper-memory-bank__memory_bank_read/write\`
- **sequential-thinking** - Step-by-step reasoning for complex problems
  - \`mcp__sequential-thinking__sequentialthinking\`
- **chromadb** - Vector database for semantic search
  - \`mcp__chromadb__search_similar\`, \`mcp__chromadb__create_document\`

## Custom Agents Available

- **Development**: java-developer, java-architect-planner, java-debugger
- **Review**: code-review-expert, plan-auditor, deep-analyst
- **Research**: deep-research-synthesizer, codebase-deep-analyzer

## Other Active Sessions

EOF

    if [[ -n "$other_sessions" ]]; then
        while IFS= read -r other_session; do
            [[ -z "$other_session" ]] && continue
            printf -- "- \`%s\`\n" "$other_session" >> "$work_dir/.hal9000-session.md"
        done <<< "$other_sessions"
    else
        printf "(No other sessions currently active)\n" >> "$work_dir/.hal9000-session.md"
    fi

    cat >> "$work_dir/.hal9000-session.md" <<'EOF'

## Available Commands

**Send command to specific session:**
```bash
hal9000-send SESSION "command"
```

**Send command to all sessions:**
```bash
hal9000-broadcast "command"
```

**List all sessions:**
```bash
hal9000-list
```

**Attach to another session:**
```bash
# Detach first: Ctrl+b d
hal9000-attach SESSION-NAME
```

## Tips

- Each session is isolated but shares the memory-bank
- Use `hal9000-send` and `hal9000-broadcast` to coordinate without switching
- Check current session: `tmux display-message -p '#S'`

## Issue Tracking (beads)

Use `bd` for ALL task tracking. Do NOT use markdown TODO lists.

**Quick Commands:**
```bash
bd ready                          # Show work ready to do
bd create "Title" -t task -p 1    # Create issue
bd update <id> --status in_progress
bd close <id> --reason "Done"
bd list                           # All issues
```

**Workflow:**
1. Check `bd ready` for unblocked work
2. Claim: `bd update <id> --status in_progress`
3. Work on it
4. Complete: `bd close <id> --reason "Done"`
5. Commit `.beads/issues.jsonl` with your changes

**Initialize in project:**
```bash
bd init                           # First time setup
bd onboard                        # Full integration guide
```
EOF
)
    chmod 600 "$work_dir/.hal9000-session.md"
}

# Launch a container in a tmux session
launch_session() {
    local session_name="$1"
    local work_dir="$2"
    local slot="$3"
    local profile="$4"
    local detach="${5:-false}"

    info "Launching hal9000 session: $session_name (slot $slot)"

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        warn "Tmux session already exists: $session_name"
        if [[ "$detach" != "true" ]]; then
            info "Attaching to existing session..."
            tmux attach-session -t "$session_name"
        fi
        return 0
    fi

    # Check for existing container with same slot
    local existing_container
    existing_container=$(docker ps -a --filter "name=hal9000-.*-slot${slot}" --format "{{.Names}}" 2>/dev/null | head -1 || true)
    if [[ -n "$existing_container" ]]; then
        warn "Found existing container with slot $slot: $existing_container"
        info "Stopping and removing..."
        docker rm -f "$existing_container" >/dev/null 2>&1 || true
    fi

    # Select image - use versioned tags for supply chain security
    local image="ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    if [[ -n "$profile" ]]; then
        # Check for profile-specific image (versioned or local)
        if docker image inspect "ghcr.io/hellblazer/hal-9000:${profile}-v3.0.0" >/dev/null 2>&1; then
            image="ghcr.io/hellblazer/hal-9000:${profile}-v3.0.0"
        elif docker image inspect "ghcr.io/hellblazer/hal-9000:${profile}" >/dev/null 2>&1; then
            warn "Using locally cached profile image (consider updating to versioned tag)"
            image="ghcr.io/hellblazer/hal-9000:${profile}"
        else
            warn "Profile image '${profile}' not found, using base image"
        fi
    fi

    # Create container-specific .claude directory
    local container_claude_dir="$HAL9000_DIR/claude/$session_name"
    mkdir -p "$container_claude_dir"

    # Copy host Claude config
    if [[ -d ~/.claude ]]; then
        [[ -f ~/.claude/config.json ]] && cp ~/.claude/config.json "$container_claude_dir/" 2>/dev/null || true
        [[ -f ~/.claude/settings.json ]] && cp ~/.claude/settings.json "$container_claude_dir/" 2>/dev/null || true
        # Copy agents
        if [[ -d ~/.claude/agents ]]; then
            cp -r ~/.claude/agents "$container_claude_dir/" 2>/dev/null || true
        fi
    fi

    # Inject MCP server configuration
    inject_mcp_config "$container_claude_dir/settings.json"

    # Create session CLAUDE.md
    create_session_claudemd "$session_name" "$work_dir" "$profile"

    # Ensure memory-bank directory exists
    mkdir -p "$HOME/memory-bank"

    # Build docker command using array for proper quoting
    local container_name="hal9000-${session_name}-slot${slot}"
    local -a docker_args=(
        docker run -it --rm
        --name "$container_name"
        -v "$work_dir:/workspace"
        -v "$container_claude_dir:/home/claude/.claude"
        -v "$HOME/memory-bank:/home/claude/memory-bank"
        -w /workspace
        -e "HAL9000_SESSION=$session_name"
        -e "HAL9000_SLOT=$slot"
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
    tmux new-session -d -s "$session_name" -c "$work_dir" "eval $docker_cmd"

    # Save session info with restrictive permissions
    (umask 077 && cat > "$HAL9000_DIR/sessions/${session_name}.json" <<EOF
{
  "session": "$session_name",
  "directory": "$work_dir",
  "slot": $slot,
  "profile": "${profile:-default}",
  "container": "$container_name",
  "created": "$(date +%FT%T%z)"
}
EOF
)
    chmod 600 "$HAL9000_DIR/sessions/${session_name}.json"

    success "Session launched: $session_name"
    info "  Directory: $work_dir"
    info "  Slot: $slot"
    info "  Profile: ${profile:-default}"

    # Attach unless detached mode
    if [[ "$detach" != "true" ]]; then
        info "Attaching to session... (Ctrl+b d to detach)"
        sleep 1
        tmux attach-session -t "$session_name"
    fi
}

# Parse simple config file
parse_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        die "Configuration file not found: $config_file"
    fi

    local tasks=()
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        tasks+=("$line")
    done < "$config_file"

    printf '%s\n' "${tasks[@]}"
}

# SECURITY: Validate profile name
validate_profile() {
    local profile="$1"
    if [[ -z "$profile" ]]; then
        return 0
    fi
    # Only allow alphanumeric and hyphen
    if [[ ! "$profile" =~ ^[a-zA-Z0-9-]+$ ]]; then
        die "Invalid profile name: '$profile'. Only alphanumeric and hyphen allowed."
    fi
    # Must be a known profile
    local allowed_profiles=("python" "node" "java" "base" "worker" "latest")
    local valid=false
    for p in "${allowed_profiles[@]}"; do
        if [[ "$profile" == "$p" ]]; then
            valid=true
            break
        fi
    done
    if [[ "$valid" != "true" ]]; then
        die "Unknown profile: '$profile'. Allowed: ${allowed_profiles[*]}"
    fi
}

# Run single container
cmd_run() {
    local profile=""
    local slot=""
    local name=""
    local detach="false"
    local work_dir=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                profile="$2"
                validate_profile "$profile"
                shift 2
                ;;
            --slot)
                slot="$2"
                shift 2
                ;;
            --name)
                name="$2"
                shift 2
                ;;
            --detach|-d)
                detach="true"
                shift
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                work_dir="$1"
                shift
                ;;
        esac
    done

    # Default to current directory
    work_dir="${work_dir:-$(pwd)}"
    work_dir="$(cd "$work_dir" && pwd)"  # Resolve to absolute path

    # Acquire lock for slot assignment
    acquire_lock "$LOCKFILE"

    # Get slot if not specified
    if [[ -z "$slot" ]]; then
        slot=$(get_next_slot)
    fi

    # Generate session name if not specified
    if [[ -z "$name" ]]; then
        name="hal9000-${slot}"
    fi

    # Validate session name to prevent command injection
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Session name must contain only alphanumeric characters, underscores, and hyphens"
    fi

    launch_session "$name" "$work_dir" "$slot" "$profile" "$detach"

    # Release lock after session is launched
    release_lock "$LOCKFILE"
}

# Run multiple sessions (squad mode)
cmd_squad() {
    local config_file=""
    local num_sessions=""
    local profile=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sessions|-n)
                num_sessions="$2"
                shift 2
                ;;
            --profile)
                profile="$2"
                validate_profile "$profile"
                shift 2
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                config_file="$1"
                shift
                ;;
        esac
    done

    printf "${BLUE}╔════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║   hal9000 squad - Multi-Session Mode   ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n\n"

    local work_dir
    work_dir="$(pwd)"

    # Acquire lock for entire squad launch to prevent slot conflicts
    acquire_lock "$LOCKFILE"

    if [[ -n "$num_sessions" ]]; then
        # Launch N identical sessions
        info "Launching $num_sessions sessions..."

        for ((i=1; i<=num_sessions; i++)); do
            local slot
            slot=$(get_next_slot)
            local session_name="hal9000-${slot}"

            printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            printf "Session $i of $num_sessions\n"
            printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

            launch_session "$session_name" "$work_dir" "$slot" "$profile" "true"
            printf "\n"
        done
    elif [[ -n "$config_file" ]]; then
        # Launch from config file
        info "Reading configuration: $config_file"
        local tasks
        tasks=$(parse_config "$config_file")

        if [[ -z "$tasks" ]]; then
            die "No tasks found in configuration file"
        fi

        while IFS=: read -r name task_profile description; do
            name=$(echo "$name" | xargs)
            task_profile=$(echo "$task_profile" | xargs)
            description=$(echo "$description" | xargs)

            local session_name="hal9000-${name}"
            local slot
            slot=$(get_next_slot)

            printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            printf "Task: ${GREEN}%s${NC}\n" "${description:-$name}"
            printf "Profile: %s\n" "${task_profile:-default}"
            printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

            launch_session "$session_name" "$work_dir" "$slot" "$task_profile" "true"
            printf "\n"
        done <<< "$tasks"
    else
        die "Either --sessions N or CONFIG_FILE required for squad mode"
    fi

    # Release lock after all sessions are launched
    release_lock "$LOCKFILE"

    printf "\n${GREEN}╔════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║     All sessions launched! 🚀          ║${NC}\n"
    printf "${GREEN}╚════════════════════════════════════════╝${NC}\n\n"

    info "Use 'hal9000-list' to see active sessions"
    info "Use 'hal9000-attach <session>' to attach"
    info "Use 'hal9000-cleanup' to stop all"
}

# Main
main() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
    fi

    check_prerequisites
    init_hal9000_dir

    local cmd="$1"
    shift

    case "$cmd" in
        run)
            cmd_run "$@"
            ;;
        squad)
            cmd_squad "$@"
            ;;
        *)
            die "Unknown command: $cmd. Use 'hal9000 --help' for usage."
            ;;
    esac
}

main "$@"
