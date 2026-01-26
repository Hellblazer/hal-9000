#!/usr/bin/env bash
# test-pool-manager.sh - Test pool-manager.sh functionality
#
# Tests:
# - Help shows usage
# - Status command works
# - Scale command works
# - Warm worker creation
# - Cleanup functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POOL_MANAGER="$REPO_ROOT/plugins/hal-9000/docker/pool-manager.sh"

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

    # Stop any test warm workers
    docker ps -a --filter "name=hal9000-warm-" --format "{{.Names}}" 2>/dev/null | while read -r name; do
        docker rm -f "$name" 2>/dev/null || true
    done

    # Stop pool manager if running
    [[ -n "$TEST_HAL9000_HOME" ]] && {
        local pid_file="$TEST_HAL9000_HOME/pool/pool-manager.pid"
        if [[ -f "$pid_file" ]]; then
            kill "$(cat "$pid_file")" 2>/dev/null || true
        fi
        rm -rf "$TEST_HAL9000_HOME" 2>/dev/null || true
    }
}

trap cleanup EXIT

# ============================================================================
# SETUP
# ============================================================================

setup_test_environment() {
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"
    mkdir -p "$TEST_HAL9000_HOME/pool/workers"
    log_info "Test environment: $TEST_HAL9000_HOME"
}

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking prerequisites..."

    if [[ ! -x "$POOL_MANAGER" ]]; then
        log_fail "pool-manager.sh not found: $POOL_MANAGER"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        log_fail "Docker not installed"
        exit 1
    fi

    if ! docker ps &>/dev/null; then
        log_fail "Docker daemon not running"
        exit 1
    fi

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_help_shows_usage() {
    log_test "pool-manager.sh help shows usage"

    local output
    output=$("$POOL_MANAGER" help 2>&1) || true

    if echo "$output" | grep -q "Usage: pool-manager.sh"; then
        log_pass "Help shows usage"
    else
        log_fail "Help output incorrect"
    fi
}

test_help_shows_commands() {
    log_test "Help shows all commands"

    local output
    output=$("$POOL_MANAGER" help 2>&1) || true

    local all_found=true
    for cmd in start stop status scale cleanup warm; do
        if ! echo "$output" | grep -q "$cmd"; then
            log_info "Missing command: $cmd"
            all_found=false
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        log_pass "All commands documented"
    else
        log_fail "Some commands missing from help"
    fi
}

test_status_works_empty() {
    log_test "Status works with no workers"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" status 2>&1) || true

    if echo "$output" | grep -q "Worker Pool Status"; then
        log_pass "Status command works"
    else
        log_fail "Status command failed"
        echo "Output: $output"
    fi
}

test_status_shows_counts() {
    log_test "Status shows worker counts"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" status 2>&1) || true

    if echo "$output" | grep -q "Warm.*:"; then
        log_pass "Status shows warm count"
    else
        log_fail "Status missing warm count"
    fi

    if echo "$output" | grep -q "Busy.*:"; then
        log_pass "Status shows busy count"
    else
        log_fail "Status missing busy count"
    fi
}

test_status_shows_config() {
    log_test "Status shows configuration"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" status 2>&1) || true

    if echo "$output" | grep -q "Min warm:"; then
        log_pass "Status shows min warm config"
    else
        log_fail "Status missing min warm config"
    fi

    if echo "$output" | grep -q "Idle timeout:"; then
        log_pass "Status shows idle timeout"
    else
        log_fail "Status missing idle timeout"
    fi
}

test_scale_validates_input() {
    log_test "Scale validates input"

    # Test with invalid input
    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" scale abc 2>&1) || true

    if echo "$output" | grep -qi "invalid"; then
        log_pass "Scale rejects invalid input"
    else
        log_fail "Scale should reject non-numeric input"
    fi
}

test_scale_respects_max() {
    log_test "Scale respects max limit"

    # Test with value exceeding max
    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" MAX_WARM_WORKERS=3 "$POOL_MANAGER" scale 10 2>&1) || true

    if echo "$output" | grep -q "exceeds max\|capping"; then
        log_pass "Scale respects max limit"
    else
        log_fail "Scale should warn about exceeding max"
    fi
}

test_cleanup_works() {
    log_test "Cleanup command works"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" cleanup 2>&1) || true

    if echo "$output" | grep -q "cleanup\|Cleanup"; then
        log_pass "Cleanup command works"
    else
        log_fail "Cleanup command failed"
    fi
}

test_warm_creates_worker() {
    log_test "Warm command creates worker"

    # This test requires parent container running
    if ! docker ps --format '{{.Names}}' | grep -q "^hal9000-parent$"; then
        log_info "Skipping: parent container not running"
        log_pass "Warm command (skipped - no parent)"
        return 0
    fi

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" warm 2>&1) || true

    if echo "$output" | grep -q "Created warm worker\|hal9000-warm-"; then
        log_pass "Warm command creates worker"
        # Cleanup the created worker
        local worker_name
        worker_name=$(echo "$output" | grep -oE "hal9000-warm-[0-9]+-[0-9]+-[0-9]+" | head -1)
        [[ -n "$worker_name" ]] && docker rm -f "$worker_name" 2>/dev/null || true
    else
        log_fail "Warm command failed"
        echo "Output: $output"
    fi
}

test_daemon_not_running_initially() {
    log_test "Daemon shows not running initially"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" status 2>&1) || true

    if echo "$output" | grep -q "Not running"; then
        log_pass "Daemon correctly shows not running"
    else
        log_fail "Daemon status incorrect"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  Pool Manager Tests"
    echo "=========================================="
    echo ""

    check_prerequisites
    setup_test_environment

    case "$test_filter" in
        all)
            test_help_shows_usage
            test_help_shows_commands
            test_status_works_empty
            test_status_shows_counts
            test_status_shows_config
            test_scale_validates_input
            test_scale_respects_max
            test_cleanup_works
            test_warm_creates_worker
            test_daemon_not_running_initially
            ;;
        *)
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
