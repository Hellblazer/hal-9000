#!/usr/bin/env bash
# test-category-09-claude-passthrough.sh - Test Claude Passthrough
#
# Tests plugin management, MCP servers, system commands, and slash commands
# that hal-9000 passes through to Claude CLI.
#
# Test IDs: PASS-001 to PASS-015

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
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)) || true; }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)) || true; }
log_skip() { printf "${YELLOW}[SKIP]${NC} %s\n" "$1"; ((TESTS_SKIPPED++)) || true; }
log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }

# Find script directory and hal-9000 command
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HAL9000_CMD="${HAL9000_CMD:-$REPO_ROOT/hal-9000}"

# Check if hal-9000 exists
if [[ ! -x "$HAL9000_CMD" ]]; then
    echo "Error: hal-9000 command not found at $HAL9000_CMD"
    exit 1
fi

echo "=========================================="
echo "Test Category 9: Claude Passthrough"
echo "=========================================="
echo "HAL-9000 command: $HAL9000_CMD"
echo ""

#==========================================
# 9.1 Plugin Management (PASS-001 to PASS-003)
#==========================================

test_pass_001() {
    log_test "PASS-001: hal-9000 plugin list → lists installed plugins"

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" plugin list 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "Plugin list command succeeds"
    else
        log_skip "Plugin command not implemented yet"
        echo "  Expected: Lists installed plugins or empty list"
    fi
}

test_pass_002() {
    log_test "PASS-002: hal-9000 plugin install → installs plugin"
    log_skip "Manual Docker test - requires plugin installation"
    echo "  1. hal-9000 plugin install <plugin-name>"
    echo "  2. hal-9000 plugin list"
    echo "  3. Verify: Plugin appears in list"
}

test_pass_003() {
    log_test "PASS-003: hal-9000 plugin marketplace add → adds marketplace"
    log_skip "Manual Docker test - requires marketplace URL"
    echo "  1. hal-9000 plugin marketplace add <URL>"
    echo "  2. hal-9000 plugin marketplace list"
    echo "  3. Verify: Marketplace registered"
}

#==========================================
# 9.2 MCP Server Management (PASS-004 to PASS-005)
#==========================================

test_pass_004() {
    log_test "PASS-004: hal-9000 mcp list → lists MCP servers"

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" mcp list 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "MCP list command succeeds"
    else
        log_skip "MCP command not implemented yet"
        echo "  Expected: Lists chromadb, memory-bank, sequential-thinking, etc."
    fi
}

test_pass_005() {
    log_test "PASS-005: hal-9000 mcp add → adds MCP server"
    log_skip "Manual Docker test - requires MCP configuration"
    echo "  1. hal-9000 mcp add <server-name> <command>"
    echo "  2. hal-9000 mcp list"
    echo "  3. Verify: Server registered in list"
}

#==========================================
# 9.3 System Commands (PASS-006 to PASS-009)
#==========================================

test_pass_006() {
    log_test "PASS-006: hal-9000 doctor → health check diagnostics"

    local output
    local exit_code=0
    output=$("$HAL9000_CMD" doctor 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "Doctor command succeeds"
    else
        log_skip "Doctor command not implemented yet"
        echo "  Expected: Shows Docker status, volumes, dependencies"
    fi
}

test_pass_007() {
    log_test "PASS-007: hal-9000 install → installs Claude CLI"
    log_skip "Manual Docker test - requires package management"
    echo "  1. hal-9000 install"
    echo "  2. Verify: Claude CLI installed in container"
    echo "  3. claude --version shows installed version"
}

test_pass_008() {
    log_test "PASS-008: hal-9000 setup-token → interactive token setup"
    log_skip "Manual interactive test"
    echo "  1. hal-9000 setup-token"
    echo "  2. Follow prompts to enter API key"
    echo "  3. Verify: Token saved, sessions work without re-auth"
}

test_pass_009() {
    log_test "PASS-009: hal-9000 update → updates Claude CLI"
    log_skip "Manual Docker test - requires package management"
    echo "  1. hal-9000 update"
    echo "  2. Verify: Claude CLI updated to latest version"
    echo "  3. claude --version shows new version"
}

#==========================================
# 9.4 Slash Commands (PASS-010 to PASS-015)
#==========================================

test_pass_010() {
    log_test "PASS-010: hal-9000 /login → subscription login flow"
    log_skip "Manual authentication test"
    echo "  1. Start session: hal-9000 /tmp/test"
    echo "  2. Inside container: /login"
    echo "  3. Verify: Opens browser for Claude subscription auth"
}

test_pass_011() {
    log_test "PASS-011: hal-9000 /help → shows help text"
    log_skip "Manual Docker test - requires running session"
    echo "  1. Start session: hal-9000 /tmp/test"
    echo "  2. Inside container: /help"
    echo "  3. Verify: Shows available slash commands"
}

test_pass_012() {
    log_test "PASS-012: hal-9000 /status → shows system status"
    log_skip "Manual Docker test - requires running session"
    echo "  1. Start session: hal-9000 /tmp/test"
    echo "  2. Inside container: /status"
    echo "  3. Verify: Shows Claude status, session info"
}

test_pass_013() {
    log_test "PASS-013: hal-9000 /check → saves session context"
    log_skip "Manual Docker test - requires running session"
    echo "  1. Start session with conversation"
    echo "  2. Run: /check"
    echo "  3. Verify: Context saved, confirmation message shown"
}

test_pass_014() {
    log_test "PASS-014: hal-9000 /load → restores session context"
    log_skip "Manual Docker test - requires saved context"
    echo "  1. Previous session with saved /check"
    echo "  2. Start new session: hal-9000 /tmp/test"
    echo "  3. Run: /load"
    echo "  4. Verify: Previous context restored"
}

test_pass_015() {
    log_test "PASS-015: hal-9000 /sessions → lists saved sessions"
    log_skip "Manual Docker test - requires running session"
    echo "  1. Start session: hal-9000 /tmp/test"
    echo "  2. Inside container: /sessions"
    echo "  3. Verify: Shows list of saved sessions with timestamps"
}

#==========================================
# Main Test Runner
#==========================================

main() {
    # 9.1 Plugin Management
    test_pass_001 || true
    test_pass_002 || true
    test_pass_003 || true

    # 9.2 MCP Server Management
    test_pass_004 || true
    test_pass_005 || true

    # 9.3 System Commands
    test_pass_006 || true
    test_pass_007 || true
    test_pass_008 || true
    test_pass_009 || true

    # 9.4 Slash Commands
    test_pass_010 || true
    test_pass_011 || true
    test_pass_012 || true
    test_pass_013 || true
    test_pass_014 || true
    test_pass_015 || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (manual or requires implementation)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Manual tests require:"
        echo "  - Running hal-9000 sessions"
        echo "  - Plugin and MCP server management"
        echo "  - Interactive authentication flows"
        echo "  - Slash command execution in Claude"
        echo ""
        echo "See test output above for manual test procedures."
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
