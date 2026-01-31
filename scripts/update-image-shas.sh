#!/usr/bin/env bash
# update-image-shas.sh - Update HAL-9000 worker image allowlist with SHA digests
#
# This script fetches current SHA256 digests for HAL-9000 worker images
# and updates the ALLOWED_IMAGES array in spawn-worker.sh.
#
# Supply Chain Security:
#   - SHA digests are immutable (unlike tags which can be overwritten)
#   - Prevents "tag mutation" attacks where an attacker replaces an image tag
#   - Ensures workers run exactly the image that was tested and verified
#
# Usage:
#   ./update-image-shas.sh [--check|--update|--show]
#
# Options:
#   --check     Check if allowlist uses SHA digests (default)
#   --update    Update spawn-worker.sh with current SHA digests
#   --show      Show current SHA digests for all images
#
# Prerequisites:
#   - Docker CLI installed and authenticated to ghcr.io
#   - Images must be pulled or available in registry
#
# Exit codes:
#   0 - Success
#   1 - Error (missing images, update failed)
#   2 - Allowlist uses tags instead of digests (check mode)

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
SPAWN_WORKER_SH="$REPO_ROOT/plugins/hal-9000/docker/spawn-worker.sh"

# Registry and image configuration
REGISTRY="ghcr.io/hellblazer/hal-9000"
VERSION="v3.0.0"

# Worker image profiles to track
WORKER_PROFILES=(
    "worker"
    "base"
    "python"
    "node"
    "java"
)

MODE="check"  # check, update, show

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
            --show)
                MODE="show"
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

show_help() {
    cat <<EOF
Usage: update-image-shas.sh [OPTIONS]

Update HAL-9000 worker image allowlist with SHA256 digests for supply chain security.

OPTIONS:
  --check       Check if allowlist uses SHA digests (default)
  --update      Update spawn-worker.sh with current SHA digests
  --show        Show current SHA digests for all worker images
  -h, --help    Show this help message

EXAMPLES:
  # Show current digests
  ./update-image-shas.sh --show

  # Check if allowlist is secure
  ./update-image-shas.sh --check

  # Update allowlist with SHA digests
  ./update-image-shas.sh --update

SECURITY:
  SHA digests prevent supply chain attacks where an attacker could:
  - Replace a tagged image with a malicious one
  - Perform "tag mutation" attacks on mutable tags

  Version tags (e.g., :worker-v3.0.0) are better than 'latest' but still mutable.
  SHA digests (e.g., @sha256:abc...) are immutable and provide strongest protection.

WORKFLOW:
  1. Build and push new images: ./scripts/build/build-and-push.sh
  2. Update version in spawn-worker.sh (version tag for readability)
  3. Run: ./update-image-shas.sh --update (adds SHA digest verification)
  4. Commit changes to spawn-worker.sh

EOF
}

# Get SHA digest for an image
get_image_digest() {
    local profile="$1"
    local image="${REGISTRY}:${profile}-${VERSION}"

    # Try to get digest from local image first
    local digest
    digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$image" 2>/dev/null | grep -o 'sha256:[a-f0-9]*' || echo "")

    if [[ -z "$digest" ]]; then
        # Try pulling the image
        log_info "Pulling $image..."
        if docker pull "$image" >/dev/null 2>&1; then
            digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$image" 2>/dev/null | grep -o 'sha256:[a-f0-9]*' || echo "")
        fi
    fi

    if [[ -z "$digest" ]]; then
        log_warn "Could not get digest for $image"
        log_warn "Ensure image exists: docker pull $image"
        return 1
    fi

    echo "$digest"
}

# Show current digests for all images
show_digests() {
    echo "=========================================="
    echo "HAL-9000 Worker Image Digests"
    echo "=========================================="
    echo "Registry: $REGISTRY"
    echo "Version:  $VERSION"
    echo ""

    local all_found=true

    for profile in "${WORKER_PROFILES[@]}"; do
        local image="${REGISTRY}:${profile}-${VERSION}"
        printf "%-30s " "$image"

        local digest
        if digest=$(get_image_digest "$profile" 2>/dev/null); then
            printf "${GREEN}%s${NC}\n" "${digest:0:19}..."
        else
            printf "${RED}(not found)${NC}\n"
            all_found=false
        fi
    done

    echo ""

    if [[ "$all_found" == "true" ]]; then
        log_success "All images have valid digests"
    else
        log_warn "Some images are missing - pull them first"
        return 1
    fi
}

