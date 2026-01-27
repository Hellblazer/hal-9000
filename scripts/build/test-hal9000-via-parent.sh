#!/usr/bin/env bash
# test-hal-9000-via-parent.sh - Test hal-9000 --via-parent functionality
#
# Tests worker spawning via parent container:
# - Parent must be running for via-parent to work
# - Worker shares network namespace with parent
# - Worker can access ChromaDB via localhost:8000
# - Worker mounts shared volumes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HAL9000="$REPO_ROOT/hal-9000"

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

# Test resources
PARENT_CONTAINER="hal9000-parent"
TEST_WORKER="hal9000-worker-viaparent-test"
TEST_PROJECT_DIR=""

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test resources..."
    docker rm -f "$TEST_WORKER" 2>/dev/null || true
    # Don't stop parent - other tests may need it
    [[ -n "$TEST_PROJECT_DIR" ]] && rm -rf "$TEST_PROJECT_DIR" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# SETUP
# ============================================================================

setup_test_project() {
    # Use ~/.hal9000/test-projects which is mounted to parent container
    # This allows the project to be accessible from both host and parent
    local base_dir="${HAL9000_HOME:-$HOME/.hal9000}/test-projects"
    mkdir -p "$base_dir"
    TEST_PROJECT_DIR="$base_dir/via-parent-test-$$"
    mkdir -p "$TEST_PROJECT_DIR"
    echo "# Test Project" > "$TEST_PROJECT_DIR/README.md"
    # Add pom.xml for Java profile detection
    echo '<project><groupId>test</groupId></project>' > "$TEST_PROJECT_DIR/pom.xml"
    log_info "Created test project: $TEST_PROJECT_DIR"
}

ensure_daemon_running() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_info "Starting daemon..."
        "$HAL9000" daemon start 2>&1 || {
            log_fail "Could not start daemon"
            return 1
        }
        # Wait for ChromaDB
        sleep 3
    fi
    return 0
}

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &>/dev/null; then
        log_fail "Docker not installed"
        exit 1
    fi

    if ! docker ps &>/dev/null; then
        log_fail "Docker daemon not running"
        exit 1
    fi

    # Check hal-9000 exists
    if [[ ! -x "$HAL9000" ]]; then
        log_fail "hal-9000 not found or not executable: $HAL9000"
        exit 1
    fi

    # Check for worker image
    if ! docker image inspect "ghcr.io/hellblazer/hal-9000:base" &>/dev/null; then
        log_info "Base image not found, building..."
        local docker_dir="$REPO_ROOT/plugins/hal-9000/docker"
        if [[ -f "$docker_dir/Dockerfile.hal9000" ]]; then
            docker build -f "$docker_dir/Dockerfile.hal9000" -t "ghcr.io/hellblazer/hal-9000:base" "$docker_dir" || {
                log_fail "Failed to build base image"
                exit 1
            }
        else
            log_fail "Dockerfile.hal9000 not found"
            exit 1
        fi
    fi

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_via_parent_requires_daemon() {
    log_test "via-parent requires daemon running"

    # Stop daemon if running
    docker stop "$PARENT_CONTAINER" 2>/dev/null || true
    docker rm "$PARENT_CONTAINER" 2>/dev/null || true

    # Try to use --via-parent - should fail or prompt
    local output
    output=$(echo "n" | "$HAL9000" --via-parent --name "$TEST_WORKER" --detach "$TEST_PROJECT_DIR" 2>&1) || true

    if echo "$output" | grep -qE "Parent container not running|Cannot launch via parent"; then
        log_pass "via-parent correctly requires daemon"
    else
        log_fail "via-parent should require daemon"
        echo "Output: $output"
    fi
}

test_via_parent_spawns_worker() {
    log_test "via-parent spawns worker container"

    ensure_daemon_running || return 1

    # Spawn worker via parent, using --no-rm via docker exec directly
    # (hal-9000 doesn't have --no-rm flag, so we call spawn-worker.sh directly)
    docker exec hal9000-parent /scripts/spawn-worker.sh \
        -n "$TEST_WORKER" \
        -d \
        --no-rm \
        -i "ghcr.io/hellblazer/hal-9000:base" \
        "$TEST_PROJECT_DIR" 2>&1 || {
        log_fail "via-parent spawn failed"
        return 1
    }

    # Wait for container to start
    sleep 2

    # Check if worker exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_WORKER}$"; then
        log_pass "Worker container created"
    else
        log_fail "Worker container not found"
        docker ps -a --format '{{.Names}}' 2>/dev/null | head -5
        return 1
    fi

    docker rm -f "$TEST_WORKER" 2>/dev/null || true
}

