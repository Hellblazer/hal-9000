#!/usr/bin/env bash
# rollback-dind.sh - Rollback from DinD to single-container architecture
#
# Usage:
#   ./rollback-dind.sh [options]
#
# Options:
#   --backup PATH         Restore from specific backup directory
#   --list-backups        List available backups
#   --keep-volumes        Don't remove Docker volumes (keep data for later)
#   --force               Skip confirmations
#   -h, --help            Show this help
#
# This script reverts from claudy v0.6.x (DinD) back to v0.5.x (single-container)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[rollback]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[rollback]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[rollback]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[rollback]${NC} %s\n" "$1" >&2; }

# Configuration
HAL9000_HOME="${HAL9000_HOME:-$HOME/.hal9000}"
BACKUP_DIR=""
LIST_BACKUPS=false
KEEP_VOLUMES=false
FORCE=false

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_help() {
    cat <<EOF
Usage: rollback-dind.sh [options]

Rollback from claudy v0.6.x (DinD) to v0.5.x (single-container) architecture.

Options:
  --backup PATH         Restore from specific backup directory
  --list-backups        List available backups and exit
  --keep-volumes        Don't remove Docker volumes (preserve data)
  --force               Skip confirmations
  -h, --help            Show this help

What this does:
  1. Stops the DinD daemon (parent container)
  2. Optionally removes Docker volumes (hal9000-chromadb, etc.)
  3. Restores local directories from backup
  4. Confirms you can use --legacy mode

After rollback:
  - Use 'claudy --legacy' for single-container mode
  - Data from volumes is NOT automatically restored to local dirs
  - Manual volume data export available with --keep-volumes

Example:
  ./rollback-dind.sh --list-backups          # See available backups
  ./rollback-dind.sh --backup /path/to/backup # Restore specific backup
  ./rollback-dind.sh --keep-volumes          # Rollback but keep volume data
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --list-backups)
                LIST_BACKUPS=true
                shift
                ;;
            --keep-volumes)
                KEEP_VOLUMES=true
                shift
                ;;
            --force)
                FORCE=true
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
}

# ============================================================================
# BACKUP DISCOVERY
# ============================================================================

list_backups() {
    local backup_base="${HAL9000_HOME}/backups"

    if [[ ! -d "$backup_base" ]]; then
        log_warn "No backups directory found at: $backup_base"
        return 1
    fi

    local backups
    backups=$(find "$backup_base" -maxdepth 1 -type d -name "pre-dind-*" 2>/dev/null | sort -r) || backups=""

    if [[ -z "$backups" ]]; then
        log_warn "No migration backups found"
        return 1
    fi

    echo ""
    log_info "Available backups:"
    echo ""
    for backup in $backups; do
        local manifest="$backup/manifest.json"
        if [[ -f "$manifest" ]]; then
            local created_at
            created_at=$(grep -o '"created_at":[^,]*' "$manifest" | cut -d'"' -f4) || created_at="unknown"
            printf "  %s\n" "$backup"
            printf "    Created: %s\n" "$created_at"

            # Show what's in the backup
            local contents=""
            [[ -d "$backup/chromadb" ]] && contents="${contents}chromadb "
            [[ -d "$backup/membank" ]] && contents="${contents}membank "
            [[ -d "$backup/plugins" ]] && contents="${contents}plugins "
            printf "    Contains: %s\n" "${contents:-nothing}"
            echo ""
        else
            printf "  %s (no manifest)\n" "$backup"
        fi
    done

    return 0
}

find_latest_backup() {
    local backup_base="${HAL9000_HOME}/backups"

    if [[ ! -d "$backup_base" ]]; then
        return 1
    fi

    local latest
    latest=$(find "$backup_base" -maxdepth 1 -type d -name "pre-dind-*" 2>/dev/null | sort -r | head -1) || latest=""

    if [[ -z "$latest" ]]; then
        return 1
    fi

    echo "$latest"
}

