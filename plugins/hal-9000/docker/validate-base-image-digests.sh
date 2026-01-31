#!/usr/bin/env bash
# validate-base-image-digests.sh - Validate pinned base image digests
#
# This script validates that all base image digests in Dockerfiles are
# accessible and match the expected images. Run before building to ensure
# digests haven't been revoked or corrupted.
#
# Usage:
#   ./validate-base-image-digests.sh

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[VALIDATE]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

# Test a base image digest
test_digest() {
    local image="$1"
    local digest="$2"
    local tag_ref="$3"  # Original tag for reference

    log_info "Testing $image@$digest (was $tag_ref)"

    # Try to pull by digest
    if docker pull "$image@$digest" >/dev/null 2>&1; then
        log_success "Digest valid: $image@$digest"
        ((PASSED++))
        return 0
    else
        log_fail "Digest invalid or inaccessible: $image@$digest"
        log_warn "  Original tag: $tag_ref"
        ((FAILED++))
        return 1
    fi
}

# Main validation
main() {
    echo "=========================================="
    echo "Base Image Digest Validation"
    echo "=========================================="
    echo

    log_info "Validating base image digests from Dockerfiles..."
    echo

    # debian:bookworm-slim (used in multiple Dockerfiles)
    test_digest \
        "debian" \
        "sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee" \
        "debian:bookworm-slim"

    # node:20-bookworm-slim (Dockerfile.worker)
    test_digest \
        "node" \
        "sha256:6c51af7dc83f4708aaac35991306bca8f478351cfd2bda35750a62d7efcf05bb" \
        "node:20-bookworm-slim"

    # ubuntu:24.04 (Dockerfile.test-full)
    test_digest \
        "ubuntu" \
        "sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b" \
        "ubuntu:24.04"

    # docker:27-dind (Dockerfile.test)
    test_digest \
        "docker" \
        "sha256:aa3df78ecf320f5fafdce71c659f1629e96e9de0968305fe1de670e0ca9176ce" \
        "docker:27-dind"

    echo
    echo "=========================================="
    echo "Validation Results"
    echo "=========================================="
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Total:  $((PASSED + FAILED))"
    echo "=========================================="

    if [[ $FAILED -eq 0 ]]; then
        echo "✅ All base image digests are valid!"
        return 0
    else
        echo "❌ Some digests are invalid or inaccessible"
        echo ""
        echo "Possible causes:"
        echo "- Digest was revoked by upstream registry"
        echo "- Network connectivity issue"
        echo "- Registry authentication required"
        echo ""
        echo "To update digests, run:"
        echo "  docker pull <image>:<tag>"
        echo "  docker inspect <image>:<tag> --format='{{index .RepoDigests 0}}'"
        return 1
    fi
}

main "$@"
