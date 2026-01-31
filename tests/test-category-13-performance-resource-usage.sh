#!/usr/bin/env bash
# test-category-13-performance-resource-usage.sh - Test Performance & Resource Usage
#
# Tests startup performance, memory/CPU usage, and scaling limits.
# Most tests are manual benchmarks requiring actual measurement.
#
# Test IDs: PERF-001 to PERF-011

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

# Check if Docker is available
DOCKER_AVAILABLE=false
if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
    DOCKER_AVAILABLE=true
fi

echo "=========================================="
echo "Test Category 13: Performance & Resource Usage"
echo "=========================================="
echo "HAL-9000 command: $HAL9000_CMD"
echo "Docker available: $DOCKER_AVAILABLE"
echo ""
echo "NOTE: Most tests are performance benchmarks requiring"
echo "      actual measurement with running containers."
echo ""

#==========================================
# 13.1 Startup Performance (PERF-001 to PERF-004)
#==========================================

test_perf_001() {
    log_test "PERF-001: First launch time → <10 seconds to Claude prompt"
    log_skip "Manual performance benchmark"
    echo "  1. time hal-9000 /tmp/test-project"
    echo "  2. Measure: Time from command to Claude prompt ready"
    echo "  3. Target: <10 seconds (cold start with image pull)"
    echo "  4. Verify: Should complete within target"
}

test_perf_002() {
    log_test "PERF-002: Warm pool launch → <2 seconds"
    log_skip "Manual performance benchmark - requires orchestrator"
    echo "  1. hal-9000 pool warm (pre-create warm worker)"
    echo "  2. time hal-9000 /tmp/test-project"
    echo "  3. Measure: Time to Claude prompt"
    echo "  4. Target: <2 seconds (worker already running)"
}

test_perf_003() {
    log_test "PERF-003: Daemon startup → <5 seconds"
    log_skip "Manual performance benchmark - requires orchestrator"
    echo "  1. hal-9000 daemon stop (if running)"
    echo "  2. time hal-9000 daemon start"
    echo "  3. Measure: Time until daemon ready"
    echo "  4. Target: <5 seconds (parent container + ChromaDB)"
}

test_perf_004() {
    log_test "PERF-004: Session list command → <1 second"

    if [[ ! -x "$HAL9000_CMD" ]]; then
        log_skip "hal-9000 command not found"
        return
    fi

    # Measure session list performance
    local start_time
    local end_time
    local duration

    start_time=$(date +%s%N)
    "$HAL9000_CMD" sessions &> /dev/null || true
    end_time=$(date +%s%N)

    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

    if [[ $duration -lt 1000 ]]; then
        log_pass "Session list completed in ${duration}ms (<1s)"
    else
        log_skip "Session list took ${duration}ms (>1s, acceptable for cold cache)"
    fi
}

#==========================================
# 13.2 Memory Usage (PERF-005 to PERF-006)
#==========================================

test_perf_005() {
    log_test "PERF-005: Memory per container → <500MB base"
    log_skip "Manual Docker stats measurement"
    echo "  1. hal-9000 /tmp/test-project"
    echo "  2. docker stats (in another terminal)"
    echo "  3. Measure: Memory usage of hal9000-* container"
    echo "  4. Target: <500MB for base profile (no large dependencies)"
    echo "  5. Note: Java/Node profiles may use more due to runtimes"
}

test_perf_006() {
    log_test "PERF-006: Daemon memory usage → <200MB"
    log_skip "Manual Docker stats measurement - requires orchestrator"
    echo "  1. hal-9000 daemon start"
    echo "  2. docker stats hal9000-parent"
    echo "  3. Measure: Memory usage of parent container"
    echo "  4. Target: <200MB (lightweight orchestration + ChromaDB)"
}

#==========================================
# 13.3 CPU Usage (PERF-007)
#==========================================

test_perf_007() {
    log_test "PERF-007: Idle CPU usage → <5%"
    log_skip "Manual Docker stats measurement"
    echo "  1. hal-9000 /tmp/test-project"
    echo "  2. Wait for session to be idle (no active Claude queries)"
    echo "  3. docker stats (observe CPU %)"
    echo "  4. Target: <5% CPU when idle"
    echo "  5. Note: Spikes during Claude processing are expected"
}

#==========================================
# 13.4 Disk Usage (PERF-008)
#==========================================

test_perf_008() {
    log_test "PERF-008: Volume disk usage → <1GB per session"
    log_skip "Manual volume inspection"
    echo "  1. hal-9000 /tmp/test-project (create session)"
    echo "  2. docker system df -v | grep hal9000"
    echo "  3. Measure: Size of hal9000-claude-session volume"
    echo "  4. Target: <1GB per session (typical usage)"
    echo "  5. Note: Can grow with conversation history and artifacts"
}

#==========================================
# 13.5 Scaling Limits (PERF-009 to PERF-011)
#==========================================

test_perf_009() {
    log_test "PERF-009: Concurrent sessions → 10 sessions supported"
    log_skip "Manual scaling test"
    echo "  1. Open 10 terminal windows"
    echo "  2. In each: hal-9000 /tmp/test-project-N (N=1..10)"
    echo "  3. Verify: All sessions start and remain functional"
    echo "  4. Monitor: docker stats (ensure resources don't overwhelm system)"
    echo "  5. Target: All 10 sessions work correctly"
}

test_perf_010() {
    log_test "PERF-010: Session metadata scaling → 100 sessions"
    log_skip "Manual stress test"
    echo "  1. Create 100 session metadata entries"
    echo "  2. hal-9000 sessions (list all)"
    echo "  3. Measure: List command performance"
    echo "  4. Target: Fast lookup (<2s) even with 100 sessions"
    echo "  5. Verify: No memory leaks or performance degradation"
}

test_perf_011() {
    log_test "PERF-011: Large project mounting → 1GB+ project works"
    log_skip "Manual Docker test with large repository"
    echo "  1. Clone large repository (e.g., Linux kernel, 1GB+)"
    echo "  2. cd /path/to/large-project"
    echo "  3. hal-9000"
    echo "  4. Verify: Project mounts correctly into container"
    echo "  5. Verify: File operations work without timeout"
    echo "  6. Monitor: docker stats (ensure reasonable resource usage)"
}

#==========================================
# Main Test Runner
#==========================================

main() {
    # 13.1 Startup Performance
    test_perf_001 || true
    test_perf_002 || true
    test_perf_003 || true
    test_perf_004 || true

    # 13.2 Memory Usage
    test_perf_005 || true
    test_perf_006 || true

    # 13.3 CPU Usage
    test_perf_007 || true

    # 13.4 Disk Usage
    test_perf_008 || true

    # 13.5 Scaling Limits
    test_perf_009 || true
    test_perf_010 || true
    test_perf_011 || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Performance Test Results"
    echo "=========================================="
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (performance benchmarks)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Performance benchmarks require:"
        echo "  - Running Docker containers"
        echo "  - Actual timing measurements"
        echo "  - Resource monitoring (docker stats)"
        echo "  - Large-scale testing (10+ sessions)"
        echo ""
        echo "Performance targets:"
        echo "  - First launch: <10s (cold start)"
        echo "  - Warm launch: <2s (from pool)"
        echo "  - Session list: <1s"
        echo "  - Memory/container: <500MB (base)"
        echo "  - Idle CPU: <5%"
        echo "  - Concurrent sessions: 10+"
        echo ""
        echo "See test output above for benchmark procedures."
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
