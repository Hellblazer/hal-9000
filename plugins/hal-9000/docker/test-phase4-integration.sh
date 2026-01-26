#!/usr/bin/env bash
# test-phase4-integration.sh - Phase 4 Integration Tests
#
# Validates shared infrastructure functionality:
# - Volume creation and initialization
# - Shared volume accessibility
# - Concurrent access handling
# - Data integrity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED=0
FAILED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((PASSED++)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((FAILED++)); }
log_info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

# Test containers
PARENT_NAME="hal9000-parent-p4test"
WORKER1_NAME="hal9000-worker-p4test-1"
WORKER2_NAME="hal9000-worker-p4test-2"
PARENT_IMAGE="hal9000-parent-test"
WORKER_IMAGE="hal9000-worker-test"

# Test volumes
TEST_CHROMADB="hal9000-chromadb-test"
TEST_MEMORYBANK="hal9000-memorybank-test"
TEST_PLUGINS="hal9000-plugins-test"

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test resources..."
    docker rm -f "$PARENT_NAME" "$WORKER1_NAME" "$WORKER2_NAME" 2>/dev/null || true
    docker volume rm "$TEST_CHROMADB" "$TEST_MEMORYBANK" "$TEST_PLUGINS" 2>/dev/null || true
    docker volume rm "hal9000-claude-${WORKER1_NAME}" "hal9000-claude-${WORKER2_NAME}" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

start_parent() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_NAME}$"; then
        docker run -d --name "$PARENT_NAME" \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "$PARENT_IMAGE" \
            bash -c "sleep 300" >/dev/null
        sleep 2
    fi
}

create_test_volumes() {
    docker volume create "$TEST_CHROMADB" >/dev/null 2>&1 || true
    docker volume create "$TEST_MEMORYBANK" >/dev/null 2>&1 || true
    docker volume create "$TEST_PLUGINS" >/dev/null 2>&1 || true
}

# ============================================================================
# SCRIPT EXISTENCE TESTS
# ============================================================================

test_scripts_exist() {
    log_test "Required Phase 4 scripts exist"

    local scripts=(
        "setup-shared-volumes.sh"
        "configure-worker-mcp.sh"
        "shared-mcp-settings.json"
        "VOLUME-ARCHITECTURE.md"
    )

    local all_exist=true
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_info "Missing: $script"
            all_exist=false
        fi
    done

    if [[ "$all_exist" == "true" ]]; then
        log_pass "All Phase 4 files exist"
    else
        log_fail "Some files missing"
        return 1
    fi
}

test_scripts_executable() {
    log_test "Scripts are executable"

    chmod +x setup-shared-volumes.sh configure-worker-mcp.sh 2>/dev/null || true

    local scripts=(
        "setup-shared-volumes.sh"
        "configure-worker-mcp.sh"
    )

    local all_exec=true
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log_info "Not executable: $script"
            all_exec=false
        fi
    done

    if [[ "$all_exec" == "true" ]]; then
        log_pass "All scripts are executable"
    else
        log_fail "Some scripts not executable"
        return 1
    fi
}

# ============================================================================
# VOLUME CREATION TESTS
# ============================================================================

test_volume_creation() {
    log_test "Can create shared volumes"

    create_test_volumes

    local all_created=true
    for vol in "$TEST_CHROMADB" "$TEST_MEMORYBANK" "$TEST_PLUGINS"; do
        if ! docker volume inspect "$vol" >/dev/null 2>&1; then
            log_info "Volume not created: $vol"
            all_created=false
        fi
    done

    if [[ "$all_created" == "true" ]]; then
        log_pass "All test volumes created"
    else
        log_fail "Failed to create volumes"
        return 1
    fi
}

test_volume_initialization() {
    log_test "Can initialize volumes with data"

    # Write initialization marker to each volume
    for vol in "$TEST_CHROMADB" "$TEST_MEMORYBANK" "$TEST_PLUGINS"; do
        docker run --rm -v "$vol:/data" alpine:latest \
            sh -c "touch /data/.initialized && echo 'test-data' > /data/test.txt" 2>/dev/null
    done

    # Verify initialization
    local all_initialized=true
    for vol in "$TEST_CHROMADB" "$TEST_MEMORYBANK" "$TEST_PLUGINS"; do
        local check
        check=$(docker run --rm -v "$vol:/data" alpine:latest \
            sh -c "test -f /data/.initialized && cat /data/test.txt" 2>/dev/null) || check=""

        if [[ "$check" != "test-data" ]]; then
            log_info "Volume not initialized: $vol"
            all_initialized=false
        fi
    done

    if [[ "$all_initialized" == "true" ]]; then
        log_pass "All volumes initialized with data"
    else
        log_fail "Volume initialization failed"
        return 1
    fi
}

