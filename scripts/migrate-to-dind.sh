#!/usr/bin/env bash
# migrate-to-dind.sh - Migrate from single-container to DinD architecture
#
# Usage:
#   ./migrate-to-dind.sh [options]
#
# Options:
#   --dry-run           Show what would be migrated without making changes
#   --skip-backup       Skip backup step (not recommended)
#   --force             Continue even if pre-checks fail
#   -h, --help          Show this help
#
# This script migrates from claudy v0.5.x (single container) to v0.6.x (DinD)
#
# Changes:
# - ChromaDB: local directory -> named volume (hal9000-chromadb)
# - Memory Bank: local directory -> named volume (hal9000-memorybank)
# - Plugins: local directory -> named volume (hal9000-plugins)
# - Sessions: remain in ~/.hal9000/claude/{name}/ (no change)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[migrate]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[migrate]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[migrate]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[migrate]${NC} %s\n" "$1" >&2; }

# Configuration
HAL9000_HOME="${HAL9000_HOME:-$HOME/.hal9000}"
BACKUP_DIR="${HAL9000_HOME}/backups/pre-dind-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
SKIP_BACKUP=false
FORCE=false

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_help() {
    cat <<EOF
Usage: migrate-to-dind.sh [options]

Migrate from claudy v0.5.x (single container) to v0.6.x (DinD architecture).

Options:
  --dry-run           Show what would be migrated without making changes
  --skip-backup       Skip backup step (not recommended)
  --force             Continue even if pre-checks fail
  -h, --help          Show this help

What gets migrated:
  - ChromaDB data     -> hal9000-chromadb volume
  - Memory Bank data  -> hal9000-memorybank volume
  - Plugins           -> hal9000-plugins volume
  - Sessions          -> unchanged (remain in ~/.hal9000/claude/)

The migration:
  1. Verifies prerequisites (Docker, claudy v0.6.x)
  2. Backs up existing data
  3. Creates named Docker volumes
  4. Copies data into volumes
  5. Starts the DinD daemon
  6. Verifies migration success

After migration:
  - Use 'claudy daemon start' to start orchestrator
  - Use 'claudy --via-parent' to spawn workers through parent
  - Use 'claudy daemon status' to check health
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
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
# PRE-CHECKS
# ============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."
    local failed=false

    # Check Docker
    if ! command -v docker &>/dev/null; then
        log_error "Docker not installed"
        failed=true
    elif ! docker ps &>/dev/null; then
        log_error "Docker daemon not running"
        failed=true
    else
        log_success "Docker available"
    fi

    # Check claudy version
    local claudy="${REPO_ROOT}/claudy"
    if [[ -x "$claudy" ]]; then
        local version
        version=$("$claudy" --version 2>&1 | head -1) || version=""
        if echo "$version" | grep -qE "0\.[6-9]|[1-9]\.[0-9]"; then
            log_success "Claudy version OK: $version"
        else
            log_warn "Claudy version might be old: $version"
        fi
    else
        log_error "Claudy not found at $claudy"
        failed=true
    fi

    # Check HAL9000_HOME
    if [[ -d "$HAL9000_HOME" ]]; then
        log_success "HAL9000_HOME exists: $HAL9000_HOME"
    else
        log_info "HAL9000_HOME not found (fresh install): $HAL9000_HOME"
    fi

    # Check if already migrated
    if docker volume inspect hal9000-chromadb &>/dev/null; then
        log_warn "Named volumes already exist - may be already migrated"
        if [[ "$FORCE" != "true" ]]; then
            log_error "Use --force to continue anyway"
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi
    return 0
}

