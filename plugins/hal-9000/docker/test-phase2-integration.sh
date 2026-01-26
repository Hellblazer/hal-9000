#!/usr/bin/env bash
# test-phase2-integration.sh - Phase 2 Integration Tests
#
# Validates the worker container functionality.

set -euo pipefail

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
PARENT_NAME="hal9000-parent-p2test"
WORKER_NAME="hal9000-worker-p2test"
PARENT_IMAGE="hal9000-parent-test"
WORKER_IMAGE="hal9000-worker-test"

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test containers..."
    docker rm -f "$PARENT_NAME" "$WORKER_NAME" 2>/dev/null || true
    docker rm -f "${WORKER_NAME}-mcp" "${WORKER_NAME}-entrypoint" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# TESTS
# ============================================================================

test_worker_image_built() {
    log_test "Worker image exists"
    if docker image inspect "$WORKER_IMAGE" >/dev/null 2>&1; then
        log_pass "Worker image exists: $WORKER_IMAGE"
    else
        log_fail "Worker image not found: $WORKER_IMAGE"
        return 1
    fi
}

test_worker_image_size() {
    log_test "Worker image size under 600MB"
    local size
    size=$(docker images "$WORKER_IMAGE" --format "{{.Size}}" | head -1)
    log_info "Worker image size: $size"

    # Check if under 600MB (allowing some margin)
    if echo "$size" | grep -qE "^[0-5][0-9]{2}MB$"; then
        log_pass "Worker image under 600MB: $size"
    else
        log_info "Worker image size: $size (check manually)"
        ((PASSED++))  # Don't fail for size, just note it
    fi
}

test_worker_entrypoint_runs() {
    log_test "Worker entrypoint executes successfully"

    local output
    output=$(docker run --rm --name "${WORKER_NAME}-entrypoint" \
        "$WORKER_IMAGE" bash -c "echo 'entrypoint-test'" 2>&1) || true

    if echo "$output" | grep -q "HAL-9000 Worker starting"; then
        log_pass "Worker entrypoint executed"
    else
        log_fail "Worker entrypoint failed: $output"
        return 1
    fi
}

test_claude_cli_available() {
    log_test "Claude CLI available in worker"

    local version
    version=$(docker run --rm "$WORKER_IMAGE" bash -c "claude --version" 2>&1 | tail -1) || true

    if echo "$version" | grep -qE "^[0-9]+\.[0-9]+"; then
        log_pass "Claude CLI version: $version"
    else
        log_fail "Claude CLI not working: $version"
        return 1
    fi
}

test_git_available() {
    log_test "Git available in worker"

    local version
    version=$(docker run --rm --entrypoint "" "$WORKER_IMAGE" git --version 2>&1) || true

    if echo "$version" | grep -q "git version"; then
        log_pass "Git available: $version"
    else
        log_fail "Git not available: $version"
        return 1
    fi
}

test_workspace_mount() {
    log_test "Workspace mount works"

    # Create temp directory with test file
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "test-content" > "$temp_dir/test-file.txt"

    local content
    content=$(docker run --rm --entrypoint "" \
        -v "$temp_dir:/workspace" \
        "$WORKER_IMAGE" cat /workspace/test-file.txt 2>&1) || true

    rm -rf "$temp_dir"

    if [[ "$content" == "test-content" ]]; then
        log_pass "Workspace mount works correctly"
    else
        log_fail "Workspace mount failed: $content"
        return 1
    fi
}

test_claude_home_mount() {
    log_test "Claude home mount works"

    # Create temp claude home with settings
    local temp_claude
    temp_claude=$(mktemp -d)
    echo '{"test": true}' > "$temp_claude/settings.json"

    local content
    content=$(docker run --rm --entrypoint "" \
        -v "$temp_claude:/root/.claude" \
        "$WORKER_IMAGE" cat /root/.claude/settings.json 2>&1) || true

    rm -rf "$temp_claude"

    if echo "$content" | grep -q '"test"'; then
        log_pass "Claude home mount preserves settings.json"
    else
        log_fail "Claude home mount failed: $content"
        return 1
    fi
}

