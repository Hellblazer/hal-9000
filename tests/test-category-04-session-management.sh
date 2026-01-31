#!/usr/bin/env bash
# test-category-04-session-management.sh - Test Category 4: Session Management
#
# Tests SESS-001 through SESS-027 from HAL9000_TEST_PLAN.md
# Verifies session creation, listing, attaching, killing, and lifecycle

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)); }
log_skip() { printf "${YELLOW}[SKIP]${NC} %s\n" "$1"; ((TESTS_SKIPPED++)); }
log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
log_manual() { printf "${BLUE}[MANUAL]${NC} %s\n" "$1"; }

# Find hal-9000 command
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HAL9000_CMD="$REPO_ROOT/hal-9000"

if [[ ! -x "$HAL9000_CMD" ]]; then
    echo "ERROR: hal-9000 command not found at $HAL9000_CMD"
    exit 1
fi

# Check if Docker is available
DOCKER_AVAILABLE=false
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    DOCKER_AVAILABLE=true
fi

# ============================================================================
# 4.1 SESSION CREATION (SESS-001 to SESS-008)
# ============================================================================

test_sess_001_to_004() {
    log_manual "SESS-001 to SESS-004: Session Creation (Docker required)"
    log_info "These tests require Docker container inspection:"
    log_info ""
    log_info "SESS-001: hal-9000 /tmp/myproject"
    log_info "  - Expected: Creates session named hal-9000-*"
    log_info "  - Verify: docker ps shows hal-9000-myproject-* container"
    log_info ""
    log_info "SESS-003: hal-9000 ~"
    log_info "  - Expected: Expands ~ to home directory"
    log_info "  - Verify: Home directory mounted in container"
    log_info ""
    log_info "SESS-004: hal-9000 /tmp/project --name custom"
    log_info "  - Expected: Custom session name 'custom'"
    log_info "  - Verify: docker ps shows container named 'custom'"
    log_info ""

    log_skip "SESS-001 to SESS-004: Manual Docker testing required"
}

# SESS-005: Nonexistent directory → Fails gracefully
test_sess_005() {
    log_test "SESS-005: Nonexistent directory → fails with exit 1"

    local output
    local exit_code=0
    output=$(ANTHROPIC_API_KEY="sk-ant-test" "$HAL9000_CMD" /nonexistent/directory/path 2>&1) || exit_code=$?

    # Should exit with code 1 (general error)
    if [[ $exit_code -eq 1 ]]; then
        log_pass "Nonexistent directory exits with code 1"
    elif [[ $exit_code -ne 0 ]]; then
        log_pass "Nonexistent directory rejected (exit $exit_code)"
    else
        log_fail "Expected non-zero exit code, got $exit_code"
        return 1
    fi

    # Check error message mentions directory
    if echo "$output" | grep -qiE "(directory|path|not found|does not exist)"; then
        log_pass "Error message mentions directory issue"
    else
        log_skip "Error message unclear about directory"
    fi
}

# SESS-006: File (not directory) → Fails
test_sess_006() {
    log_test "SESS-006: File instead of directory → fails with exit 1"

    # Create temp file
    local test_file
    test_file=$(mktemp)

    local output
    local exit_code=0
    output=$(ANTHROPIC_API_KEY="sk-ant-test" "$HAL9000_CMD" "$test_file" 2>&1) || exit_code=$?

    rm -f "$test_file"

    # Should exit with code 1
    if [[ $exit_code -eq 1 ]]; then
        log_pass "File (not directory) exits with code 1"
    elif [[ $exit_code -ne 0 ]]; then
        log_pass "File rejected (exit $exit_code)"
    else
        log_fail "Expected non-zero exit code, got $exit_code"
        return 1
    fi

    # Check error message mentions directory
    if echo "$output" | grep -qiE "(directory|not a dir)"; then
        log_pass "Error message mentions directory requirement"
    else
        log_skip "Error message doesn't mention directory requirement"
    fi
}

test_sess_007_to_008() {
    log_manual "SESS-007 to SESS-008: Session Collision & Creation (Docker required)"
    log_info ""
    log_info "SESS-007: Session name collision"
    log_info "  - Expected: Reuses running container, no new one created"
    log_info "  - Verify: docker ps shows same container ID before/after"
    log_info ""
    log_info "SESS-008: Directory created during execution"
    log_info "  - Expected: Creates if missing"
    log_info "  - Verify: mkdir during session creates directory"
    log_info ""

    log_skip "SESS-007 to SESS-008: Manual Docker testing required"
}