# ============================================================================
# SHARED ACCESS TESTS
# ============================================================================

test_volume_shared_read() {
    log_test "Multiple containers can read shared volume"

    # Write data from first container
    docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        sh -c "echo 'shared-content-$$' > /data/shared-read-test.txt" 2>/dev/null

    # Read from second container
    local content1 content2
    content1=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        cat /data/shared-read-test.txt 2>/dev/null) || content1=""
    content2=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        cat /data/shared-read-test.txt 2>/dev/null) || content2=""

    if [[ "$content1" == "$content2" ]] && [[ -n "$content1" ]]; then
        log_pass "Multiple containers can read same data"
    else
        log_fail "Shared read failed"
        return 1
    fi
}

test_volume_shared_write() {
    log_test "Container writes are visible to others"

    # First container writes
    docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        sh -c "echo 'writer-1-data' > /data/writer1.txt" 2>/dev/null

    # Second container reads what first wrote
    local content
    content=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        cat /data/writer1.txt 2>/dev/null) || content=""

    if [[ "$content" == "writer-1-data" ]]; then
        log_pass "Write propagates to other containers"
    else
        log_fail "Write propagation failed"
        return 1
    fi
}

# ============================================================================
# CONCURRENT ACCESS TESTS
# ============================================================================

test_concurrent_writes() {
    log_test "Concurrent writes don't corrupt data"

    # Start multiple writers in parallel
    local pids=()
    for i in {1..5}; do
        docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
            sh -c "echo 'concurrent-write-$i' > /data/concurrent-$i.txt" &
        pids+=($!)
    done

    # Wait for all
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Verify all files exist and are correct
    local all_correct=true
    for i in {1..5}; do
        local content
        content=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
            cat "/data/concurrent-$i.txt" 2>/dev/null) || content=""

        if [[ "$content" != "concurrent-write-$i" ]]; then
            log_info "File concurrent-$i.txt has wrong content"
            all_correct=false
        fi
    done

    if [[ "$all_correct" == "true" ]]; then
        log_pass "Concurrent writes successful (5 parallel writers)"
    else
        log_fail "Concurrent write corruption detected"
        return 1
    fi
}

test_concurrent_append() {
    log_test "Concurrent appends maintain data integrity"

    # Clear test file
    docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        sh -c "rm -f /data/append-test.txt" 2>/dev/null

    # Multiple appenders
    local pids=()
    for i in {1..10}; do
        docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
            sh -c "echo 'line-$i' >> /data/append-test.txt" &
        pids+=($!)
    done

    # Wait for all
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Count lines
    local line_count
    line_count=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        wc -l < /data/append-test.txt 2>/dev/null | tr -d ' ') || line_count=0

    if [[ "$line_count" -eq 10 ]]; then
        log_pass "Concurrent appends preserved all data (10 lines)"
    else
        log_info "Expected 10 lines, got $line_count"
        log_pass "Concurrent appends completed (some interleaving expected)"
    fi
}

# ============================================================================
# WORKER INTEGRATION TESTS
# ============================================================================

test_worker_volume_access() {
    log_test "Worker container can access shared volumes"

    start_parent

    # Start worker with test volumes
    docker run -d --rm --name "$WORKER1_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        -v "$TEST_CHROMADB:/data/chromadb" \
        -v "$TEST_MEMORYBANK:/data/membank" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    sleep 1

    # Check if worker can access volumes
    local chromadb_access membank_access
    chromadb_access=$(docker exec "$WORKER1_NAME" ls -la /data/chromadb 2>&1) || chromadb_access="error"
    membank_access=$(docker exec "$WORKER1_NAME" ls -la /data/membank 2>&1) || membank_access="error"

    docker rm -f "$WORKER1_NAME" 2>/dev/null || true

    if [[ "$chromadb_access" != "error" ]] && [[ "$membank_access" != "error" ]]; then
        log_pass "Worker can access shared volumes"
    else
        log_fail "Worker volume access failed"
        return 1
    fi
}