detect_existing_data() {
    log_info "Detecting existing data..."

    # Check for ChromaDB data
    local chromadb_dir="${HAL9000_HOME}/chromadb"
    if [[ -d "$chromadb_dir" ]]; then
        local chromadb_size
        chromadb_size=$(du -sh "$chromadb_dir" 2>/dev/null | cut -f1) || chromadb_size="unknown"
        log_info "  ChromaDB: $chromadb_dir ($chromadb_size)"
        echo "chromadb:$chromadb_dir"
    else
        log_info "  ChromaDB: not found (fresh)"
    fi

    # Check for Memory Bank data
    local membank_dir="${HAL9000_HOME}/membank"
    if [[ -d "$membank_dir" ]]; then
        local membank_size
        membank_size=$(du -sh "$membank_dir" 2>/dev/null | cut -f1) || membank_size="unknown"
        log_info "  Memory Bank: $membank_dir ($membank_size)"
        echo "membank:$membank_dir"
    else
        log_info "  Memory Bank: not found (fresh)"
    fi

    # Check for plugins
    local plugins_dir="${HAL9000_HOME}/plugins"
    if [[ -d "$plugins_dir" ]]; then
        local plugins_size
        plugins_size=$(du -sh "$plugins_dir" 2>/dev/null | cut -f1) || plugins_size="unknown"
        log_info "  Plugins: $plugins_dir ($plugins_size)"
        echo "plugins:$plugins_dir"
    else
        log_info "  Plugins: not found (fresh)"
    fi

    # Check for sessions (these don't migrate - just informational)
    local sessions_dir="${HAL9000_HOME}/claude"
    if [[ -d "$sessions_dir" ]]; then
        local session_count
        session_count=$(find "$sessions_dir" -maxdepth 1 -type d | wc -l)
        session_count=$((session_count - 1))  # Subtract 1 for the directory itself
        log_info "  Sessions: $session_count found (will remain in place)"
    fi
}

# ============================================================================
# BACKUP
# ============================================================================

create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_warn "Skipping backup (--skip-backup)"
        return 0
    fi

    log_info "Creating backup at: $BACKUP_DIR"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup directory"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"

    # Backup ChromaDB
    local chromadb_dir="${HAL9000_HOME}/chromadb"
    if [[ -d "$chromadb_dir" ]]; then
        log_info "  Backing up ChromaDB..."
        cp -r "$chromadb_dir" "$BACKUP_DIR/chromadb"
        log_success "  ChromaDB backed up"
    fi

    # Backup Memory Bank
    local membank_dir="${HAL9000_HOME}/membank"
    if [[ -d "$membank_dir" ]]; then
        log_info "  Backing up Memory Bank..."
        cp -r "$membank_dir" "$BACKUP_DIR/membank"
        log_success "  Memory Bank backed up"
    fi

    # Backup Plugins
    local plugins_dir="${HAL9000_HOME}/plugins"
    if [[ -d "$plugins_dir" ]]; then
        log_info "  Backing up Plugins..."
        cp -r "$plugins_dir" "$BACKUP_DIR/plugins"
        log_success "  Plugins backed up"
    fi

    # Create manifest
    cat > "$BACKUP_DIR/manifest.json" <<EOF
{
    "created_at": "$(date -Iseconds)",
    "hal9000_home": "$HAL9000_HOME",
    "source_version": "v0.5.x",
    "target_version": "v0.6.x"
}
EOF

    log_success "Backup created: $BACKUP_DIR"
}

# ============================================================================
# MIGRATION
# ============================================================================

create_volumes() {
    log_info "Creating Docker volumes..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create volumes: hal9000-chromadb, hal9000-memorybank, hal9000-plugins"
        return 0
    fi

    # Create volumes (idempotent)
    for vol in hal9000-chromadb hal9000-memorybank hal9000-plugins; do
        if docker volume inspect "$vol" &>/dev/null; then
            log_info "  Volume $vol already exists"
        else
            docker volume create "$vol" >/dev/null
            log_success "  Created volume: $vol"
        fi
    done
}

migrate_data() {
    log_info "Migrating data to volumes..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would copy data to volumes"
        return 0
    fi

    # Migrate ChromaDB
    local chromadb_dir="${HAL9000_HOME}/chromadb"
    if [[ -d "$chromadb_dir" ]] && [[ "$(ls -A "$chromadb_dir" 2>/dev/null)" ]]; then
        log_info "  Migrating ChromaDB data..."
        # Use a temporary container to copy data into volume
        docker run --rm \
            -v "$chromadb_dir:/source:ro" \
            -v hal9000-chromadb:/dest \
            alpine sh -c "cp -a /source/. /dest/" 2>/dev/null || {
            log_warn "  ChromaDB migration may have partial data"
        }
        log_success "  ChromaDB migrated"
    else
        log_info "  No ChromaDB data to migrate"
    fi

    # Migrate Memory Bank
    local membank_dir="${HAL9000_HOME}/membank"
    if [[ -d "$membank_dir" ]] && [[ "$(ls -A "$membank_dir" 2>/dev/null)" ]]; then
        log_info "  Migrating Memory Bank data..."
        docker run --rm \
            -v "$membank_dir:/source:ro" \
            -v hal9000-memorybank:/dest \
            alpine sh -c "cp -a /source/. /dest/" 2>/dev/null || {
            log_warn "  Memory Bank migration may have partial data"
        }
        log_success "  Memory Bank migrated"
    else
        log_info "  No Memory Bank data to migrate"
    fi

    # Migrate Plugins
    local plugins_dir="${HAL9000_HOME}/plugins"
    if [[ -d "$plugins_dir" ]] && [[ "$(ls -A "$plugins_dir" 2>/dev/null)" ]]; then
        log_info "  Migrating Plugins data..."
        docker run --rm \
            -v "$plugins_dir:/source:ro" \
            -v hal9000-plugins:/dest \
            alpine sh -c "cp -a /source/. /dest/" 2>/dev/null || {
            log_warn "  Plugins migration may have partial data"
        }
        log_success "  Plugins migrated"
    else
        log_info "  No Plugins data to migrate"
    fi
}