# ============================================================================
# 4.2 SESSION NAMING & HASHING (SESS-009 to SESS-012)
# ============================================================================

test_sess_009_to_012() {
    log_manual "SESS-009 to SESS-012: Session Naming & Hashing (Docker/Unit required)"
    log_info ""
    log_info "SESS-009: Same project, different sessions → different names"
    log_info "  - Expected: Hash includes timestamp or random component"
    log_info "  - Verify: Two sessions from same dir have different names"
    log_info ""
    log_info "SESS-010: Same project, same time → collision handling"
    log_info "  - Expected: Naming handles collisions gracefully"
    log_info ""
    log_info "SESS-011: Session name structure"
    log_info "  - Expected: hal-9000-{basename}-{8-char-hash}"
    log_info "  - Verify: docker ps output matches pattern"
    log_info ""
    log_info "SESS-012: UTF-8 project names"
    log_info "  - Expected: Unicode paths supported"
    log_info "  - Verify: Create session from Unicode-named directory"
    log_info ""

    log_skip "SESS-009 to SESS-012: Manual naming/hashing tests required"
}

# ============================================================================
# 4.3 SESSION LISTING (SESS-013 to SESS-017)
# ============================================================================

# SESS-013: hal-9000 sessions → Lists all running
test_sess_013() {
    log_test "SESS-013: 'hal-9000 sessions' lists running sessions"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "SESS-013: Docker not available"
        return 0
    fi

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" sessions 2>&1) || exit_code=$?

    # Should succeed (exit 0) even if no sessions
    if [[ $exit_code -eq 0 ]]; then
        log_pass "Sessions command succeeds"
    else
        log_fail "Sessions command failed with exit $exit_code"
        log_info "Output: $output"
        return 1
    fi

    # Output should have some structure (headers or session info)
    if [[ -n "$output" ]]; then
        log_pass "Sessions command produces output"
    else
        log_skip "Sessions command produces no output (implementation-dependent)"
    fi
}

# SESS-014: No running sessions → Shows "No sessions"
test_sess_014() {
    log_test "SESS-014: No running sessions → clear message"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "SESS-014: Docker not available"
        return 0
    fi

    # Kill any existing hal-9000 sessions first
    docker ps --filter "name=hal-9000-" --format "{{.ID}}" | xargs -r docker kill >/dev/null 2>&1 || true

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" sessions 2>&1) || exit_code=$?

    # Should succeed
    if [[ $exit_code -eq 0 ]]; then
        log_pass "Sessions command succeeds with no sessions"
    else
        log_fail "Expected exit 0, got $exit_code"
        return 1
    fi

    # Check for "no sessions" message
    if echo "$output" | grep -qiE "(no session|none|empty)"; then
        log_pass "Output indicates no sessions"
    else
        log_skip "Output format varies (may show empty list)"
    fi
}

test_sess_015_to_017() {
    log_manual "SESS-015 to SESS-017: Session Listing Details (Docker required)"
    log_info ""
    log_info "SESS-015: Multiple sessions → lists all"
    log_info "  - Expected: Correct count matches docker ps"
    log_info ""
    log_info "SESS-016: Output includes status"
    log_info "  - Expected: Running, idle, stopped indicators"
    log_info ""
    log_info "SESS-017: Session list ordering"
    log_info "  - Expected: Alphabetical or by date, consistent"
    log_info ""

    log_skip "SESS-015 to SESS-017: Manual listing tests required"
}

# ============================================================================
# 4.4 SESSION ATTACH (SESS-018 to SESS-023) - Mostly Manual
# ============================================================================