# ============================================================================
# ROLLBACK STEPS
# ============================================================================

stop_daemon() {
    log_info "Stopping DinD daemon..."

    # Stop parent container
    if docker ps --format '{{.Names}}' | grep -q "^hal9000-parent$"; then
        log_info "  Stopping hal9000-parent..."
        docker stop hal9000-parent >/dev/null 2>&1 || true
        docker rm hal9000-parent >/dev/null 2>&1 || true
        log_success "  Parent container stopped"
    else
        log_info "  Parent container not running"
    fi

    # Stop any orphaned workers
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" 2>/dev/null) || workers=""
    if [[ -n "$workers" ]]; then
        log_warn "  Stopping orphaned workers..."
        echo "$workers" | while read -r worker; do
            docker stop "$worker" >/dev/null 2>&1 || true
            docker rm "$worker" >/dev/null 2>&1 || true
            log_info "    Stopped: $worker"
        done
    fi
}

export_volume_data() {
    log_info "Exporting volume data before removal..."

    local export_dir="${HAL9000_HOME}/volume-exports-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$export_dir"

    # Export ChromaDB volume
    if docker volume inspect hal9000-chromadb &>/dev/null; then
        log_info "  Exporting hal9000-chromadb..."
        docker run --rm \
            -v hal9000-chromadb:/source:ro \
            -v "$export_dir:/dest" \
            alpine sh -c "cp -a /source/. /dest/chromadb/" 2>/dev/null || {
            log_warn "  Could not export chromadb"
        }
    fi

    # Export memorybank volume
    if docker volume inspect hal9000-memorybank &>/dev/null; then
        log_info "  Exporting hal9000-memorybank..."
        docker run --rm \
            -v hal9000-memorybank:/source:ro \
            -v "$export_dir:/dest" \
            alpine sh -c "cp -a /source/. /dest/membank/" 2>/dev/null || {
            log_warn "  Could not export memorybank"
        }
    fi

    # Export plugins volume
    if docker volume inspect hal9000-plugins &>/dev/null; then
        log_info "  Exporting hal9000-plugins..."
        docker run --rm \
            -v hal9000-plugins:/source:ro \
            -v "$export_dir:/dest" \
            alpine sh -c "cp -a /source/. /dest/plugins/" 2>/dev/null || {
            log_warn "  Could not export plugins"
        }
    fi

    log_success "Volume data exported to: $export_dir"
}

remove_volumes() {
    if [[ "$KEEP_VOLUMES" == "true" ]]; then
        log_info "Keeping Docker volumes (--keep-volumes)"
        return 0
    fi

    log_info "Removing Docker volumes..."

    # Export first as safety measure
    export_volume_data

    for vol in hal9000-chromadb hal9000-memorybank hal9000-plugins; do
        if docker volume inspect "$vol" &>/dev/null; then
            docker volume rm "$vol" >/dev/null 2>&1 || {
                log_warn "  Could not remove $vol (may be in use)"
            }
            log_success "  Removed: $vol"
        fi
    done
}

