#!/usr/bin/env bash
# init-volumes.sh - Initialize HAL-9000 persistent volumes
#
# Creates the required directory structure and Docker volumes for
# HAL-9000 parent/worker containers.
#
# Usage:
#   init-volumes.sh [--clean]
#
# Options:
#   --clean     Remove existing volumes before creating new ones

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[volumes]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[volumes]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[volumes]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[volumes]${NC} %s\n" "$1" >&2; }

# ============================================================================
# CONFIGURATION
# ============================================================================

# Base directory for HAL-9000 state
HAL9000_BASE="${HAL9000_BASE:-$HOME/.hal9000}"

# Directory structure
DIRS=(
    "$HAL9000_BASE"
    "$HAL9000_BASE/sessions"
    "$HAL9000_BASE/logs"
    "$HAL9000_BASE/config"
    "$HAL9000_BASE/workers"
    "$HAL9000_BASE/claude"
)

# Docker volumes (named volumes for container data)
VOLUMES=(
    "hal9000-sessions"
    "hal9000-logs"
    "hal9000-workers"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

clean_volumes() {
    log_warn "Cleaning existing volumes..."

    # Remove directories
    for dir in "${DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Removing: $dir"
            rm -rf "$dir"
        fi
    done

    # Remove Docker volumes
    for vol in "${VOLUMES[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            log_info "Removing volume: $vol"
            docker volume rm "$vol" 2>/dev/null || log_warn "Could not remove $vol (may be in use)"
        fi
    done

    log_success "Cleanup complete"
}

create_directories() {
    log_info "Creating directory structure..."

    for dir in "${DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Created: $dir"
        else
            log_info "Exists: $dir"
        fi
    done
}

create_docker_volumes() {
    log_info "Creating Docker volumes..."

    for vol in "${VOLUMES[@]}"; do
        if ! docker volume inspect "$vol" >/dev/null 2>&1; then
            docker volume create "$vol" >/dev/null
            log_success "Created volume: $vol"
        else
            log_info "Exists: $vol"
        fi
    done
}

create_config_files() {
    log_info "Creating default configuration..."

    # Create default config file
    local config_file="$HAL9000_BASE/config/hal9000.conf"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<EOF
# HAL-9000 Configuration
# Generated: $(date -Iseconds)

# Worker settings
WORKER_IMAGE=ghcr.io/hellblazer/hal-9000:worker
WORKER_REMOVE_ON_EXIT=true
WORKER_MAX_COUNT=10

# Parent settings
PARENT_IMAGE=ghcr.io/hellblazer/hal-9000:parent
PARENT_NAME=hal9000-parent

# Paths (relative to HAL9000_BASE)
SESSIONS_DIR=sessions
LOGS_DIR=logs
WORKERS_DIR=workers

# Logging
LOG_LEVEL=info
LOG_RETENTION_DAYS=7
EOF
        log_success "Created: $config_file"
    else
        log_info "Exists: $config_file"
    fi

    # Create .gitignore for hal9000 directory
    local gitignore="$HAL9000_BASE/.gitignore"
    if [[ ! -f "$gitignore" ]]; then
        cat > "$gitignore" <<EOF
# Ignore everything in .hal9000
*
# Except config
!.gitignore
!config/
!config/*
EOF
        log_success "Created: $gitignore"
    fi
}

show_status() {
    echo
    echo "=== HAL-9000 Volume Status ==="
    echo

    echo "Directories:"
    for dir in "${DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            printf "  ${GREEN}✓${NC} %s\n" "$dir"
        else
            printf "  ${RED}✗${NC} %s\n" "$dir"
        fi
    done

    echo
    echo "Docker Volumes:"
    for vol in "${VOLUMES[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} %s\n" "$vol"
        else
            printf "  ${RED}✗${NC} %s\n" "$vol"
        fi
    done

    echo
    echo "Configuration:"
    local config_file="$HAL9000_BASE/config/hal9000.conf"
    if [[ -f "$config_file" ]]; then
        printf "  ${GREEN}✓${NC} %s\n" "$config_file"
    else
        printf "  ${RED}✗${NC} %s\n" "$config_file"
    fi
}

show_usage() {
    cat <<EOF
Initialize HAL-9000 persistent volumes and directories.

Usage: init-volumes.sh [options]

Options:
  --clean       Remove existing volumes before creating
  --status      Show current volume status
  -h, --help    Show this help

Examples:
  init-volumes.sh              # Create volumes (non-destructive)
  init-volumes.sh --clean      # Clean and recreate
  init-volumes.sh --status     # Show status only
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local clean=false
    local status_only=false

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
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ "$status_only" == "true" ]]; then
        show_status
        exit 0
    fi

    log_info "Initializing HAL-9000 volumes..."
    log_info "Base directory: $HAL9000_BASE"

    if [[ "$clean" == "true" ]]; then
        clean_volumes
    fi

    create_directories
    create_docker_volumes
    create_config_files

    log_success "Volume initialization complete"
    show_status
}

main "$@"