test_worker_shares_network() {
    log_test "Worker shares network with parent"

    ensure_daemon_running || return 1

    # Spawn worker via parent
    docker exec hal9000-parent /scripts/spawn-worker.sh \
        -n "$TEST_WORKER" \
        -d \
        --no-rm \
        -i "ghcr.io/hellblazer/hal-9000:base" \
        "$TEST_PROJECT_DIR" 2>&1 || {
        log_fail "Could not spawn worker"
        return 1
    }

    sleep 2

    # Check if worker can access parent's ChromaDB
    if docker exec "$TEST_WORKER" curl -s "http://localhost:8000/api/v2/heartbeat" >/dev/null 2>&1; then
        log_pass "Worker can access parent's ChromaDB via localhost"
    else
        log_fail "Worker cannot access ChromaDB"
    fi

    docker rm -f "$TEST_WORKER" 2>/dev/null || true
}

test_worker_has_shared_volumes() {
    log_test "Worker has shared volumes mounted"

    ensure_daemon_running || return 1

    # Spawn worker via parent
    docker exec hal9000-parent /scripts/spawn-worker.sh \
        -n "$TEST_WORKER" \
        -d \
        --no-rm \
        -i "ghcr.io/hellblazer/hal-9000:base" \
        "$TEST_PROJECT_DIR" 2>&1 || {
        log_fail "Could not spawn worker"
        return 1
    }

    sleep 2

    # Check for shared volume mounts
    local has_chromadb has_membank
    has_chromadb=$(docker exec "$TEST_WORKER" test -d /data/chromadb 2>/dev/null && echo "yes" || echo "no")
    has_membank=$(docker exec "$TEST_WORKER" test -d /data/membank 2>/dev/null && echo "yes" || echo "no")

    if [[ "$has_chromadb" == "yes" ]] && [[ "$has_membank" == "yes" ]]; then
        log_pass "Worker has shared volumes mounted"
    else
        log_fail "Worker missing shared volumes (chromadb: $has_chromadb, membank: $has_membank)"
    fi

    docker rm -f "$TEST_WORKER" 2>/dev/null || true
}

test_worker_has_project_mounted() {
    log_test "Worker has project directory mounted"

    ensure_daemon_running || return 1

    # Spawn worker via parent
    docker exec hal9000-parent /scripts/spawn-worker.sh \
        -n "$TEST_WORKER" \
        -d \
        --no-rm \
        -i "ghcr.io/hellblazer/hal-9000:base" \
        "$TEST_PROJECT_DIR" 2>&1 || {
        log_fail "Could not spawn worker"
        return 1
    }

    sleep 2

    # Check for project files in /workspace
    if docker exec "$TEST_WORKER" cat /workspace/README.md 2>/dev/null | grep -q "Test Project"; then
        log_pass "Worker has project mounted at /workspace"
    else
        log_fail "Worker project not mounted correctly"
    fi

    docker rm -f "$TEST_WORKER" 2>/dev/null || true
}

test_hal-9000_via_parent_flag() {
    log_test "hal-9000 --via-parent flag works"

    ensure_daemon_running || return 1

    # Test that hal-9000 --via-parent runs and calls spawn-worker.sh
    # Note: with --rm (default), the container exits immediately
    # so we just test that the command runs successfully
    local output
    output=$("$HAL9000" --via-parent --name "${TEST_WORKER}-flag" --detach "$TEST_PROJECT_DIR" 2>&1) || true

    # Should have spawned (even if container exited with --rm)
    if echo "$output" | grep -q "Worker spawned"; then
        log_pass "hal-9000 --via-parent flag works"
    else
        log_fail "hal-9000 --via-parent flag failed"
        echo "Output: $output"
    fi

    docker rm -f "${TEST_WORKER}-flag" 2>/dev/null || true
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  hal-9000 Via-Parent Tests"
    echo "=========================================="
    echo ""

    check_prerequisites
    setup_test_project

    case "$test_filter" in
        all)
            test_via_parent_requires_daemon
            test_via_parent_spawns_worker
            test_worker_shares_network
            test_worker_has_shared_volumes
            test_worker_has_project_mounted
            test_hal-9000_via_parent_flag
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