# Check if allowlist uses SHA digests
check_allowlist() {
    echo "=========================================="
    echo "Checking Allowlist Security"
    echo "=========================================="

    if [[ ! -f "$SPAWN_WORKER_SH" ]]; then
        log_error "spawn-worker.sh not found: $SPAWN_WORKER_SH"
        return 1
    fi

    # Check for SHA digest pattern in ALLOWED_IMAGES
    local has_digests=true
    local has_tags=false

    # Extract ALLOWED_IMAGES entries
    local entries
    entries=$(grep -A 10 'ALLOWED_IMAGES=(' "$SPAWN_WORKER_SH" | grep 'ghcr.io' || echo "")

    if [[ -z "$entries" ]]; then
        log_error "Could not find ALLOWED_IMAGES in spawn-worker.sh"
        return 1
    fi

    echo "Current allowlist entries:"
    echo "$entries" | while read -r line; do
        if [[ "$line" =~ @sha256: ]]; then
            printf "  ${GREEN}[SHA]${NC} %s\n" "$line"
        elif [[ "$line" =~ ghcr.io ]]; then
            printf "  ${YELLOW}[TAG]${NC} %s\n" "$line"
            has_tags=true
        fi
    done

    echo ""

    # Check for SHA digests
    if echo "$entries" | grep -q '@sha256:'; then
        log_success "Allowlist contains SHA digests"
    else
        log_warn "Allowlist uses only version tags (no SHA digests)"
        log_warn "Consider running: $0 --update"
        return 2
    fi

    # Check for version tags without digests
    if echo "$entries" | grep -qv '@sha256:' | grep -q 'ghcr.io'; then
        log_warn "Some entries use tags without SHA digests"
        log_info "For maximum security, all entries should use SHA digests"
    fi
}

# Update allowlist with SHA digests
update_allowlist() {
    echo "=========================================="
    echo "Updating Allowlist with SHA Digests"
    echo "=========================================="

    if [[ ! -f "$SPAWN_WORKER_SH" ]]; then
        log_error "spawn-worker.sh not found: $SPAWN_WORKER_SH"
        return 1
    fi

    # Collect all digests first
    declare -A digests
    local all_found=true

    for profile in "${WORKER_PROFILES[@]}"; do
        log_info "Getting digest for ${profile}..."
        local digest
        if digest=$(get_image_digest "$profile"); then
            digests["$profile"]="$digest"
            log_success "  ${profile}: ${digest:0:19}..."
        else
            log_error "  ${profile}: NOT FOUND"
            all_found=false
        fi
    done

    if [[ "$all_found" == "false" ]]; then
        log_error "Cannot update: some images are missing"
        log_info "Pull missing images first, then retry"
        return 1
    fi

    echo ""
    log_info "Creating backup: ${SPAWN_WORKER_SH}.bak"
    cp "$SPAWN_WORKER_SH" "${SPAWN_WORKER_SH}.bak"

    # Generate new ALLOWED_IMAGES block
    local new_block="ALLOWED_IMAGES=(
    # SHA digests provide immutable image references for supply chain security
    # Updated: $(date +%Y-%m-%d)
    # To update: ./scripts/update-image-shas.sh --update"

    for profile in "${WORKER_PROFILES[@]}"; do
        local image="${REGISTRY}:${profile}-${VERSION}"
        local digest="${digests[$profile]}"
        new_block+=$'\n'"    \"${image}@${digest}\""
    done

    new_block+=$'\n'")"

    # Find and replace ALLOWED_IMAGES block
    # This is a multi-line replacement, so we use a different approach
    local temp_file
    temp_file=$(mktemp)

    awk -v new_block="$new_block" '
    /^ALLOWED_IMAGES=\(/ {
        # Print the new block
        print new_block
        # Skip until closing parenthesis
        while (!/^\)/) {
            if (!getline) break
        }
        next
    }
    { print }
    ' "$SPAWN_WORKER_SH" > "$temp_file"

    mv "$temp_file" "$SPAWN_WORKER_SH"
    chmod +x "$SPAWN_WORKER_SH"

    log_success "Updated ALLOWED_IMAGES with SHA digests"
    echo ""
    log_info "Changes:"
    grep -A $((${#WORKER_PROFILES[@]} + 4)) 'ALLOWED_IMAGES=(' "$SPAWN_WORKER_SH"
    echo ""
    log_info "Next steps:"
    log_info "  1. Review changes: git diff $SPAWN_WORKER_SH"
    log_info "  2. Test: spawn a worker to verify allowlist works"
    log_info "  3. Commit: git add $SPAWN_WORKER_SH && git commit -m 'security: Update image allowlist with SHA digests'"
}

# Main execution
main() {
    parse_args "$@"

    case "$MODE" in
        check)
            check_allowlist
            ;;
        update)
            update_allowlist
            ;;
        show)
            show_digests
            ;;
    esac
}

main "$@"