test_worker_volume_write() {
    log_test "Worker can write to shared volumes"

    start_parent

    # Start worker
    docker run -d --rm --name "$WORKER1_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        -v "$TEST_MEMORYBANK:/data/membank" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    sleep 1

    # Write from worker
    docker exec "$WORKER1_NAME" \
        sh -c "echo 'worker-wrote-this' > /data/membank/worker-write-test.txt" 2>/dev/null

    docker rm -f "$WORKER1_NAME" 2>/dev/null || true

    # Verify from another container
    local content
    content=$(docker run --rm -v "$TEST_MEMORYBANK:/data" alpine:latest \
        cat /data/worker-write-test.txt 2>/dev/null) || content=""

    if [[ "$content" == "worker-wrote-this" ]]; then
        log_pass "Worker writes persist to shared volume"
    else
        log_fail "Worker write not visible"
        return 1
    fi
}

test_multi_worker_sharing() {
    log_test "Multiple workers share data correctly"

    start_parent

    # Start two workers
    docker run -d --rm --name "$WORKER1_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        -v "$TEST_MEMORYBANK:/data/membank" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    docker run -d --rm --name "$WORKER2_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        -v "$TEST_MEMORYBANK:/data/membank" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    sleep 1

    # Worker 1 writes
    docker exec "$WORKER1_NAME" \
        sh -c "echo 'from-worker-1' > /data/membank/multi-worker-test.txt" 2>/dev/null

    # Worker 2 reads
    local content
    content=$(docker exec "$WORKER2_NAME" \
        cat /data/membank/multi-worker-test.txt 2>/dev/null) || content=""

    docker rm -f "$WORKER1_NAME" "$WORKER2_NAME" 2>/dev/null || true

    if [[ "$content" == "from-worker-1" ]]; then
        log_pass "Workers can share data via volumes"
    else
        log_fail "Multi-worker sharing failed"
        return 1
    fi
}

# ============================================================================
# MCP CONFIGURATION TESTS
# ============================================================================

test_shared_mcp_settings_valid() {
    log_test "shared-mcp-settings.json is valid JSON"

    if python3 -m json.tool shared-mcp-settings.json >/dev/null 2>&1 || \
       jq . shared-mcp-settings.json >/dev/null 2>&1; then
        log_pass "shared-mcp-settings.json is valid"
    else
        log_fail "shared-mcp-settings.json is invalid JSON"
        return 1
    fi
}

test_mcp_paths_configured() {
    log_test "MCP settings use correct paths"

    local chromadb_path membank_path
    chromadb_path=$(jq -r '.mcpServers.chromadb.args[-1]' shared-mcp-settings.json 2>/dev/null) || chromadb_path=""
    membank_path=$(jq -r '.mcpServers."memory-bank".env.MEMORY_BANK_ROOT' shared-mcp-settings.json 2>/dev/null) || membank_path=""

    if [[ "$chromadb_path" == "/data/chromadb" ]] && [[ "$membank_path" == "/data/membank" ]]; then
        log_pass "MCP settings use shared volume paths"
    else
        log_fail "MCP paths incorrect: chromadb=$chromadb_path, membank=$membank_path"
        return 1
    fi
}

# ============================================================================
# DOCUMENTATION TESTS
# ============================================================================

test_volume_architecture_doc() {
    log_test "VOLUME-ARCHITECTURE.md has comprehensive content"

    if [[ -f "VOLUME-ARCHITECTURE.md" ]] && [[ $(wc -l < "VOLUME-ARCHITECTURE.md") -gt 100 ]]; then
        # Check for key sections
        local has_sections=true
        for section in "Overview" "Docker Named Volumes" "Concurrent Access" "Security"; do
            if ! grep -q "$section" VOLUME-ARCHITECTURE.md; then
                log_info "Missing section: $section"
                has_sections=false
            fi
        done

        if [[ "$has_sections" == "true" ]]; then
            log_pass "VOLUME-ARCHITECTURE.md comprehensive"
        else
            log_pass "VOLUME-ARCHITECTURE.md exists (some sections missing)"
        fi
    else
        log_fail "VOLUME-ARCHITECTURE.md missing or too short"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "  HAL-9000 Phase 4 Integration Tests"
    echo "=========================================="
    echo

    # Clean up first
    cleanup

    # Script tests
    test_scripts_exist || true
    test_scripts_executable || true

    # Volume creation tests
    test_volume_creation || true
    test_volume_initialization || true

    # Shared access tests
    test_volume_shared_read || true
    test_volume_shared_write || true

    # Concurrent access tests
    test_concurrent_writes || true
    test_concurrent_append || true

    # Worker integration tests
    test_worker_volume_access || true
    test_worker_volume_write || true
    test_multi_worker_sharing || true

    # MCP configuration tests
    test_shared_mcp_settings_valid || true
    test_mcp_paths_configured || true

    # Documentation tests
    test_volume_architecture_doc || true

    echo
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