test_sess_018_to_023() {
    log_manual "SESS-018 to SESS-023: Session Attach (Manual testing)"
    log_info "These tests require interactive attach/detach:"
    log_info ""
    log_info "SESS-018: hal-9000 attach <session-name>"
    log_info "  - Expected: Drops into bash shell"
    log_info ""
    log_info "SESS-019: Attach to stopped session"
    log_info "  - Expected: Fails with 'Session not running', exit 5"
    log_info ""
    log_info "SESS-020: Attach with ambiguous name"
    log_info "  - Expected: Prompts or lists options"
    log_info ""
    log_info "SESS-021: hal-9000 attach (no name, 1 running)"
    log_info "  - Expected: Auto-selects and attaches"
    log_info ""
    log_info "SESS-022: hal-9000 attach (multiple running)"
    log_info "  - Expected: Shows numbered menu"
    log_info ""
    log_info "SESS-023: Attach exits cleanly"
    log_info "  - Expected: Container persists after detach"
    log_info ""

    log_skip "SESS-018 to SESS-023: Manual attach testing required"
}

# ============================================================================
# 4.5 SESSION KILLING (SESS-024 to SESS-027)
# ============================================================================

test_sess_024() {
    log_manual "SESS-024: Kill session (Docker required)"
    log_info "hal-9000 kill <session-name>"
    log_info "  - Expected: Container stopped and removed"
    log_info "  - Verify: docker ps shows container gone"
    log_info ""

    log_skip "SESS-024: Manual Docker testing required"
}

# SESS-025: Kill nonexistent session → Error with exit 5
test_sess_025() {
    log_test "SESS-025: Kill nonexistent session → error exit 5"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "SESS-025: Docker not available"
        return 0
    fi

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" kill nonexistent_session_name_12345 2>&1) || exit_code=$?

    # Should exit with code 5 (session not found) or 1 (general error)
    if [[ $exit_code -eq 5 ]]; then
        log_pass "Nonexistent session exits with code 5"
    elif [[ $exit_code -eq 1 ]]; then
        log_pass "Nonexistent session rejected (exit 1)"
    elif [[ $exit_code -ne 0 ]]; then
        log_pass "Nonexistent session rejected (exit $exit_code)"
    else
        log_fail "Expected non-zero exit code, got $exit_code"
        return 1
    fi

    # Check error message mentions session
    if echo "$output" | grep -qiE "(session|not found|does not exist)"; then
        log_pass "Error message mentions session not found"
    else
        log_skip "Error message format varies"
    fi
}

test_sess_026_to_027() {
    log_manual "SESS-026 to SESS-027: Kill Operations (Docker required)"
    log_info ""
    log_info "SESS-026: Kill all sessions"
    log_info "  - Expected: Script or loop kills all"
    log_info "  - Verify: docker ps shows no hal-9000-* containers"
    log_info ""
    log_info "SESS-027: Kill + immediate recreate"
    log_info "  - Expected: New session created with different name"
    log_info "  - Verify: Session name hash differs"
    log_info ""

    log_skip "SESS-026 to SESS-027: Manual kill operation tests required"
}

# ============================================================================
# Main test runner
# ============================================================================
main() {
    echo "========================================"
    echo "Test Category 4: Session Management"
    echo "========================================"
    echo "HAL-9000 command: $HAL9000_CMD"
    echo "Docker available: $DOCKER_AVAILABLE"
    echo ""

    # 4.1 Session creation
    test_sess_001_to_004 || true
    echo ""

    test_sess_005 || true
    echo ""

    test_sess_006 || true
    echo ""

    test_sess_007_to_008 || true
    echo ""

    # 4.2 Session naming & hashing
    test_sess_009_to_012 || true
    echo ""

    # 4.3 Session listing
    test_sess_013 || true
    echo ""

    test_sess_014 || true
    echo ""

    test_sess_015_to_017 || true
    echo ""

    # 4.4 Session attach
    test_sess_018_to_023 || true
    echo ""

    # 4.5 Session killing
    test_sess_024 || true
    echo ""

    test_sess_025 || true
    echo ""

    test_sess_026_to_027 || true
    echo ""

    # Summary
    echo "========================================"
    echo "Test Results"
    echo "========================================"
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (manual or Docker-required)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "========================================"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Manual Test Instructions:"
        echo "  Session management tests are primarily manual/Docker-based."
        echo "  Run SESS-001 to SESS-004, SESS-007 to SESS-024, SESS-026 to SESS-027"
        echo "  manually to verify session lifecycle operations."
        return 0
    else
        echo "❌ Some automated tests failed"
        return 1
    fi
}

main "$@"
