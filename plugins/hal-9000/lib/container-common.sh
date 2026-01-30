#!/usr/bin/env bash
# container-common.sh - Shared functions for hal9000 and aod container management
#
# Source this file from hal9000.sh, aod.sh, and related scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/container-common.sh"

# Prevent multiple sourcing
if [[ -n "${_CONTAINER_COMMON_SOURCED:-}" ]]; then
    return 0
fi
readonly _CONTAINER_COMMON_SOURCED=1

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Standard log with timestamp (for file logging)
log() {
    printf '%s [%s] %s\n' "$(date +%FT%T%z)" "$1" "$2" >&2
}

# Console logging with icons
info() {
    printf "${CYAN}i${NC} %s\n" "$1" >&2
}

success() {
    printf "${GREEN}✓${NC} %s\n" "$1" >&2
}

warn() {
    printf "${YELLOW}!${NC} %s\n" "$1" >&2
}

error() {
    printf "${RED}x${NC} %s\n" "$1" >&2
}

die() {
    error "$1"
    exit 1
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

# Check for required tools
# Usage: check_prerequisites "git" "tmux" "docker"
check_container_prerequisites() {
    local missing=()
    local tool

    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required tools: ${missing[*]}"
    fi

    # Verify Docker is running if docker was in the list
    for tool in "$@"; do
        if [[ "$tool" == "docker" ]]; then
            if ! docker ps >/dev/null 2>&1; then
                die "Docker is not running. Please start Docker and try again."
            fi
            break
        fi
    done
}

# ============================================================================
# LOCKING FUNCTIONS
# ============================================================================

# Acquire lock with timeout
# Usage: acquire_lock "/path/to/lockfile" [max_wait_seconds]
acquire_lock() {
    local lockfile="$1"
    local max_wait="${2:-30}"
    local waited=0

    while ! mkdir "$lockfile" 2>/dev/null; do
        if [[ $waited -ge $max_wait ]]; then
            die "Could not acquire lock after ${max_wait}s. Another instance may be stuck. Remove $lockfile to force."
        fi
        sleep 1
        ((waited++))
    done
}

# Release lock
release_lock() {
    local lockfile="$1"
    rmdir "$lockfile" 2>/dev/null || true
}

# ============================================================================
# SLOT MANAGEMENT
# ============================================================================

# Get next available slot number for containers
# Usage: get_next_slot "hal9000" or get_next_slot "aod"
get_next_container_slot() {
    local prefix="${1:-hal9000}"
    local max_slot=0
    local slot

    while IFS= read -r container; do
        if [[ "$container" =~ -slot([0-9]+) ]]; then
            slot="${BASH_REMATCH[1]}"
            if [[ $slot -gt $max_slot ]]; then
                max_slot=$slot
            fi
        fi
    done < <(docker ps --filter "name=${prefix}" --format "{{.Names}}" 2>/dev/null || true)

    printf '%d\n' "$((max_slot + 1))"
}

# ============================================================================
# MCP CONFIGURATION
# ============================================================================

# Inject MCP server configuration into settings.json
# Usage: inject_mcp_config "/path/to/settings.json"
# SECURITY: Uses jq for safe JSON manipulation (no code injection risk)
inject_mcp_config() {
    local settings_file="$1"

    # SECURITY: Validate settings_file path
    if [[ -z "$settings_file" ]]; then
        warn "inject_mcp_config: settings_file path required"
        return 1
    fi

    # Create settings.json if it doesn't exist
    if [[ ! -f "$settings_file" ]]; then
        echo '{}' > "$settings_file"
    fi

    # Determine ChromaDB client type based on environment variables
    local chromadb_client_type="ephemeral"
    if [[ -n "${CHROMADB_TENANT:-}" ]] && [[ -n "${CHROMADB_API_KEY:-}" ]]; then
        chromadb_client_type="cloud"
        info "ChromaDB configured for cloud mode"
    fi

    # MCP server configuration
    # SECURITY: Paths must match container user (claude, UID 1000)
    local mcp_config
    mcp_config=$(cat <<'MCPEOF'
{
  "mcpServers": {
    "memory-bank": {
      "command": "mcp-server-memory-bank",
      "args": [],
      "env": {
        "MEMORY_BANK_ROOT": "/home/claude/memory-bank"
      }
    },
    "sequential-thinking": {
      "command": "mcp-server-sequential-thinking",
      "args": []
    },
    "chromadb": {
      "command": "chroma-mcp",
      "args": ["--client-type", "CHROMADB_CLIENT_TYPE_PLACEHOLDER"],
      "env": {}
    }
  }
}
MCPEOF
)
    # Substitute the client type (safe - value is controlled)
    mcp_config="${mcp_config//CHROMADB_CLIENT_TYPE_PLACEHOLDER/$chromadb_client_type}"

    # Merge MCP config using jq (preferred - safe JSON manipulation)
    if command -v jq >/dev/null 2>&1; then
        local merged
        merged=$(jq -s '.[0] * .[1] | .mcpServers = (.[0].mcpServers // {}) * (.[1].mcpServers // {})' \
            "$settings_file" <(echo "$mcp_config") 2>/dev/null) || {
            warn "Could not merge MCP config with jq"
            return 1
        }
        echo "$merged" > "$settings_file"
    # Fallback to Python if jq not available
    elif command -v python3 >/dev/null 2>&1; then
        # SECURITY: Pass MCP config via stdin to avoid exposure in process listings
        # Only the settings file path is passed as argument (not sensitive)
        echo "$mcp_config" | python3 -c "
import json
import sys

settings_file = sys.argv[1]
mcp_config = json.load(sys.stdin)  # Read config from stdin (not visible in ps)

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    settings = {}

if 'mcpServers' not in settings:
    settings['mcpServers'] = {}
settings['mcpServers'].update(mcp_config.get('mcpServers', {}))

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
" "$settings_file"
        if [[ $? -ne 0 ]]; then
            warn "Could not inject MCP config (Python error)"
            return 1
        fi
    else
        warn "Neither jq nor Python available for MCP config injection"
        return 1
    fi
}

# ============================================================================
# DOCKER HELPERS
# ============================================================================

# Build docker args array for container launch
# Sets docker_args array variable
# Usage: init_docker_args "container-name" "/workspace/dir" "/claude/dir"
# SECURITY: Container runs as non-root user 'claude' (UID 1000)
init_docker_args() {
    local container_name="$1"
    local work_dir="$2"
    local claude_dir="$3"
    local image="${4:-ghcr.io/hellblazer/hal-9000:latest}"

    # Ensure memory-bank directory exists
    mkdir -p "$HOME/memory-bank"

    docker_args=(
        docker run -it --rm
        --name "$container_name"
        --network host
        -v "$work_dir:/workspace"
        -v "$claude_dir:/home/claude/.claude"
        -v "$HOME/memory-bank:/home/claude/memory-bank"
        -w /workspace
        -e ANTHROPIC_API_KEY
    )
}

# Add ChromaDB environment variables to docker_args
# Usage: add_chromadb_env
add_chromadb_env() {
    [[ -n "${CHROMADB_TENANT:-}" ]] && docker_args+=(-e CHROMADB_TENANT)
    [[ -n "${CHROMADB_DATABASE:-}" ]] && docker_args+=(-e CHROMADB_DATABASE)
    [[ -n "${CHROMADB_API_KEY:-}" ]] && docker_args+=(-e CHROMADB_API_KEY)
}

# Build quoted command string for tmux from docker_args
# Usage: build_tmux_command
build_tmux_command() {
    printf '%q ' "${docker_args[@]}"
}

# ============================================================================
# SESSION INFO
# ============================================================================

# Get list of other sessions with given prefix
# Usage: get_other_sessions "hal9000-" "$current_session"
get_other_sessions() {
    local prefix="$1"
    local current_session="$2"

    tmux list-sessions 2>/dev/null | grep "^${prefix}" | cut -d':' -f1 | grep -v "^${current_session}$" || echo ""
}

# Export functions for sourcing
export -f log info success warn error die
export -f check_container_prerequisites
export -f acquire_lock release_lock
export -f get_next_container_slot
export -f inject_mcp_config
export -f init_docker_args add_chromadb_env build_tmux_command
export -f get_other_sessions
