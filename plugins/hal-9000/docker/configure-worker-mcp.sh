#!/usr/bin/env bash
# configure-worker-mcp.sh - Configure MCP settings for a worker
#
# Sets up the worker's MCP configuration to use shared volumes.
# Can be run inside a worker container or used to prepare a config volume.
#
# Usage:
#   configure-worker-mcp.sh [options]
#
# Options:
#   --volume NAME     Configure a named volume instead of current container
#   --chromadb PATH   ChromaDB path (default: /data/chromadb)
#   --membank PATH    Memory Bank path (default: /data/membank)
#   --minimal         Create minimal config (no MCP servers)
#   -h, --help        Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[mcp-config]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[mcp-config]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[mcp-config]${NC} %s\n" "$1"; }

# ============================================================================
# CONFIGURATION
# ============================================================================

CLAUDE_HOME="${CLAUDE_HOME:-/root/.claude}"
CHROMADB_HOST="${CHROMADB_HOST:-localhost}"
CHROMADB_PORT="${CHROMADB_PORT:-8000}"
MEMBANK_PATH="/data/membank"
VOLUME_NAME=""
MINIMAL=false

# ============================================================================
# SETTINGS GENERATION
# ============================================================================

generate_full_settings() {
    cat <<EOF
{
  "theme": "dark",
  "preferredNotificationChannel": "terminal",
  "verbose": false,

  "mcpServers": {
    "chromadb": {
      "command": "chroma-mcp",
      "args": [
        "--client-type", "http",
        "--host", "${CHROMADB_HOST}",
        "--port", "${CHROMADB_PORT}"
      ],
      "env": {
        "CHROMA_ANONYMIZED_TELEMETRY": "false"
      }
    },

    "memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp@0.2.2"],
      "env": {
        "MEMORY_BANK_ROOT": "${MEMBANK_PATH}"
      }
    },

    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking@2025.12.18"]
    }
  }
}
EOF
}

generate_minimal_settings() {
    cat <<EOF
{
  "theme": "dark",
  "preferredNotificationChannel": "terminal",
  "verbose": false
}
EOF
}

# ============================================================================
# CONFIGURATION
# ============================================================================

configure_local() {
    log_info "Configuring MCP for: $CLAUDE_HOME"

    # Create directory structure
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$CLAUDE_HOME/agents"
    mkdir -p "$CLAUDE_HOME/commands"

    # Generate settings
    local settings_file="$CLAUDE_HOME/settings.json"

    if [[ -f "$settings_file" ]]; then
        log_warn "settings.json exists, backing up..."
        cp "$settings_file" "${settings_file}.bak"
    fi

    if [[ "$MINIMAL" == "true" ]]; then
        generate_minimal_settings > "$settings_file"
        log_success "Created minimal settings (no MCP)"
    else
        generate_full_settings > "$settings_file"
        log_success "Created settings with shared MCP paths"
    fi

    # Show result
    log_info "Settings file: $settings_file"
    log_info "ChromaDB server: ${CHROMADB_HOST}:${CHROMADB_PORT}"
    log_info "Memory Bank path: $MEMBANK_PATH"
}

configure_volume() {
    local volume="$1"
    log_info "Configuring MCP for volume: $volume"

    # Create volume if needed
    if ! docker volume inspect "$volume" >/dev/null 2>&1; then
        log_info "Creating volume: $volume"
        docker volume create "$volume" >/dev/null
    fi

    # Generate settings content
    local settings_content
    if [[ "$MINIMAL" == "true" ]]; then
        settings_content=$(generate_minimal_settings)
    else
        settings_content=$(generate_full_settings)
    fi

    # Write to volume using alpine container
    docker run --rm \
        -v "$volume:/claude-home" \
        alpine:latest \
        sh -c "
            mkdir -p /claude-home/agents
            mkdir -p /claude-home/commands
            cat > /claude-home/settings.json << 'SETTINGS'
$settings_content
SETTINGS
            echo 'Settings configured'
        "

    log_success "Volume configured: $volume"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_config() {
    local settings_file="$CLAUDE_HOME/settings.json"

    if [[ ! -f "$settings_file" ]]; then
        log_warn "settings.json not found"
        return 1
    fi

    # Check if valid JSON
    if ! python3 -m json.tool "$settings_file" >/dev/null 2>&1 && \
       ! jq . "$settings_file" >/dev/null 2>&1; then
        log_warn "settings.json is not valid JSON"
        return 1
    fi

    log_success "Configuration valid"

    # Show MCP servers
    log_info "Configured MCP servers:"
    if command -v jq &>/dev/null; then
        jq -r '.mcpServers // {} | keys[]' "$settings_file" 2>/dev/null | while read -r server; do
            echo "  - $server"
        done
    else
        grep -o '"[^"]*":' "$settings_file" | grep -v 'theme\|verbose\|preferred' | tr -d '":' | while read -r key; do
            echo "  - $key"
        done
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat <<EOF
Configure MCP Settings for HAL-9000 Worker

Usage: configure-worker-mcp.sh [options]

Options:
  --volume NAME       Configure a named volume instead of current container
  --chromadb-host H   ChromaDB server host (default: localhost)
  --chromadb-port P   ChromaDB server port (default: 8000)
  --membank PATH      Memory Bank path (default: /data/membank)
  --claude-home DIR   Claude home directory (default: /root/.claude)
  --minimal           Create minimal config (no MCP servers)
  --verify            Verify current configuration
  -h, --help          Show this help

Examples:
  # Inside worker container (connects to parent's ChromaDB)
  configure-worker-mcp.sh

  # Configure a specific volume
  configure-worker-mcp.sh --volume hal9000-claude-my-worker

  # Custom ChromaDB server
  configure-worker-mcp.sh --chromadb-host chromadb-server --chromadb-port 9000

  # Minimal config (no MCP servers needed)
  configure-worker-mcp.sh --minimal

MCP Servers Configured:
  chromadb           HTTP client connecting to parent's ChromaDB server
  memory-bank        Project state at MEMBANK_PATH (file-based)
  sequential-thinking Chain-of-thought reasoning

Architecture:
  Parent container runs ChromaDB server on port 8000.
  Workers connect via HTTP (--network=container:parent allows localhost access).
  This ensures safe concurrent read/write from multiple workers.
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local verify_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --volume)
                VOLUME_NAME="$2"
                shift 2
                ;;
            --chromadb)
                CHROMADB_PATH="$2"
                shift 2
                ;;
            --membank)
                MEMBANK_PATH="$2"
                shift 2
                ;;
            --claude-home)
                CLAUDE_HOME="$2"
                shift 2
                ;;
            --minimal)
                MINIMAL=true
                shift
                ;;
            --verify)
                verify_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ "$verify_only" == "true" ]]; then
        verify_config
        exit $?
    fi

    if [[ -n "$VOLUME_NAME" ]]; then
        configure_volume "$VOLUME_NAME"
    else
        configure_local
    fi
}

main "$@"