start_daemon() {
    log_info "Starting DinD daemon..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would start daemon with: claudy daemon start"
        return 0
    fi

    local claudy="${REPO_ROOT}/claudy"
    "$claudy" daemon start 2>&1 || {
        log_error "Failed to start daemon"
        return 1
    }

    log_success "Daemon started"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_migration() {
    log_info "Verifying migration..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would verify migration"
        return 0
    fi

    local failed=false

    # Check volumes exist
    for vol in hal9000-chromadb hal9000-memorybank hal9000-plugins; do
        if docker volume inspect "$vol" &>/dev/null; then
            log_success "  Volume $vol: exists"
        else
            log_error "  Volume $vol: missing"
            failed=true
        fi
    done

    # Check daemon is running
    if docker ps --format '{{.Names}}' | grep -q "^hal9000-parent$"; then
        log_success "  Parent container: running"

        # Check ChromaDB health
        if docker exec hal9000-parent curl -s "http://localhost:8000/api/v2/heartbeat" >/dev/null 2>&1; then
            log_success "  ChromaDB server: healthy"
        else
            log_warn "  ChromaDB server: not responding (may still be starting)"
        fi
    else
        log_warn "  Parent container: not running"
    fi

    # Check data was migrated
    local chromadb_dir="${HAL9000_HOME}/chromadb"
    if [[ -d "$chromadb_dir" ]] && [[ "$(ls -A "$chromadb_dir" 2>/dev/null)" ]]; then
        # Verify data exists in volume
        local vol_files
        vol_files=$(docker run --rm -v hal9000-chromadb:/data alpine ls /data 2>/dev/null | wc -l) || vol_files=0
        if [[ "$vol_files" -gt 0 ]]; then
            log_success "  ChromaDB data: migrated ($vol_files items)"
        else
            log_warn "  ChromaDB data: volume appears empty"
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# CLEANUP
# ============================================================================

show_post_migration_info() {
    echo ""
    log_info "================================================"
    log_info "  Migration Complete"
    log_info "================================================"
    echo ""
    log_info "Your data has been migrated to Docker volumes:"
    log_info "  - hal9000-chromadb:    ChromaDB vector store"
    log_info "  - hal9000-memorybank:  Memory Bank storage"
    log_info "  - hal9000-plugins:     Plugin data"
    echo ""
    log_info "Original data backed up to:"
    log_info "  $BACKUP_DIR"
    echo ""
    log_info "Next steps:"
    log_info "  1. Test: claudy daemon status"
    log_info "  2. Spawn worker: claudy --via-parent /path/to/project"
    log_info "  3. If issues, rollback: ./scripts/rollback-dind.sh"
    echo ""
    log_info "To remove old local data (after verifying migration):"
    log_info "  rm -rf ${HAL9000_HOME}/chromadb"
    log_info "  rm -rf ${HAL9000_HOME}/membank"
    log_info "  rm -rf ${HAL9000_HOME}/plugins"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    echo ""
    log_info "================================================"
    log_info "  HAL-9000 Migration: v0.5.x -> v0.6.x (DinD)"
    log_info "================================================"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Pre-checks
    if ! check_prerequisites; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "Prerequisites check failed. Use --force to continue anyway."
            exit 1
        fi
        log_warn "Continuing despite failed prerequisites (--force)"
    fi

    echo ""
    detect_existing_data

    echo ""
    create_backup

    echo ""
    create_volumes

    echo ""
    migrate_data

    echo ""
    start_daemon

    echo ""
    if verify_migration; then
        show_post_migration_info
    else
        log_error "Migration verification failed. Check logs above."
        log_info "Your original data is backed up at: $BACKUP_DIR"
        exit 1
    fi
}

main "$@"
