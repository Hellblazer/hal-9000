#!/usr/bin/env bash
# test-claudy-rollback.sh - Test rollback script
#
# Tests:
# - Help shows usage
# - List backups works
# - Rollback with --force works

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLBACK="$REPO_ROOT/scripts/rollback-dind.sh"

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

# Test environment
TEST_HAL9000_HOME=""

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test resources..."
    [[ -n "$TEST_HAL9000_HOME" ]] && rm -rf "$TEST_HAL9000_HOME" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# SETUP
# ============================================================================

setup_test_environment() {
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    # Create mock backup
    local backup_dir="$TEST_HAL9000_HOME/backups/pre-dind-20260125-000000"
    mkdir -p "$backup_dir/chromadb"
    mkdir -p "$backup_dir/membank"
    mkdir -p "$backup_dir/plugins"

    echo "test data" > "$backup_dir/chromadb/test.db"
    echo "test data" > "$backup_dir/membank/test.md"
    echo "test data" > "$backup_dir/plugins/test.json"

    cat > "$backup_dir/manifest.json" <<EOF
{
    "created_at": "2026-01-25T00:00:00Z",
    "hal9000_home": "$TEST_HAL9000_HOME",
    "source_version": "v0.5.x",
    "target_version": "v0.6.x"
}
EOF

    log_info "Created test environment: $TEST_HAL9000_HOME"
}

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking prerequisites..."

    if [[ ! -x "$ROLLBACK" ]]; then
        log_fail "Rollback script not found or not executable: $ROLLBACK"
        exit 1
    fi

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_help_shows_usage() {
    log_test "rollback-dind.sh --help shows usage"

    local output
    output=$("$ROLLBACK" --help 2>&1) || true

    if echo "$output" | grep -q "Usage: rollback-dind.sh"; then
        log_pass "Help shows usage"
    else
        log_fail "Help output incorrect"
    fi
}

test_list_backups_finds_backup() {
    log_test "--list-backups finds test backup"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$ROLLBACK" --list-backups 2>&1) || true

    if echo "$output" | grep -q "pre-dind-20260125"; then
        log_pass "List backups finds test backup"
    else
        log_fail "Backup not found in list"
        echo "Output: $output"
    fi
}

test_list_backups_shows_contents() {
    log_test "--list-backups shows backup contents"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$ROLLBACK" --list-backups 2>&1) || true

    if echo "$output" | grep -q "chromadb"; then
        log_pass "Shows backup contents"
    else
        log_fail "Contents not shown"
    fi
}

test_rollback_stops_daemon() {
    log_test "Rollback stops daemon (if running)"

    # Run rollback with force and keep-volumes (minimal changes)
    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$ROLLBACK" --force --keep-volumes 2>&1) || true

    if echo "$output" | grep -qE "Stopping.*daemon|Daemon stopped|not running"; then
        log_pass "Rollback attempts to stop daemon"
    else
        log_fail "No daemon stop attempt"
        echo "Output: $output"
    fi
}

test_rollback_restores_from_backup() {
    log_test "Rollback restores from backup"

    # Run rollback with force
    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$ROLLBACK" --force --keep-volumes 2>&1) || true

    # Check that chromadb was restored
    if [[ -f "$TEST_HAL9000_HOME/chromadb/test.db" ]]; then
        log_pass "Data restored from backup"
    else
        log_fail "Data not restored"
    fi
}

test_rollback_shows_completion() {
    log_test "Rollback shows completion message"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$ROLLBACK" --force --keep-volumes 2>&1) || true

    if echo "$output" | grep -q "Rollback Complete"; then
        log_pass "Shows completion message"
    else
        log_fail "No completion message"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  Rollback Script Tests"
    echo "=========================================="
    echo ""

    check_prerequisites
    setup_test_environment

    case "$test_filter" in
        all)
            test_help_shows_usage
            test_list_backups_finds_backup
            test_list_backups_shows_contents
            test_rollback_stops_daemon
            test_rollback_restores_from_backup
            test_rollback_shows_completion
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
