#!/usr/bin/env bash
# update-base-image-digests.sh - Check and update base image digests
#
# This script checks for updates to pinned base images in Dockerfiles
# and can automatically update them with new digests.
#
# Usage:
#   ./update-base-image-digests.sh [--check|--update|--dry-run]
#
# Options:
#   --check     Check for available updates (default)
#   --update    Update Dockerfiles with new digests
#   --dry-run   Show what would be updated without changing files
#
# Exit codes:
#   0 - No updates available or update successful
#   1 - Error occurred
#   2 - Updates available (check mode)

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_update() { printf "${BLUE}[UPDATE]${NC} %s\n" "$1"; }

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/plugins/hal-9000/docker"

MODE="check"  # check, update, dry-run
UPDATES_AVAILABLE=0
UPDATE_COUNT=0

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                MODE="check"
                shift
                ;;
            --update)
                MODE="update"
                shift
                ;;
            --dry-run)
                MODE="dry-run"
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: update-base-image-digests.sh [OPTIONS]

Check and update base image digests in Dockerfiles.

OPTIONS:
  --check       Check for available updates (default)
  --update      Update Dockerfiles with new digests
  --dry-run     Show what would be updated without changing files
  -h, --help    Show this help message

EXAMPLES:
  # Check for updates
  ./update-base-image-digests.sh --check

  # Preview updates
  ./update-base-image-digests.sh --dry-run

  # Apply updates
  ./update-base-image-digests.sh --update

EXIT CODES:
  0 - No updates or update successful
  1 - Error occurred
  2 - Updates available (check mode)
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Get latest digest for an image tag
get_latest_digest() {
    local image="$1"
    local tag="$2"

    # Pull latest version
    if ! docker pull "${image}:${tag}" >/dev/null 2>&1; then
        log_error "Failed to pull ${image}:${tag}"
        return 1
    fi

    # Get digest from RepoDigests
    local digest
    digest=$(docker inspect "${image}:${tag}" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2)

    if [[ -z "$digest" ]]; then
        log_error "Failed to get digest for ${image}:${tag}"
        return 1
    fi

    echo "$digest"
}

# Extract current digest from Dockerfile
get_current_digest() {
    local dockerfile="$1"
    local image_name="$2"  # e.g., "debian", "node", "ubuntu", "docker"

    # Look for FROM <image>@sha256:...
    local digest
    digest=$(grep "^FROM ${image_name}@sha256:" "$dockerfile" | cut -d'@' -f2 || echo "")

    echo "$digest"
}

# Extract tag reference from comment
get_tag_from_comment() {
    local dockerfile="$1"
    local image_name="$2"

    # Look for comment like: # debian:bookworm-slim (pinned ...)
    local tag
    tag=$(grep "^# ${image_name}:" "$dockerfile" | cut -d':' -f2 | cut -d' ' -f1 || echo "")

    echo "$tag"
}

# Update digest in Dockerfile
update_dockerfile_digest() {
    local dockerfile="$1"
    local image_name="$2"
    local old_digest="$3"
    local new_digest="$4"
    local tag="$5"

    # Create backup
    cp "$dockerfile" "${dockerfile}.bak"

    # Update comment with new date
    local new_date
    new_date=$(date +%Y-%m-%d)

    # Update the comment line
    sed -i.tmp "s|^# ${image_name}:${tag} (pinned [0-9-]*)|# ${image_name}:${tag} (pinned ${new_date})|" "$dockerfile"

    # Update the FROM line
    sed -i.tmp "s|^FROM ${image_name}@${old_digest}|FROM ${image_name}@${new_digest}|" "$dockerfile"

    # Remove temp file
    rm -f "${dockerfile}.tmp"

    log_success "Updated $dockerfile"
}

# Check a specific base image across all Dockerfiles
check_base_image() {
    local image_name="$1"
    local default_tag="$2"

    log_info "Checking ${image_name}:${default_tag}..."

    # Get latest digest
    local latest_digest
    if ! latest_digest=$(get_latest_digest "$image_name" "$default_tag"); then
        log_warn "Skipping ${image_name}:${default_tag} (pull failed)"
        return 0
    fi

    log_info "Latest digest: $latest_digest"

    # Check all Dockerfiles
    local found_usage=false
    for dockerfile in "$DOCKER_DIR"/Dockerfile*; do
        [[ ! -f "$dockerfile" ]] && continue

        # Skip our own images
        if grep -q "FROM ghcr.io/hellblazer/hal-9000" "$dockerfile" 2>/dev/null; then
            continue
        fi

        # Check if this Dockerfile uses this image
        if ! grep -q "^FROM ${image_name}@sha256:" "$dockerfile" 2>/dev/null; then
            continue
        fi

        found_usage=true

        local current_digest
        current_digest=$(get_current_digest "$dockerfile" "$image_name")

        local tag
        tag=$(get_tag_from_comment "$dockerfile" "$image_name")
        [[ -z "$tag" ]] && tag="$default_tag"

        if [[ "$current_digest" == "$latest_digest" ]]; then
            log_success "$(basename "$dockerfile"): Up to date"
        else
            log_update "$(basename "$dockerfile"): Update available"
            log_info "  Current: ${current_digest:0:12}..."
            log_info "  Latest:  ${latest_digest:0:12}..."

            UPDATES_AVAILABLE=1

            if [[ "$MODE" == "update" ]]; then
                update_dockerfile_digest "$dockerfile" "$image_name" "$current_digest" "$latest_digest" "$tag"
                ((UPDATE_COUNT++))
            elif [[ "$MODE" == "dry-run" ]]; then
                log_info "  Would update: ${image_name}@${latest_digest}"
                ((UPDATE_COUNT++))
            fi
        fi
    done

    if [[ "$found_usage" == "false" ]]; then
        log_info "No Dockerfiles use ${image_name}"
    fi

    echo ""
}

# Main execution
main() {
    parse_args "$@"

    echo "=========================================="
    echo "Base Image Digest Update Check"
    echo "=========================================="
    echo "Mode: $MODE"
    echo "Docker directory: $DOCKER_DIR"
    echo ""

    # Check each base image
    check_base_image "debian" "bookworm-slim"
    check_base_image "node" "20-bookworm-slim"
    check_base_image "ubuntu" "24.04"
    check_base_image "docker" "27-dind"

    # Summary
    echo "=========================================="
    echo "Summary"
    echo "=========================================="

    if [[ $UPDATES_AVAILABLE -eq 0 ]]; then
        log_success "All base images are up to date!"
        exit 0
    else
        if [[ "$MODE" == "check" ]]; then
            log_warn "Updates available for base images"
            log_info "Run with --update to apply updates"
            exit 2
        elif [[ "$MODE" == "dry-run" ]]; then
            log_info "Would update $UPDATE_COUNT Dockerfile(s)"
            log_info "Run with --update to apply changes"
            exit 0
        else
            log_success "Updated $UPDATE_COUNT Dockerfile(s)"
            log_info "Changes:"
            log_info "  - Updated digests to latest versions"
            log_info "  - Updated pin dates"
            log_info "  - Created .bak backups"
            log_info ""
            log_info "Next steps:"
            log_info "  1. Review changes: git diff"
            log_info "  2. Validate: cd plugins/hal-9000/docker && ./validate-base-image-digests.sh"
            log_info "  3. Test builds: docker build -f Dockerfile.parent ..."
            log_info "  4. Commit: git add -A && git commit -m 'Update base image digests'"
            exit 0
        fi
    fi
}

main "$@"
