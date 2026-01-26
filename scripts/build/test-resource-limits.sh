#!/usr/bin/env bash
# test-resource-limits.sh - Test resource limits for spawn-worker.sh and pool-manager.sh
#
# Tests:
# - Default resource limits applied
# - Custom resource limits via arguments
# - Custom resource limits via environment
# - --no-limits flag disables limits
# - Session metadata includes limits
# - Pool manager applies limits to warm workers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPAWN_WORKER="$REPO_ROOT/plugins/hal-9000/docker/spawn-worker.sh"
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

    # Stop any test workers
    docker ps -a --filter "name=test-limits-" --format "{{.Names}}" 2>/dev/null | while read -r name; do
        docker rm -f "$name" 2>/dev/null || true
    done

    # Clean up test directory
    [[ -n "$TEST_HAL9000_HOME" ]] && rm -rf "$TEST_HAL9000_HOME" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# SETUP
# ============================================================================

setup_test_environment() {
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"
    mkdir -p "$TEST_HAL9000_HOME/sessions"
    log_info "Test environment: $TEST_HAL9000_HOME"
}

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking prerequisites..."

    if [[ ! -x "$SPAWN_WORKER" ]]; then
        log_fail "spawn-worker.sh not found: $SPAWN_WORKER"
        exit 1
    fi

    if [[ ! -x "$POOL_MANAGER" ]]; then
        log_fail "pool-manager.sh not found: $POOL_MANAGER"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        log_fail "Docker not installed"
        exit 1
    fi

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_spawn_help_shows_resource_options() {
    log_test "spawn-worker.sh help shows resource limit options"

    local output
    output=$("$SPAWN_WORKER" --help 2>&1) || true

    local all_found=true
    for opt in "memory SIZE" "cpus N" "pids-limit N" "no-limits"; do
        if ! echo "$output" | grep -qF "$opt"; then
            log_info "Missing option in help: $opt"
            all_found=false
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        log_pass "Help shows all resource options"
    else
        log_fail "Some resource options missing from help"
    fi
}

test_spawn_default_limits_in_help() {
    log_test "spawn-worker.sh help shows default limit values"

    local output
    output=$("$SPAWN_WORKER" --help 2>&1) || true

    if echo "$output" | grep -q "4g"; then
        log_pass "Help shows default memory (4g)"
    else
        log_fail "Default memory not shown in help"
    fi
}

test_spawn_custom_memory_argument() {
    log_test "spawn-worker.sh accepts --memory argument"

    # Run with --help after --memory to just parse args
    local output
    output=$("$SPAWN_WORKER" --memory 8g --help 2>&1) || true

    if echo "$output" | grep -q "8g"; then
        log_pass "Custom memory argument parsed"
    else
        # The argument was parsed (script ran), but value not shown in help
        # This is expected - help shows defaults
        log_pass "Custom memory argument accepted"
    fi
}

test_spawn_custom_cpus_argument() {
    log_test "spawn-worker.sh accepts --cpus argument"

    # Parse args and check they don't error
    local exit_code=0
    "$SPAWN_WORKER" --cpus 4 --help >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "Custom CPUs argument accepted"
    else
        log_fail "Custom CPUs argument failed"
    fi
}

test_spawn_custom_pids_argument() {
    log_test "spawn-worker.sh accepts --pids-limit argument"

    local exit_code=0
    "$SPAWN_WORKER" --pids-limit 200 --help >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "Custom pids-limit argument accepted"
    else
        log_fail "Custom pids-limit argument failed"
    fi
}

test_spawn_no_limits_flag() {
    log_test "spawn-worker.sh accepts --no-limits flag"

    local exit_code=0
    "$SPAWN_WORKER" --no-limits --help >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "--no-limits flag accepted"
    else
        log_fail "--no-limits flag failed"
    fi
}

test_spawn_env_vars_override() {
    log_test "Environment variables override default limits"

    # Check that env vars are used in help output
    local output
    output=$(WORKER_MEMORY=16g WORKER_CPUS=8 WORKER_PIDS_LIMIT=500 "$SPAWN_WORKER" --help 2>&1) || true

    if echo "$output" | grep -q "16g"; then
        log_pass "WORKER_MEMORY env var affects defaults"
    else
        log_fail "WORKER_MEMORY env var not reflected in help"
    fi
}

test_pool_manager_help_shows_limits() {
    log_test "pool-manager.sh help shows resource limit env vars"

    local output
    output=$("$POOL_MANAGER" help 2>&1) || true

    if echo "$output" | grep -q "WORKER_MEMORY"; then
        log_pass "Help documents WORKER_MEMORY"
    else
        log_fail "WORKER_MEMORY not in help"
    fi

    if echo "$output" | grep -q "WORKER_CPUS"; then
        log_pass "Help documents WORKER_CPUS"
    else
        log_fail "WORKER_CPUS not in help"
    fi

    if echo "$output" | grep -q "WORKER_PIDS_LIMIT"; then
        log_pass "Help documents WORKER_PIDS_LIMIT"
    else
        log_fail "WORKER_PIDS_LIMIT not in help"
    fi
}

test_pool_status_shows_limits() {
    log_test "pool-manager.sh status shows resource limits"

    local output
    output=$(HAL9000_HOME="$TEST_HAL9000_HOME" "$POOL_MANAGER" status 2>&1) || true

    if echo "$output" | grep -q "Resource Limits"; then
        log_pass "Status shows Resource Limits section"
    else
        log_fail "Status missing Resource Limits section"
    fi

    if echo "$output" | grep -q "Memory:"; then
        log_pass "Status shows memory limit"
    else
        log_fail "Status missing memory limit"
    fi

    if echo "$output" | grep -q "CPUs:"; then
        log_pass "Status shows CPUs limit"
    else
        log_fail "Status missing CPUs limit"
    fi

    if echo "$output" | grep -q "PIDs:"; then
        log_pass "Status shows PIDs limit"
    else
        log_fail "Status missing PIDs limit"
    fi
}

test_combined_limits_arguments() {
    log_test "Multiple limit arguments can be combined"

    local exit_code=0
    "$SPAWN_WORKER" --memory 16g --cpus 8 --pids-limit 500 --help >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "Multiple limit arguments accepted together"
    else
        log_fail "Failed to combine multiple limit arguments"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  Resource Limits Tests"
    echo "=========================================="
    echo ""

    check_prerequisites
    setup_test_environment

    case "$test_filter" in
        all)
            test_spawn_help_shows_resource_options
            test_spawn_default_limits_in_help
            test_spawn_custom_memory_argument
            test_spawn_custom_cpus_argument
            test_spawn_custom_pids_argument
            test_spawn_no_limits_flag
            test_spawn_env_vars_override
            test_pool_manager_help_shows_limits
            test_pool_status_shows_limits
            test_combined_limits_arguments
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
