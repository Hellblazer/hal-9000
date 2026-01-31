#!/usr/bin/env bash
# test-category-02-setup-authentication.sh - Test Category 2: Setup & Authentication
#
# Tests AUTH-001 through AUTH-016 from HAL9000_TEST_PLAN.md
# Verifies API key setup, validation, and authentication modes

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
# 2.1 API KEY SETUP (AUTH-001 to AUTH-007) - Manual Tests
# ============================================================================

test_auth_001_to_007() {
    log_manual "AUTH-001 to AUTH-007: API Key Setup Tests (Manual)"
    log_info "These tests require interactive input and are designed for manual execution:"
    log_info ""
    log_info "AUTH-001: hal-9000 --setup (fresh env)"
    log_info "  - Should prompt for API key interactively"
    log_info ""
    log_info "AUTH-002: hal-9000 --setup (ANTHROPIC_API_KEY set)"
    log_info "  - Should detect existing key and confirm override"
    log_info ""
    log_info "AUTH-003: hal-9000 --setup with valid key (sk-ant-*)"
    log_info "  - Should accept and store key in ~/.bashrc or ~/.zshrc"
    log_info ""
    log_info "AUTH-004: hal-9000 --setup with invalid key (abc123)"
    log_info "  - Should reject with validation error and retry"
    log_info ""
    log_info "AUTH-005: Verify .bashrc persistence"
    log_info "  - Key survives new shell session"
    log_info ""
    log_info "AUTH-006: Verify .zshrc persistence (zsh only)"
    log_info "  - Key survives zsh session"
    log_info ""
    log_info "AUTH-007: Session-only key (not persisted)"
    log_info "  - Key lost after shell exit"
    log_info ""

    log_skip "AUTH-001 to AUTH-007: Manual testing required"
}

# ============================================================================
# 2.2 API KEY VALIDATION - Automated Tests
# ============================================================================

# AUTH-008: ANTHROPIC_API_KEY unset → Fails with exit 4
test_auth_008() {
    log_test "AUTH-008: ANTHROPIC_API_KEY unset → fails with guidance"

    # Clear any existing subscription credentials from volume
    docker run --rm -v hal9000-claude-home:/root/.claude alpine:latest sh -c '
        rm -f /root/.claude/.credentials.json
        rm -f /root/.claude/statsig_user_id
    ' >/dev/null 2>&1 || true

    # Create temp project dir
    local test_dir
    test_dir=$(mktemp -d)

    # Unset ANTHROPIC_API_KEY
    local output
    local exit_code=0

    # Capture both output and exit code (|| captures exit code when command fails)
    output=$(env -u ANTHROPIC_API_KEY "$HAL9000_CMD" "$test_dir" 2>&1) || exit_code=$?

    # Clean up
    rm -rf "$test_dir"

    # Check exit code is 4
    if [[ $exit_code -eq 4 ]]; then
        log_pass "Exit code 4 (missing API key)"
    else
        log_fail "Expected exit code 4, got $exit_code"
        return 1
    fi

    # Check stderr mentions --setup or authentication
    if echo "$output" | grep -qiE "(setup|authentication|api.?key)"; then
        log_pass "Error message guides user to setup"
    else
        log_fail "Error message doesn't mention setup/authentication"
        log_info "Output: $output"
        return 1
    fi
}

# AUTH-009: ANTHROPIC_API_KEY="" (empty) → Fails with exit 4
test_auth_009() {
    log_test "AUTH-009: ANTHROPIC_API_KEY empty → fails"

    # Clear any existing subscription credentials from volume
    docker run --rm -v hal9000-claude-home:/root/.claude alpine:latest sh -c '
        rm -f /root/.claude/.credentials.json
        rm -f /root/.claude/statsig_user_id
    ' >/dev/null 2>&1 || true

    local test_dir
    test_dir=$(mktemp -d)

    local output
    local exit_code=0

    # Capture both output and exit code
    output=$(ANTHROPIC_API_KEY="" "$HAL9000_CMD" "$test_dir" 2>&1) || exit_code=$?

    rm -rf "$test_dir"

    if [[ $exit_code -eq 4 ]]; then
        log_pass "Exit code 4 for empty API key"
    else
        log_fail "Expected exit code 4, got $exit_code"
        return 1
    fi
}

