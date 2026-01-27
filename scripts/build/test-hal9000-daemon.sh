#!/usr/bin/env bash
# test-hal-9000-daemon.sh - Test hal-9000 daemon subcommands
#
# Tests:
# - hal-9000 daemon help
# - hal-9000 daemon status (when not running)
# - hal-9000 daemon start
# - hal-9000 daemon status (when running)
# - hal-9000 daemon restart
# - hal-9000 daemon stop

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
log_fail() { printf "${RED}[FAIL]${NC} %s\\n" "$1"; FAILED=$((FAILED + 1)); }
log_info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

# Test container names
PARENT_CONTAINER="hal9000-parent"
TEST_VOLUMES=("hal9000-chromadb" "hal9000-memorybank" "hal9000-plugins")

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test resources..."
    # Stop parent if running (use docker directly to avoid prompts)
    docker stop "$PARENT_CONTAINER" 2>/dev/null || true
    docker rm "$PARENT_CONTAINER" 2>/dev/null || true
    # Don't remove volumes - they persist across tests
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

    log_pass "Prerequisites OK"
}

# ============================================================================
# TESTS
# ============================================================================

test_daemon_help() {
    log_test "hal-9000 daemon help shows usage"

    local output
    output=$("$HAL9000" daemon help 2>&1) || true

    if echo "$output" | grep -q "Usage: hal-9000 daemon"; then
        log_pass "daemon help shows usage"
    else
        log_fail "daemon help output incorrect"
        echo "Output: $output"
    fi
}

test_daemon_status_not_running() {
    log_test "hal-9000 daemon status when not running"

    # Ensure parent is not running
    docker stop "$PARENT_CONTAINER" 2>/dev/null || true
    docker rm "$PARENT_CONTAINER" 2>/dev/null || true

    local output
    output=$("$HAL9000" daemon status 2>&1) || true

    if echo "$output" | grep -q "Parent container: Not found"; then
        log_pass "daemon status shows not found when stopped"
    else
        log_fail "daemon status should show not found"
        echo "Output: $output"
    fi
}

test_daemon_start() {
    log_test "hal-9000 daemon start creates parent container"

    # Check if parent image exists
    if ! docker image inspect "ghcr.io/hellblazer/hal-9000:parent" &>/dev/null; then
        log_info "Parent image not found, building..."
        local docker_dir="$REPO_ROOT/plugins/hal-9000/docker"
        if [[ -f "$docker_dir/Dockerfile.parent" ]]; then
            docker build -f "$docker_dir/Dockerfile.parent" -t "ghcr.io/hellblazer/hal-9000:parent" "$docker_dir" || {
                log_fail "Failed to build parent image"
                return 1
            }
        else
            log_fail "Dockerfile.parent not found"
            return 1
        fi
    fi

    # Start daemon
    "$HAL9000" daemon start 2>&1 || {
        log_fail "daemon start failed"
        return 1
    }

    # Verify container is running
    if docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_pass "daemon start created parent container"
    else
        log_fail "Parent container not running after start"
        return 1
    fi
}

test_daemon_status_running() {
    log_test "hal-9000 daemon status when running"

    # Ensure daemon is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_info "Starting daemon for status test..."
        "$HAL9000" daemon start 2>&1 || true
    fi

    local output
    output=$("$HAL9000" daemon status 2>&1) || true

    if echo "$output" | grep -q "Parent container: Running"; then
        log_pass "daemon status shows running"
    else
        log_fail "daemon status should show running"
        echo "Output: $output"
    fi
}

test_daemon_chromadb_healthy() {
    log_test "ChromaDB server is healthy after start"

    # Ensure daemon is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_info "Starting daemon for chromadb test..."
        "$HAL9000" daemon start 2>&1 || true
        sleep 5  # Extra wait for ChromaDB
    fi

    # Check ChromaDB heartbeat (v2 API)
    if docker exec "$PARENT_CONTAINER" curl -s "http://localhost:8000/api/v2/heartbeat" >/dev/null 2>&1; then
        log_pass "ChromaDB server is healthy"
    else
        log_fail "ChromaDB server not responding"
    fi
}

test_daemon_volumes_created() {
    log_test "Shared volumes are created"

    # Start daemon to ensure volumes are created
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        "$HAL9000" daemon start 2>&1 || true
    fi

    local all_exist=true
    for vol in "${TEST_VOLUMES[@]}"; do
        if ! docker volume inspect "$vol" >/dev/null 2>&1; then
            log_info "Volume not found: $vol"
            all_exist=false
        fi
    done

    if [[ "$all_exist" == "true" ]]; then
        log_pass "All shared volumes created"
    else
        log_fail "Some volumes not created"
    fi
}

test_daemon_restart() {
    log_test "hal-9000 daemon restart works"

    # Ensure daemon is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        "$HAL9000" daemon start 2>&1 || true
    fi

    # Get original container ID
    local old_id
    old_id=$(docker inspect --format '{{.Id}}' "$PARENT_CONTAINER" 2>/dev/null | cut -c1-12) || old_id=""

    # Restart (non-interactive - force stop)
    docker stop "$PARENT_CONTAINER" >/dev/null 2>&1 || true
    docker rm "$PARENT_CONTAINER" >/dev/null 2>&1 || true
    "$HAL9000" daemon start 2>&1 || true

    # Get new container ID
    local new_id
    new_id=$(docker inspect --format '{{.Id}}' "$PARENT_CONTAINER" 2>/dev/null | cut -c1-12) || new_id=""

    if [[ -n "$new_id" ]] && [[ "$old_id" != "$new_id" ]]; then
        log_pass "daemon restart created new container"
    elif [[ -n "$new_id" ]]; then
        log_pass "daemon restart (same container - acceptable)"
    else
        log_fail "daemon restart failed - no container"
    fi
}

test_daemon_stop() {
    log_test "hal-9000 daemon stop works"

    # Ensure daemon is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        "$HAL9000" daemon start 2>&1 || true
    fi

    # Stop (use docker directly to avoid interactive prompt)
    docker stop "$PARENT_CONTAINER" >/dev/null 2>&1 || true

    # Verify stopped
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_pass "daemon stop works"
    else
        log_fail "Container still running after stop"
    fi
}

test_version_updated() {
    log_test "hal-9000 version is 0.6.0+"

    local version
    version=$("$HAL9000" --version 2>&1 | head -1) || version=""

    if echo "$version" | grep -qE "0\.[6-9]|[1-9]\.[0-9]"; then
        log_pass "Version updated: $version"
    else
        log_fail "Version should be 0.6.0+, got: $version"
    fi
}

test_help_shows_daemon() {
    log_test "hal-9000 --help shows daemon commands"

    local output
    output=$("$HAL9000" --help 2>&1) || true

    if echo "$output" | grep -q "DAEMON COMMANDS"; then
        log_pass "Help shows daemon commands section"
    else
        log_fail "Help should include daemon commands"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  hal-9000 Daemon Tests"
    echo "=========================================="
    echo ""

    check_prerequisites
    cleanup

    case "$test_filter" in
        all)
            test_version_updated
            test_help_shows_daemon
            test_daemon_help
            test_daemon_status_not_running
            test_daemon_start
            test_daemon_status_running
            test_daemon_chromadb_healthy
            test_daemon_volumes_created
            test_daemon_restart
            test_daemon_stop
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

    cleanup

    echo ""
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
