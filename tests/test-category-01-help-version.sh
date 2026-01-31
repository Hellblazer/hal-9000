#!/usr/bin/env bash
# test-category-01-help-version.sh - Test Category 1: Help & Version Commands
#
# Tests INFO-001 through INFO-007 from HAL9000_TEST_PLAN.md
# Verifies help output, version strings, and diagnostic information

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)); }
log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }

# Find hal-9000 command
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HAL9000_CMD="$REPO_ROOT/hal-9000"

if [[ ! -x "$HAL9000_CMD" ]]; then
    echo "ERROR: hal-9000 command not found at $HAL9000_CMD"
    exit 1
fi

# ============================================================================
# INFO-001: hal-9000 --help prints comprehensive help
# ============================================================================
test_info_001() {
    log_test "INFO-001: hal-9000 --help prints comprehensive help"

    local output
    output=$("$HAL9000_CMD" --help 2>&1 || true)

    # Check for key sections (case-insensitive)
    if [[ "$output" =~ USAGE ]] || [[ "$output" =~ Usage ]] || [[ "$output" =~ usage ]]; then
        log_pass "Help contains 'Usage' section"
    else
        log_fail "Help missing 'Usage' section"
        return 1
    fi

    if [[ "$output" =~ [Oo]ptions || "$output" =~ OPTIONS ]]; then
        log_pass "Help contains 'Options' section"
    else
        log_fail "Help missing 'Options' section"
        return 1
    fi

    if [[ "$output" =~ [Ee]xamples || "$output" =~ EXAMPLES ]]; then
        log_pass "Help contains 'Examples' section"
    else
        log_fail "Help missing 'Examples' section"
        return 1
    fi

    # Check minimum length (comprehensive help should be substantial)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    if [[ "$line_count" -gt 20 ]]; then
        log_pass "Help is comprehensive ($line_count lines)"
    else
        log_fail "Help seems too brief ($line_count lines, expected >20)"
        return 1
    fi
}

# ============================================================================
# INFO-002: hal-9000 -h same as --help
# ============================================================================
test_info_002() {
    log_test "INFO-002: hal-9000 -h same as --help"

    local help_long
    help_long=$("$HAL9000_CMD" --help 2>&1 || true)

    local help_short
    help_short=$("$HAL9000_CMD" -h 2>&1 || true)

    if [[ "$help_long" == "$help_short" ]]; then
        log_pass "-h output identical to --help"
    else
        log_fail "-h output differs from --help"
        log_info "Diff length: ${#help_long} vs ${#help_short}"
        return 1
    fi
}

# ============================================================================
# INFO-003: hal-9000 --version prints version string
# ============================================================================
test_info_003() {
    log_test "INFO-003: hal-9000 --version prints version string"

    local output
    output=$("$HAL9000_CMD" --version 2>&1 || true)

    # Check for semantic version pattern (X.Y.Z)
    if [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
        local version="${BASH_REMATCH[0]}"
        log_pass "Version string matches pattern: $version"
    else
        log_fail "Version string does not match semver pattern: $output"
        return 1
    fi

    # Verify it's a clean version output (not mixed with other text)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    if [[ "$line_count" -le 3 ]]; then
        log_pass "Version output is concise ($line_count lines)"
    else
        log_fail "Version output seems verbose ($line_count lines)"
        return 1
    fi
}

# ============================================================================
# INFO-004: hal-9000 -v same as --version
# ============================================================================
test_info_004() {
    log_test "INFO-004: hal-9000 -v same as --version"

    local version_long
    version_long=$("$HAL9000_CMD" --version 2>&1 || true)

    local version_short
    version_short=$("$HAL9000_CMD" -v 2>&1 || true)

    if [[ "$version_long" == "$version_short" ]]; then
        log_pass "-v output identical to --version"
    else
        log_fail "-v output differs from --version"
        log_info "Long: $version_long"
        log_info "Short: $version_short"
        return 1
    fi
}

# ============================================================================
# INFO-005: hal-9000 --help mentions Docker
# ============================================================================
test_info_005() {
    log_test "INFO-005: hal-9000 --help | grep -i docker"

    local output
    if output=$("$HAL9000_CMD" --help 2>&1 | grep -i docker); then
        log_pass "Help mentions Docker"
        log_info "Found: $(echo "$output" | head -1 | cut -c1-60)..."
    else
        log_fail "Help does not mention Docker"
        return 1
    fi
}

# ============================================================================
# INFO-006: hal-9000 --help documents daemon subcommands
# ============================================================================
test_info_006() {
    log_test "INFO-006: hal-9000 --help | grep -i daemon"

    local output
    if output=$("$HAL9000_CMD" --help 2>&1 | grep -i daemon); then
        log_pass "Help documents daemon subcommands"
        log_info "Found: $(echo "$output" | head -1 | cut -c1-60)..."
    else
        log_fail "Help does not mention daemon"
        return 1
    fi
}

# ============================================================================
# INFO-007: hal-9000 --help documents authentication
# ============================================================================
test_info_007() {
    log_test "INFO-007: hal-9000 --help | grep -i authentication"

    local output
    # Try both "authentication" and "auth" variants
    if output=$("$HAL9000_CMD" --help 2>&1 | grep -iE "auth(entication)?"); then
        log_pass "Help documents authentication"
        log_info "Found: $(echo "$output" | head -1 | cut -c1-60)..."
    else
        log_fail "Help does not mention authentication"
        return 1
    fi
}

# ============================================================================
# Main test runner
# ============================================================================
main() {
    echo "=========================================="
    echo "Test Category 1: Help & Version Commands"
    echo "=========================================="
    echo "HAL-9000 command: $HAL9000_CMD"
    echo ""

    # Run all tests
    test_info_001 || true
    echo ""

    test_info_002 || true
    echo ""

    test_info_003 || true
    echo ""

    test_info_004 || true
    echo ""

    test_info_005 || true
    echo ""

    test_info_006 || true
    echo ""

    test_info_007 || true
    echo ""

    # Summary
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed"
        return 1
    fi
}

main "$@"