# AUTH-010: ANTHROPIC_API_KEY="invalid" → Rejects with exit 1
test_auth_010() {
    log_test "AUTH-010: ANTHROPIC_API_KEY invalid format → fails"

    # Clear any existing subscription credentials from volume
    docker run --rm -v hal9000-claude-home:/root/.claude alpine:latest sh -c '
        rm -f /root/.claude/.credentials.json
        rm -f /root/.claude/statsig_user_id
    ' >/dev/null 2>&1 || true

    local test_dir
    test_dir=$(mktemp -d)

    local output
    local exit_code=0

    # Capture both output and exit code
    output=$(ANTHROPIC_API_KEY="invalid123" "$HAL9000_CMD" "$test_dir" 2>&1) || exit_code=$?

    rm -rf "$test_dir"

    # Exit code should be 1 for invalid format
    if [[ $exit_code -ne 0 ]]; then
        log_pass "Non-zero exit code for invalid key format"
    else
        log_fail "Expected non-zero exit code, got $exit_code"
        return 1
    fi

    # Check error message mentions invalid format
    if echo "$output" | grep -qiE "(invalid|format|sk-ant)"; then
        log_pass "Error message mentions invalid format"
    else
        log_fail "Error message doesn't explain invalid format"
        log_info "Output: $output"
        return 1
    fi
}

# AUTH-011: ANTHROPIC_API_KEY=correct → Key passed to container
test_auth_011() {
    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "AUTH-011: Docker not available"
        return 0
    fi

    log_test "AUTH-011: Valid API key passed to container via -e"

    # This test requires actually launching a container
    # For now, we'll verify the command would work by checking the script logic
    log_info "This test requires Docker container inspection"
    log_info "Verify: docker inspect <container> shows ANTHROPIC_API_KEY env var"

    log_skip "AUTH-011: Requires full Docker integration test"
}

# AUTH-012: Key starts with "sk-ant-" → Accepted as valid
test_auth_012() {
    log_test "AUTH-012: API key with sk-ant- prefix accepted"

    local test_dir
    test_dir=$(mktemp -d)

    # Use a fake but valid-format key
    local fake_key="sk-ant-api03-test123456789012345678901234567890123456789012345678901234567890123456789012345678901234"

    # Run with --shell to avoid actually launching Claude
    local output
    local exit_code=0

    # The command should start validating and attempting to launch
    # We'll check if it gets past the API key validation step
    # Use timeout to prevent hanging (timeout exits 124 if command times out)
    output=$(timeout 5 ANTHROPIC_API_KEY="$fake_key" "$HAL9000_CMD" --shell "$test_dir" 2>&1) || exit_code=$?

    rm -rf "$test_dir"

    # If the key format was rejected, we'd see an error early
    # If it proceeded to Docker checks, the key was accepted
    if echo "$output" | grep -qiE "(invalid.*key|invalid.*format)" || [[ $exit_code -eq 4 ]]; then
        log_fail "Valid sk-ant- key was rejected"
        log_info "Output: $output"
        return 1
    else
        log_pass "sk-ant- prefixed key accepted (proceeded past validation)"
    fi
}

# ============================================================================
# 2.3 SUBSCRIPTION LOGIN (AUTH-013 to AUTH-016) - Manual/Docker Tests
# ============================================================================

test_auth_013_to_016() {
    log_manual "AUTH-013 to AUTH-016: Subscription Login Tests (Manual)"
    log_info "These tests require Claude authentication and Docker volumes:"
    log_info ""
    log_info "AUTH-013: hal-9000 /login (no API key)"
    log_info "  - Should trigger Claude subscription login flow"
    log_info ""
    log_info "AUTH-014: Credentials persist to hal9000-claude-session volume"
    log_info "  - After login, volume contains auth data"
    log_info ""
    log_info "AUTH-015: Subsequent invocations use cached credentials"
    log_info "  - No re-login required for new sessions"
    log_info ""
    log_info "AUTH-016: API key takes precedence over subscription"
    log_info "  - When both configured, API key is used"
    log_info ""

    log_skip "AUTH-013 to AUTH-016: Manual testing required"
}

# ============================================================================
# Main test runner
# ============================================================================
main() {
    echo "=========================================="
    echo "Test Category 2: Setup & Authentication"
    echo "=========================================="
    echo "HAL-9000 command: $HAL9000_CMD"
    echo "Docker available: $DOCKER_AVAILABLE"
    echo ""

    # Manual tests (informational)
    test_auth_001_to_007 || true
    echo ""

    # Automated validation tests
    test_auth_008 || true
    echo ""

    test_auth_009 || true
    echo ""

    test_auth_010 || true
    echo ""

    test_auth_011 || true
    echo ""

    test_auth_012 || true
    echo ""

    # Manual/Docker tests (informational)
    test_auth_013_to_016 || true
    echo ""

    # Summary
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (manual or Docker-required)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Manual Test Instructions:"
        echo "  Run each AUTH-001 to AUTH-007 and AUTH-013 to AUTH-016 manually"
        echo "  to verify interactive authentication flows."
        return 0
    else
        echo "❌ Some automated tests failed"
        return 1
    fi
}

main "$@"
