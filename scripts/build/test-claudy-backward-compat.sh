#!/usr/bin/env bash
# test-claudy-backward-compat.sh - Test backward compatibility features
#
# Tests:
# - --legacy flag is recognized
# - Deprecation warning is shown
# - Legacy mode works (single-container)
# - --legacy overrides --via-parent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDY="$REPO_ROOT/claudy"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED=0
FAILED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; PASSED=$((PASSED + 1)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAILED=$((FAILED + 1)); }
log_info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking prerequisites..."

    if [[ ! -x "$CLAUDY" ]]; then
        log_fail "claudy not found or not executable: $CLAUDY"
        exit 1
    fi

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_help_shows_legacy() {
    log_test "--help shows --legacy option"

    local output
    output=$("$CLAUDY" --help 2>&1) || true

    if echo "$output" | grep -q "\-\-legacy"; then
        log_pass "Help shows --legacy option"
    else
        log_fail "--legacy not in help output"
    fi
}

test_legacy_shows_deprecation() {
    log_test "--legacy shows deprecation warning"

    # Use --verify to avoid actually launching a container
    # Note: --verify will exit before the legacy warning in current code
    # So we test by trying to run with a non-existent directory and check output
    local output
    output=$("$CLAUDY" --legacy --verify 2>&1) || true

    if echo "$output" | grep -qi "deprecat"; then
        log_pass "Deprecation warning shown"
    else
        # Try with an invalid scenario that triggers warning before error
        output=$("$CLAUDY" --legacy /nonexistent/dir/12345 2>&1) || true
        if echo "$output" | grep -qi "deprecat"; then
            log_pass "Deprecation warning shown"
        else
            log_fail "No deprecation warning (output: ${output:0:200}...)"
        fi
    fi
}

test_legacy_mentions_migration() {
    log_test "--legacy mentions migration script"

    local output
    output=$("$CLAUDY" --legacy /nonexistent 2>&1) || true

    if echo "$output" | grep -q "migrate-to-dind"; then
        log_pass "Migration script mentioned"
    else
        log_fail "No mention of migration"
    fi
}

test_legacy_overrides_via_parent() {
    log_test "--legacy overrides --via-parent"

    local output
    output=$("$CLAUDY" --legacy --via-parent /nonexistent 2>&1) || true

    if echo "$output" | grep -q "\-\-legacy overrides"; then
        log_pass "--legacy overrides --via-parent"
    else
        # Check for "single-container" mention
        if echo "$output" | grep -q "single-container"; then
            log_pass "--legacy forces single-container mode"
        else
            log_fail "No override message"
        fi
    fi
}

test_version_shows_0_6_x() {
    log_test "Version is 0.6.x"

    local version
    version=$("$CLAUDY" --version 2>&1 | head -1) || version=""

    if echo "$version" | grep -qE "0\.[6-9]|[1-9]\.[0-9]"; then
        log_pass "Version is 0.6.x: $version"
    else
        log_fail "Unexpected version: $version"
    fi
}

test_default_mode_is_direct() {
    log_test "Default mode (no flags) uses direct container launch"

    # With a valid directory but without --via-parent, should use direct mode
    # We can test by checking the info message
    local test_dir
    test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN

    # Create minimal project
    echo "# Test" > "$test_dir/README.md"

    # Run with --verify to check prerequisites but not launch
    local output
    output=$("$CLAUDY" --verify "$test_dir" 2>&1) || true

    # Verify mode should not mention via-parent
    if echo "$output" | grep -q "via-parent"; then
        log_fail "Default mode mentions via-parent"
    else
        log_pass "Default mode is direct (not via-parent)"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  Backward Compatibility Tests"
    echo "=========================================="
    echo ""

    check_prerequisites

    case "$test_filter" in
        all)
            test_help_shows_legacy
            test_version_shows_0_6_x
            test_legacy_shows_deprecation
            test_legacy_mentions_migration
            test_legacy_overrides_via_parent
            test_default_mode_is_direct
            ;;
        *)
            # Run specific test
            if declare -f "$test_filter" >/dev/null 2>&1; then
                "$test_filter"
            else
                echo "Unknown test: $test_filter"
                exit 1
            fi
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