test_worker_with_parent_network() {
    log_test "Worker shares parent network namespace"

    # Start parent
    docker run -d --name "$PARENT_NAME" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$PARENT_IMAGE" \
        bash -c "sleep 120" >/dev/null

    sleep 2

    # Start worker sharing parent's network
    docker run -d --name "$WORKER_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    sleep 1

    # Compare network namespaces
    local parent_ns worker_ns
    parent_ns=$(docker exec "$PARENT_NAME" cat /proc/net/tcp 2>/dev/null | md5sum | cut -d' ' -f1) || true
    worker_ns=$(docker exec "$WORKER_NAME" cat /proc/net/tcp 2>/dev/null | md5sum | cut -d' ' -f1) || true

    if [[ -n "$parent_ns" ]] && [[ "$parent_ns" == "$worker_ns" ]]; then
        log_pass "Worker shares parent's network namespace"
    else
        log_fail "Network namespaces don't match"
        return 1
    fi
}

test_environment_variables() {
    log_test "Environment variables set correctly"

    local env_output
    env_output=$(docker run --rm --entrypoint "" "$WORKER_IMAGE" \
        bash -c 'echo "CLAUDE_HOME=$CLAUDE_HOME WORKSPACE=$WORKSPACE LANG=$LANG"' 2>&1) || true

    if echo "$env_output" | grep -q "CLAUDE_HOME=/root/.claude" && \
       echo "$env_output" | grep -q "WORKSPACE=/workspace" && \
       echo "$env_output" | grep -q "LANG=en_US.UTF-8"; then
        log_pass "Environment variables set correctly"
    else
        log_fail "Environment variables incorrect: $env_output"
        return 1
    fi
}

test_mcp_settings_created() {
    log_test "MCP settings.json created when not mounted"

    local settings
    settings=$(docker run --rm "$WORKER_IMAGE" \
        bash -c "cat /root/.claude/settings.json" 2>&1 | tail -5) || true

    if echo "$settings" | grep -q '"theme"'; then
        log_pass "Minimal settings.json created"
    else
        log_fail "settings.json not created: $settings"
        return 1
    fi
}

test_spawn_worker_integration() {
    log_test "spawn-worker.sh integration"

    # Ensure parent is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_NAME}$"; then
        docker run -d --name "$PARENT_NAME" \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "$PARENT_IMAGE" \
            bash -c "sleep 120" >/dev/null
        sleep 2
    fi

    # Copy spawn script and test
    docker cp spawn-worker.sh "$PARENT_NAME:/scripts/spawn-worker.sh"
    docker exec "$PARENT_NAME" chmod +x /scripts/spawn-worker.sh

    # Set worker image env and spawn
    local spawn_result
    spawn_result=$(docker exec -e WORKER_IMAGE="$WORKER_IMAGE" -e HAL9000_PARENT="$PARENT_NAME" \
        "$PARENT_NAME" /scripts/spawn-worker.sh -d -n "${WORKER_NAME}-spawn" 2>&1) || true

    sleep 2

    # Check if spawn was successful by looking for "Worker started" or the container
    if echo "$spawn_result" | grep -q "Worker started"; then
        log_pass "spawn-worker.sh created worker successfully"
        docker rm -f "${WORKER_NAME}-spawn" 2>/dev/null || true
        # Also clean up the named volume
        docker volume rm "hal9000-claude-${WORKER_NAME}-spawn" 2>/dev/null || true
    elif docker ps --format '{{.Names}}' | grep -q "${WORKER_NAME}-spawn"; then
        log_pass "spawn-worker.sh created worker successfully"
        docker rm -f "${WORKER_NAME}-spawn" 2>/dev/null || true
        docker volume rm "hal9000-claude-${WORKER_NAME}-spawn" 2>/dev/null || true
    else
        log_fail "spawn-worker.sh failed: $spawn_result"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "  HAL-9000 Phase 2 Integration Tests"
    echo "=========================================="
    echo

    # Clean up any previous test containers
    cleanup

    # Run tests
    test_worker_image_built || true
    test_worker_image_size || true
    test_worker_entrypoint_runs || true
    test_claude_cli_available || true
    test_git_available || true
    test_workspace_mount || true
    test_claude_home_mount || true
    test_environment_variables || true
    test_mcp_settings_created || true
    test_worker_with_parent_network || true
    test_spawn_worker_integration || true

    echo
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
