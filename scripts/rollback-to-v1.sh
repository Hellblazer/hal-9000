#!/usr/bin/env bash
# Rollback HAL-9000 plugin from v2.0 to v1.3.2
#
# This script safely reverts HAL-9000 to the previous stable version (v1.3.2)
# with backup and validation safeguards.
#
# Usage:
#   ./scripts/rollback-to-v1.sh              # Interactive mode with confirmation
#   ./scripts/rollback-to-v1.sh --yes        # Non-interactive (auto-confirm)
#   ./scripts/rollback-to-v1.sh --check      # Check rollback prerequisites only

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly BACKUP_DIR="$HOME/.hal-9000-backups"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Versions
readonly TARGET_VERSION="1.3.2"
readonly CURRENT_VERSION_FILE="$REPO_ROOT/plugins/hal-9000/.claude-plugin/plugin.json"

# Flags
AUTO_CONFIRM=false
CHECK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [OPTIONS]

Rollback HAL-9000 plugin from v2.0 to v1.3.2

Options:
    --yes, -y       Auto-confirm (skip interactive prompts)
    --check, -c     Check prerequisites only (don't rollback)
    --help, -h      Show this help message

Examples:
    $0              # Interactive rollback with confirmation
    $0 --yes        # Non-interactive rollback
    $0 --check      # Verify prerequisites

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

detect_current_version() {
    if [[ ! -f "$CURRENT_VERSION_FILE" ]]; then
        log_error "Cannot find plugin.json at $CURRENT_VERSION_FILE"
        return 1
    fi

    local version
    version=$(python3 -c "import json; print(json.load(open('$CURRENT_VERSION_FILE'))['version'])" 2>/dev/null || echo "unknown")
    echo "$version"
}

check_prerequisites() {
    local errors=0

    log_info "Checking prerequisites..."

    # Check if in git repository
    if ! git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository: $REPO_ROOT"
        ((errors++))
    fi

    # Check if git is clean or has uncommitted changes
    if ! git -C "$REPO_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "Git repository has uncommitted changes"
        log_warning "Changes will be preserved in backup but may cause conflicts"
    fi

    # Check if target tag exists
    if ! git -C "$REPO_ROOT" rev-parse "v$TARGET_VERSION" >/dev/null 2>&1; then
        log_error "Git tag v$TARGET_VERSION not found"
        log_error "Available tags:"
        git -C "$REPO_ROOT" tag | grep "^v" | tail -5
        ((errors++))
    fi

    # Check Python availability (for version detection)
    if ! command -v python3 &> /dev/null; then
        log_error "python3 not found in PATH"
        ((errors++))
    fi

    # Check backup directory is writable
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
            log_error "Cannot create backup directory: $BACKUP_DIR"
            ((errors++))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "All prerequisites met"
        return 0
    else
        log_error "$errors prerequisite check(s) failed"
        return 1
    fi
}

backup_current_state() {
    local backup_path="$BACKUP_DIR/hal-9000-v2.0-backup-$TIMESTAMP"

    log_info "Creating backup at $backup_path..."

    mkdir -p "$backup_path"

    # Backup plugin directory
    if [[ -d "$REPO_ROOT/plugins/hal-9000" ]]; then
        cp -r "$REPO_ROOT/plugins/hal-9000" "$backup_path/" || {
            log_error "Failed to backup plugin directory"
            return 1
        }
    fi

    # Backup Claude config if exists
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        cp "$HOME/.claude/settings.json" "$backup_path/settings.json.backup" || {
            log_warning "Failed to backup Claude settings"
        }
    fi

    # Create backup manifest
    cat > "$backup_path/MANIFEST.txt" <<EOF
HAL-9000 v2.0 Backup
Created: $(date)
Hostname: $(hostname)
User: $(whoami)

Backup Contents:
- Plugin directory: plugins/hal-9000/
- Claude settings: settings.json.backup (if exists)

Restore Instructions:
1. cd $REPO_ROOT
2. git checkout main
3. cp -r $backup_path/hal-9000 plugins/
4. Restart Claude Code

Rollback Timestamp: $TIMESTAMP
EOF

    log_success "Backup created at $backup_path"
    echo "$backup_path"
}

detect_breaking_changes() {
    log_info "Checking for breaking changes..."

    local current_version
    current_version=$(detect_current_version)

    if [[ "$current_version" != "2.0.0" ]]; then
        log_warning "Current version is $current_version (expected 2.0.0)"
        log_warning "Rollback may not be necessary or may cause issues"
        return 1
    fi

    # Check for v2.0-specific features in use
    local has_agent_registry=false
    if [[ -f "$REPO_ROOT/agents/REGISTRY.yaml" ]]; then
        has_agent_registry=true
    fi

    if [[ "$has_agent_registry" == true ]]; then
        log_warning "Agent registry detected (v2.0 feature)"
        log_warning "After rollback, registry commands will not be available"
    fi

    log_info "No breaking changes detected that would prevent rollback"
    return 0
}

perform_rollback() {
    log_info "Rolling back to v$TARGET_VERSION..."

    # Stash any uncommitted changes
    if ! git -C "$REPO_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        log_info "Stashing uncommitted changes..."
        git -C "$REPO_ROOT" stash push -m "Pre-rollback stash $TIMESTAMP" || {
            log_error "Failed to stash changes"
            return 1
        }
    fi

    # Checkout target version
    log_info "Checking out v$TARGET_VERSION..."
    if ! git -C "$REPO_ROOT" checkout "v$TARGET_VERSION" 2>&1; then
        log_error "Failed to checkout v$TARGET_VERSION"
        log_error "You may need to resolve conflicts manually"
        return 1
    fi

    log_success "Rolled back to v$TARGET_VERSION"
    return 0
}

verify_rollback() {
    log_info "Verifying rollback..."

    local current_version
    current_version=$(detect_current_version)

    if [[ "$current_version" != "$TARGET_VERSION" ]]; then
        log_error "Rollback verification failed"
        log_error "Expected version $TARGET_VERSION, got $current_version"
        return 1
    fi

    log_success "Rollback verified: now at v$TARGET_VERSION"
    return 0
}

show_post_rollback_instructions() {
    cat <<EOF

${GREEN}=== Rollback Complete ===${NC}

Version: v$TARGET_VERSION
Backup: $BACKUP_DIR/hal-9000-v2.0-backup-$TIMESTAMP

${YELLOW}Next Steps:${NC}
1. ${BLUE}Restart Claude Code${NC}
   - Quit Claude Code application
   - Relaunch to load v$TARGET_VERSION

2. ${BLUE}Verify Installation${NC}
   - Check that HAL-9000 plugin is active
   - Test basic commands (/sessions, /check)

3. ${BLUE}If Issues Occur${NC}
   - Restore from backup: cp -r $BACKUP_DIR/hal-9000-v2.0-backup-$TIMESTAMP/hal-9000 plugins/
   - Or re-upgrade: git checkout main

${YELLOW}What Changed:${NC}
- Agent registry commands removed (v2.0 feature)
- Enhanced validation tools removed
- Documentation reverted to v1.3.2
- All v1.x features remain functional

${YELLOW}To Re-upgrade to v2.0:${NC}
   cd $REPO_ROOT
   git checkout main
   # Restart Claude Code

EOF
}

confirm_rollback() {
    if [[ "$AUTO_CONFIRM" == true ]]; then
        return 0
    fi

    local current_version
    current_version=$(detect_current_version)

    cat <<EOF

${YELLOW}=== Rollback Confirmation ===${NC}

Current Version: ${RED}$current_version${NC}
Target Version:  ${GREEN}$TARGET_VERSION${NC}

This will:
1. Create backup of current state
2. Checkout git tag v$TARGET_VERSION
3. Restart Claude Code will be required

${YELLOW}Features removed after rollback:${NC}
- Agent registry and validation tools
- Enhanced security documentation
- v2.0 testing infrastructure

${GREEN}All v1.x features remain functional${NC}

EOF

    read -p "Proceed with rollback? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Rollback cancelled by user"
        return 1
    fi

    return 0
}

main() {
    echo -e "${BLUE}HAL-9000 Rollback Utility${NC}"
    echo -e "${BLUE}=========================${NC}\n"

    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites not met. Exiting."
        exit 1
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        log_success "Prerequisites check passed"
        exit 0
    fi

    # Detect current version
    local current_version
    current_version=$(detect_current_version)
    log_info "Current version: $current_version"

    if [[ "$current_version" == "$TARGET_VERSION" ]]; then
        log_warning "Already at target version $TARGET_VERSION"
        log_info "No rollback needed"
        exit 0
    fi

    # Check for breaking changes
    detect_breaking_changes || log_warning "Proceeding despite warnings..."

    # Confirm rollback
    if ! confirm_rollback; then
        exit 0
    fi

    # Create backup
    local backup_path
    backup_path=$(backup_current_state) || {
        log_error "Backup failed. Aborting rollback."
        exit 1
    }

    # Perform rollback
    if ! perform_rollback; then
        log_error "Rollback failed"
        log_error "Your backup is safe at: $backup_path"
        exit 1
    fi

    # Verify rollback
    if ! verify_rollback; then
        log_error "Rollback verification failed"
        log_error "Manual intervention may be required"
        exit 1
    fi

    # Show instructions
    show_post_rollback_instructions

    exit 0
}

main "$@"