restore_from_backup() {
    local backup="$BACKUP_DIR"

    if [[ -z "$backup" ]]; then
        log_info "Looking for latest backup..."
        backup=$(find_latest_backup) || {
            log_warn "No backup found to restore from"
            return 0
        }
        log_info "Found: $backup"
    fi

    if [[ ! -d "$backup" ]]; then
        log_error "Backup directory not found: $backup"
        return 1
    fi

    log_info "Restoring from backup: $backup"

    # Restore ChromaDB
    if [[ -d "$backup/chromadb" ]]; then
        local dest="${HAL9000_HOME}/chromadb"
        log_info "  Restoring ChromaDB to $dest..."
        mkdir -p "$dest"
        cp -r "$backup/chromadb/." "$dest/" 2>/dev/null || {
            log_warn "  Could not restore chromadb"
        }
        log_success "  ChromaDB restored"
    fi

    # Restore Memory Bank
    if [[ -d "$backup/membank" ]]; then
        local dest="${HAL9000_HOME}/membank"
        log_info "  Restoring Memory Bank to $dest..."
        mkdir -p "$dest"
        cp -r "$backup/membank/." "$dest/" 2>/dev/null || {
            log_warn "  Could not restore membank"
        }
        log_success "  Memory Bank restored"
    fi

    # Restore Plugins
    if [[ -d "$backup/plugins" ]]; then
        local dest="${HAL9000_HOME}/plugins"
        log_info "  Restoring Plugins to $dest..."
        mkdir -p "$dest"
        cp -r "$backup/plugins/." "$dest/" 2>/dev/null || {
            log_warn "  Could not restore plugins"
        }
        log_success "  Plugins restored"
    fi

    log_success "Backup restored"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_rollback() {
    log_info "Verifying rollback..."
    local issues=0

    # Check daemon is stopped
    if docker ps --format '{{.Names}}' | grep -q "^hal9000-parent$"; then
        log_warn "  Parent container still running"
        issues=$((issues + 1))
    else
        log_success "  Daemon stopped"
    fi

    # Check volumes (if we were supposed to remove them)
    if [[ "$KEEP_VOLUMES" != "true" ]]; then
        for vol in hal9000-chromadb hal9000-memorybank hal9000-plugins; do
            if docker volume inspect "$vol" &>/dev/null; then
                log_warn "  Volume $vol still exists"
            else
                log_success "  Volume $vol removed"
            fi
        done
    fi

    # Check local directories restored (if we had a backup)
    if [[ -n "$BACKUP_DIR" ]] || find_latest_backup &>/dev/null; then
        [[ -d "${HAL9000_HOME}/chromadb" ]] && log_success "  Local chromadb: restored"
        [[ -d "${HAL9000_HOME}/membank" ]] && log_success "  Local membank: restored"
        [[ -d "${HAL9000_HOME}/plugins" ]] && log_success "  Local plugins: restored"
    fi

    return $issues
}

show_post_rollback_info() {
    echo ""
    log_info "================================================"
    log_info "  Rollback Complete"
    log_info "================================================"
    echo ""
    log_info "Your system has been reverted to single-container mode."
    echo ""
    log_info "To use claudy in legacy mode:"
    log_info "  claudy --legacy /path/to/project"
    echo ""
    if [[ "$KEEP_VOLUMES" == "true" ]]; then
        log_info "Docker volumes were preserved. To re-migrate later:"
        log_info "  ./scripts/migrate-to-dind.sh --force"
    else
        log_info "Volume data was exported to:"
        log_info "  ${HAL9000_HOME}/volume-exports-*"
    fi
    echo ""
    log_info "To re-migrate to DinD architecture:"
    log_info "  ./scripts/migrate-to-dind.sh"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    echo ""
    log_info "================================================"
    log_info "  HAL-9000 Rollback: v0.6.x (DinD) -> v0.5.x"
    log_info "================================================"
    echo ""

    # Handle list backups
    if [[ "$LIST_BACKUPS" == "true" ]]; then
        list_backups
        exit 0
    fi

    # Confirmation
    if [[ "$FORCE" != "true" ]]; then
        log_warn "This will:"
        log_warn "  - Stop the DinD daemon"
        if [[ "$KEEP_VOLUMES" != "true" ]]; then
            log_warn "  - Remove Docker volumes (data will be exported first)"
        fi
        log_warn "  - Restore local directories from backup (if available)"
        echo ""
        read -p "Continue? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Rollback cancelled"
            exit 0
        fi
    fi

    # Execute rollback
    echo ""
    stop_daemon

    echo ""
    remove_volumes

    echo ""
    restore_from_backup

    echo ""
    if verify_rollback; then
        show_post_rollback_info
    else
        log_warn "Rollback completed with some issues. Check logs above."
    fi
}

main "$@"
