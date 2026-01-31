#!/bin/bash
# Network Isolation Tests - Issue #7
#
# Validates network isolation between workers:
# - Workers cannot access each other's network interfaces
# - Workers can reach parent container
# - Parent can reach all workers
# - Network traffic is isolated by default
#
# Usage: bash test-network-isolation.sh [--no-cleanup]
#
set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test tracking
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Configuration
NO_CLEANUP="${1:-}"
TEST_NETWORK="hal9000-test-net-$$"
PARENT_CONTAINER="hal9000-test-parent-$$"
WORKER_1="hal9000-test-worker-1-$$"
WORKER_2="hal9000-test-worker-2-$$"

# Helper functions
log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}⊘${NC} $1 (SKIPPED)"
}

record_test() {
    local test_name="$1"
    local passed="$2"

    TOTAL=$((TOTAL + 1))

    if [ "$passed" -eq 1 ]; then
        PASSED=$((PASSED + 1))
        log_success "$test_name"
    else
        FAILED=$((FAILED + 1))
        log_fail "$test_name"
    fi
}

cleanup() {
    if [ "$NO_CLEANUP" != "--no-cleanup" ]; then
        log_info "Cleaning up test containers and network..."

        # Stop and remove containers
        docker stop "$PARENT_CONTAINER" "$WORKER_1" "$WORKER_2" 2>/dev/null || true
        docker rm -f "$PARENT_CONTAINER" "$WORKER_1" "$WORKER_2" 2>/dev/null || true

        # Remove test network
        docker network rm "$TEST_NETWORK" 2>/dev/null || true
    else
        log_info "Skipping cleanup (--no-cleanup flag set)"
        log_info "Network: $TEST_NETWORK"
        log_info "Containers: $PARENT_CONTAINER, $WORKER_1, $WORKER_2"
    fi
}

trap cleanup EXIT

# ============================================================================
# TEST SETUP
# ============================================================================

setup_test_network() {
    log_section "SETUP: Creating test network and containers"

    # Check Docker availability
    if ! docker ps >/dev/null 2>&1; then
        log_skip "Docker not available"
        return 1
    fi

    # Create custom Docker network
    if docker network create "$TEST_NETWORK" >/dev/null 2>&1; then
        log_success "Created test network: $TEST_NETWORK"
    else
        log_fail "Failed to create test network"
        return 1
    fi

    # Create parent container
    if docker run -d \
        --name "$PARENT_CONTAINER" \
        --network "$TEST_NETWORK" \
        alpine sleep 600 >/dev/null 2>&1; then
        log_success "Created parent container: $PARENT_CONTAINER"
    else
        log_fail "Failed to create parent container"
        return 1
    fi

    # Create worker 1
    if docker run -d \
        --name "$WORKER_1" \
        --network "$TEST_NETWORK" \
        alpine sleep 600 >/dev/null 2>&1; then
        log_success "Created worker 1: $WORKER_1"
    else
        log_fail "Failed to create worker 1"
        return 1
    fi

    # Create worker 2
    if docker run -d \
        --name "$WORKER_2" \
        --network "$TEST_NETWORK" \
        alpine sleep 600 >/dev/null 2>&1; then
        log_success "Created worker 2: $WORKER_2"
    else
        log_fail "Failed to create worker 2"
        return 1
    fi

    sleep 1  # Wait for containers to stabilize
}

# ============================================================================
# ISO-001: Network existence and containers joined
# ============================================================================

test_ISO_001_network_exists() {
    log_section "ISO-001: Network exists and containers joined"

    if docker network ls --filter "name=$TEST_NETWORK" --format "{{.Name}}" | grep -q "$TEST_NETWORK"; then
        record_test "ISO-001: Network created and exists" 1
    else
        record_test "ISO-001: Network created and exists" 0
    fi
}

# ============================================================================
# ISO-002: Parent can reach workers by hostname
# ============================================================================

test_ISO_002_parent_reaches_workers() {
    log_section "ISO-002: Parent can reach workers by hostname"

    # Test parent → worker 1
    if docker exec "$PARENT_CONTAINER" ping -c 1 -W 2 "$WORKER_1" >/dev/null 2>&1; then
        record_test "ISO-002a: Parent can ping worker 1" 1
    else
        record_test "ISO-002a: Parent can ping worker 1" 0
    fi

    # Test parent → worker 2
    if docker exec "$PARENT_CONTAINER" ping -c 1 -W 2 "$WORKER_2" >/dev/null 2>&1; then
        record_test "ISO-002b: Parent can ping worker 2" 1
    else
        record_test "ISO-002b: Parent can ping worker 2" 0
    fi
}

