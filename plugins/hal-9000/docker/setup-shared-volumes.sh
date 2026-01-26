#!/usr/bin/env bash
# setup-shared-volumes.sh - Set up shared data volumes for HAL-9000
#
# Creates and configures the shared volumes that all workers can access:
# - ChromaDB for persistent vector storage
# - Memory Bank for project state
# - Plugins for marketplace extensions
#
# Usage:
#   setup-shared-volumes.sh [options]
#
# Options:
#   --clean         Remove and recreate volumes
#   --status        Show volume status
#   --verify        Verify volumes are accessible
#   -h, --help      Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[shared-volumes]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[shared-volumes]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[shared-volumes]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[shared-volumes]${NC} %s\n" "$1" >&2; }

# ============================================================================
# CONFIGURATION
# ============================================================================

# Shared named volumes
SHARED_VOLUMES=(
    "hal9000-chromadb"
    "hal9000-memorybank"
    "hal9000-plugins"
)

# Volume labels for identification
VOLUME_LABELS="com.hal9000.type=shared"

# Host fallback directories (when not using named volumes)
HAL9000_BASE="${HAL9000_BASE:-$HOME/.hal9000}"
HOST_CHROMADB="${HAL9000_BASE}/chromadb"
HOST_MEMORYBANK="${HAL9000_BASE}/memory-bank"
HOST_PLUGINS="${HAL9000_BASE}/plugins"

# ============================================================================
# VOLUME MANAGEMENT
# ============================================================================

create_volume() {
    local name="$1"
    local description="$2"

    if docker volume inspect "$name" >/dev/null 2>&1; then
        log_info "Volume exists: $name"
        return 0
    fi

    log_info "Creating volume: $name ($description)"
    docker volume create \
        --label "$VOLUME_LABELS" \
        --label "com.hal9000.description=$description" \
        "$name" >/dev/null

    log_success "Created: $name"
}

remove_volume() {
    local name="$1"

    if docker volume inspect "$name" >/dev/null 2>&1; then
        # Check if in use
        local containers
        containers=$(docker ps -a --filter "volume=$name" --format "{{.Names}}" 2>/dev/null || true)

        if [[ -n "$containers" ]]; then
            log_warn "Volume $name in use by: $containers"
            log_warn "Stop containers first or use --force"
            return 1
        fi

        log_info "Removing volume: $name"
        docker volume rm "$name" >/dev/null
        log_success "Removed: $name"
    else
        log_info "Volume not found: $name"
    fi
}

create_all_volumes() {
    log_info "Creating shared volumes..."

    create_volume "hal9000-chromadb" "Shared ChromaDB vector database"
    create_volume "hal9000-memorybank" "Shared Memory Bank storage"
    create_volume "hal9000-plugins" "Marketplace plugins"

    log_success "All shared volumes created"
}

remove_all_volumes() {
    log_warn "Removing all shared volumes..."

    for vol in "${SHARED_VOLUMES[@]}"; do
        remove_volume "$vol" || true
    done

    log_success "Cleanup complete"
}

# ============================================================================
# HOST DIRECTORIES (Fallback)
# ============================================================================

create_host_directories() {
    log_info "Creating host directories (fallback mode)..."

    mkdir -p "$HOST_CHROMADB"
    mkdir -p "$HOST_MEMORYBANK"
    mkdir -p "$HOST_PLUGINS"

    # Set permissions
    chmod 700 "$HOST_CHROMADB" "$HOST_MEMORYBANK" "$HOST_PLUGINS"

    log_success "Host directories created"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

initialize_chromadb() {
    log_info "Initializing ChromaDB volume..."

    # Create a minimal test to verify the volume works
    docker run --rm \
        -v hal9000-chromadb:/data/chromadb \
        alpine:latest \
        sh -c 'mkdir -p /data/chromadb && touch /data/chromadb/.initialized && echo "ChromaDB volume ready"'

    log_success "ChromaDB initialized"
}

initialize_memorybank() {
    log_info "Initializing Memory Bank volume..."

    # Create default directory structure
    docker run --rm \
        -v hal9000-memorybank:/data/membank \
        alpine:latest \
        sh -c '
            mkdir -p /data/membank/shared
            echo "# Shared Memory Bank" > /data/membank/shared/README.md
            echo "This directory is for cross-worker shared state." >> /data/membank/shared/README.md
            touch /data/membank/.initialized
            echo "Memory Bank volume ready"
        '

    log_success "Memory Bank initialized"
}

initialize_plugins() {
    log_info "Initializing Plugins volume..."

    # Create plugin directory structure
    docker run --rm \
        -v hal9000-plugins:/data/plugins \
        alpine:latest \
        sh -c '
            mkdir -p /data/plugins/installed
            mkdir -p /data/plugins/cache
            touch /data/plugins/.initialized
            echo "Plugins volume ready"
        '

    log_success "Plugins initialized"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_volumes() {
    log_info "Verifying shared volumes..."

    local all_ok=true

    for vol in "${SHARED_VOLUMES[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            # Check if initialized
            local init_check
            init_check=$(docker run --rm -v "$vol:/check" alpine:latest \
                sh -c 'test -f /check/.initialized && echo "yes" || echo "no"' 2>/dev/null) || init_check="error"

            if [[ "$init_check" == "yes" ]]; then
                printf "  ${GREEN}✓${NC} %s (initialized)\n" "$vol"
            else
                printf "  ${YELLOW}○${NC} %s (exists but not initialized)\n" "$vol"
            fi
        else
            printf "  ${RED}✗${NC} %s (missing)\n" "$vol"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == "true" ]]; then
        log_success "All volumes verified"
        return 0
    else
        log_error "Some volumes missing - run setup-shared-volumes.sh to create"
        return 1
    fi
}