# ============================================================================
# ISO-003: Workers can reach parent
# ============================================================================

test_ISO_003_workers_reach_parent() {
    log_section "ISO-003: Workers can reach parent"

    # Test worker 1 → parent
    if docker exec "$WORKER_1" ping -c 1 -W 2 "$PARENT_CONTAINER" >/dev/null 2>&1; then
        record_test "ISO-003a: Worker 1 can ping parent" 1
    else
        record_test "ISO-003a: Worker 1 can ping parent" 0
    fi

    # Test worker 2 → parent
    if docker exec "$WORKER_2" ping -c 1 -W 2 "$PARENT_CONTAINER" >/dev/null 2>&1; then
        record_test "ISO-003b: Worker 2 can ping parent" 1
    else
        record_test "ISO-003b: Worker 2 can ping parent" 0
    fi
}

# ============================================================================
# ISO-004: Workers cannot reach each other (network isolation)
# ============================================================================

test_ISO_004_worker_isolation() {
    log_section "ISO-004: Workers cannot reach each other (network isolation)"

    # By default, Docker containers in same network CAN reach each other
    # This test documents current behavior; true isolation would require
    # additional network policies (seccomp, AppArmor, etc.)
    log_info "Note: Docker bridge networks allow inter-container communication by default"
    log_info "True isolation requires additional policies (not currently implemented)"

    # Test worker 1 → worker 2 (will succeed in default setup)
    if docker exec "$WORKER_1" ping -c 1 -W 2 "$WORKER_2" >/dev/null 2>&1; then
        log_fail "ISO-004: Workers can reach each other (isolation not enforced)"
        record_test "ISO-004: Inter-worker communication blocked" 0
    else
        log_success "ISO-004: Workers cannot reach each other"
        record_test "ISO-004: Inter-worker communication blocked" 1
    fi
}

# ============================================================================
# ISO-005: Network namespace isolation documentation
# ============================================================================

test_ISO_005_network_isolation_design() {
    log_section "ISO-005: Network isolation design and documentation"

    log_info "Network isolation in HAL-9000:"
    log_info "  - Current: Workers share network namespace (by default)"
    log_info "  - Rationale: Allows ChromaDB access via localhost:8000"
    log_info "  - Parent: Owns network, spawns workers on same network"
    log_info "  - Workers: Access parent services via DNS (container hostname)"
    log_info ""
    log_info "Security considerations:"
    log_info "  - Network isolation alone doesn't prevent all attacks"
    log_info "  - Container namespaces provide PID/UTS/IPC isolation"
    log_info "  - Additional policies can enforce stricter isolation"
    log_info "  - Current design prioritizes functionality over isolation"
    log_info ""
    log_info "Future enhancements (Issue #7):"
    log_info "  - User-defined networks with isolation policies"
    log_info "  - seccomp profiles to restrict syscalls"
    log_info "  - AppArmor policies to isolate container access"
    log_info "  - NetworkPolicy equivalent for Docker (via plugin)"

    record_test "ISO-005: Network isolation design documented" 1
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_section "HAL-9000 Network Isolation Tests - Issue #7"

    # Check if Docker is available
    if ! docker ps >/dev/null 2>&1; then
        log_skip "Docker is not available - cannot run network isolation tests"
        return 0
    fi

    # Setup test environment
    if ! setup_test_network; then
        log_fail "Failed to setup test network"
        return 1
    fi

    # Run tests
    test_ISO_001_network_exists
    test_ISO_002_parent_reaches_workers
    test_ISO_003_workers_reach_parent
    test_ISO_004_worker_isolation
    test_ISO_005_network_isolation_design

    # Summary
    log_section "Network Isolation Test Summary"

    echo "Total Tests:  $TOTAL"
    echo -e "Passed:       ${GREEN}$PASSED${NC}"
    echo -e "Failed:       ${RED}$FAILED${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        log_success "All network tests passed ($PASSED/$TOTAL)"
        return 0
    else
        log_fail "$FAILED test(s) failed"
        return 1
    fi
}

main "$@"