# ============================================================================
# STATUS
# ============================================================================

show_status() {
    echo
    echo "=== HAL-9000 Shared Volumes Status ==="
    echo

    echo "Named Volumes:"
    for vol in "${SHARED_VOLUMES[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            local size
            size=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $3}' || echo "N/A")
            printf "  ${GREEN}✓${NC} %-25s %s\n" "$vol" "$size"
        else
            printf "  ${RED}✗${NC} %-25s (not created)\n" "$vol"
        fi
    done

    echo
    echo "Host Directories:"
    for dir in "$HOST_CHROMADB" "$HOST_MEMORYBANK" "$HOST_PLUGINS"; do
        if [[ -d "$dir" ]]; then
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "N/A")
            printf "  ${GREEN}✓${NC} %-40s %s\n" "$dir" "$size"
        else
            printf "  ${YELLOW}○${NC} %-40s (not created)\n" "$dir"
        fi
    done

    echo
    echo "Volume Usage by Containers:"
    for vol in "${SHARED_VOLUMES[@]}"; do
        local containers
        containers=$(docker ps --filter "volume=$vol" --format "{{.Names}}" 2>/dev/null | tr '\n' ' ')
        if [[ -n "$containers" ]]; then
            printf "  %s: %s\n" "$vol" "$containers"
        fi
    done
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat <<EOF
Set up HAL-9000 Shared Volumes

Usage: setup-shared-volumes.sh [options]

Options:
  --clean         Remove and recreate all shared volumes
  --status        Show current volume status
  --verify        Verify volumes are accessible and initialized
  --host          Create host directories instead of Docker volumes
  -h, --help      Show this help

Examples:
  setup-shared-volumes.sh              # Create and initialize volumes
  setup-shared-volumes.sh --status     # Check current status
  setup-shared-volumes.sh --clean      # Clean and recreate
  setup-shared-volumes.sh --verify     # Verify accessibility

Volumes Created:
  hal9000-chromadb      Shared ChromaDB vector database
  hal9000-memorybank    Shared Memory Bank for project state
  hal9000-plugins       Marketplace plugin storage

Mount Points:
  hal9000-chromadb    → /data/chromadb
  hal9000-memorybank  → /data/membank
  hal9000-plugins     → /data/plugins
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local clean=false
    local status_only=false
    local verify_only=false
    local host_mode=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --clean)
                clean=true
                shift
                ;;
            --status)
                status_only=true
                shift
                ;;
            --verify)
                verify_only=true
                shift
                ;;
            --host)
                host_mode=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Status only
    if [[ "$status_only" == "true" ]]; then
        show_status
        exit 0
    fi

    # Verify only
    if [[ "$verify_only" == "true" ]]; then
        verify_volumes
        exit $?
    fi

    # Host mode (fallback)
    if [[ "$host_mode" == "true" ]]; then
        create_host_directories
        exit 0
    fi

    # Clean mode
    if [[ "$clean" == "true" ]]; then
        remove_all_volumes
    fi

    # Create and initialize
    log_info "Setting up shared volumes..."

    create_all_volumes
    initialize_chromadb
    initialize_memorybank
    initialize_plugins

    log_success "Shared volume setup complete"
    echo
    show_status
}

main "$@"
