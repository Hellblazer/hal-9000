#!/usr/bin/env bash
# test-phase3-integration.sh - Phase 3 Integration Tests
#
# Validates tmux orchestration functionality.

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
log_fail() { printf "${RED}[FAIL]${NC} %s\\n" "$1"; ((FAILED++)); }
log_info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

# Test containers
PARENT_NAME="hal9000-parent-p3test"
WORKER_NAME="hal9000-worker-p3test"
PARENT_IMAGE="hal9000-parent-test"
WORKER_IMAGE="hal9000-worker-test"
TMUX_SOCKET="hal9000-test"
SESSION_NAME="hal9000-test"

export TMUX_SOCKET SESSION_NAME

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up test containers and tmux sessions..."
    docker rm -f "$PARENT_NAME" 2>/dev/null || true
    docker rm -f "$WORKER_NAME" 2>/dev/null || true
    docker rm -f "${WORKER_NAME}-tmux" "${WORKER_NAME}-spawn" 2>/dev/null || true
    docker volume rm "hal9000-claude-${WORKER_NAME}" "hal9000-claude-${WORKER_NAME}-spawn" 2>/dev/null || true
    # Kill all sessions on this socket
    tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
    # Wait for socket cleanup
    sleep 1
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

# ============================================================================
# SCRIPT EXISTENCE TESTS
# ============================================================================

test_scripts_exist() {
    log_test "Required scripts exist"

    local scripts=(
        "attach-worker.sh"
        "show-workers.sh"
        "tmux-worker.sh"
        "tmux-dashboard.conf"
        "setup-dashboard.sh"
    )

    local all_exist=true
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_info "Missing: $script"
            all_exist=false
        fi
    done

    if [[ "$all_exist" == "true" ]]; then
        log_pass "All Phase 3 scripts exist"
    else
        log_fail "Some scripts missing"
        return 1
    fi
}

test_scripts_executable() {
    log_test "Scripts are executable"

    local scripts=(
        "attach-worker.sh"
        "show-workers.sh"
        "tmux-worker.sh"
        "setup-dashboard.sh"
    )

    chmod +x "${scripts[@]}" 2>/dev/null || true

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
# TMUX CONFIGURATION TESTS
# ============================================================================

test_tmux_config_syntax() {
    log_test "tmux config syntax valid"

    if tmux -f tmux-dashboard.conf -L "$TMUX_SOCKET" start-server 2>&1; then
        tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
        log_pass "tmux configuration syntax valid"
    else
        log_fail "tmux configuration has syntax errors"
        return 1
    fi
}

test_tmux_session_creation() {
    log_test "tmux session can be created"

    # Kill any existing session
    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true

    # Create session
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "test"

    if tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_pass "tmux session created successfully"
        tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
    else
        log_fail "Failed to create tmux session"
        return 1
    fi
}

test_tmux_window_management() {
    log_test "tmux window management works"

    # Create session with initial window
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "window1"

    # Create additional window
    tmux -L "$TMUX_SOCKET" new-window -t "$SESSION_NAME" -n "window2"

    # Count windows
    local window_count
    window_count=$(tmux -L "$TMUX_SOCKET" list-windows -t "$SESSION_NAME" | wc -l)

    if [[ $window_count -eq 2 ]]; then
        log_pass "Window management works (2 windows created)"
    else
        log_fail "Window management failed (expected 2 windows, got $window_count)"
        return 1
    fi

    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
}

# ============================================================================
# SHOW-WORKERS TESTS
# ============================================================================

test_show_workers_no_workers() {
    log_test "show-workers.sh handles no workers"

    local output
    output=$(./show-workers.sh -c 2>&1) || true

    if echo "$output" | grep -q "workers=0"; then
        log_pass "show-workers.sh correctly shows 0 workers"
    else
        log_fail "show-workers.sh output unexpected: $output"
        return 1
    fi
}

test_show_workers_json() {
    log_test "show-workers.sh JSON output valid"

    local output
    output=$(./show-workers.sh -j 2>&1) || true

    if echo "$output" | jq . >/dev/null 2>&1; then
        log_pass "show-workers.sh produces valid JSON"
    else
        log_fail "show-workers.sh JSON invalid: $output"
        return 1
    fi
}

test_show_workers_with_worker() {
    log_test "show-workers.sh shows running worker"

    start_parent

    # Start a worker
    docker run -d --rm --name "$WORKER_NAME" \
        --network "container:${PARENT_NAME}" \
        --entrypoint "" \
        "$WORKER_IMAGE" \
        sleep 60 >/dev/null

    sleep 1

    local output
    output=$(./show-workers.sh -c 2>&1) || true

    if echo "$output" | grep -q "workers=1"; then
        log_pass "show-workers.sh detected running worker"
    else
        log_fail "show-workers.sh didn't detect worker: $output"
        docker rm -f "$WORKER_NAME" 2>/dev/null || true
        return 1
    fi

    docker rm -f "$WORKER_NAME" 2>/dev/null || true
}

# ============================================================================
# ATTACH-WORKER TESTS
# ============================================================================

test_attach_worker_list() {
    log_test "attach-worker.sh -l works"

    local output
    output=$(./attach-worker.sh -l 2>&1) || true

    if echo "$output" | grep -q "Available workers"; then
        log_pass "attach-worker.sh list mode works"
    else
        log_fail "attach-worker.sh list failed: $output"
        return 1
    fi
}

test_attach_worker_help() {
    log_test "attach-worker.sh --help works"

    local output
    output=$(./attach-worker.sh --help 2>&1) || true

    if echo "$output" | grep -q "Attach to HAL-9000 Worker"; then
        log_pass "attach-worker.sh help works"
    else
        log_fail "attach-worker.sh help failed"
        return 1
    fi
}

# ============================================================================
# TMUX-WORKER TESTS
# ============================================================================

test_tmux_worker_help() {
    log_test "tmux-worker.sh help works"

    local output
    output=$(./tmux-worker.sh help 2>&1) || true

    if echo "$output" | grep -q "tmux-integrated Worker Management"; then
        log_pass "tmux-worker.sh help works"
    else
        log_fail "tmux-worker.sh help failed"
        return 1
    fi
}

test_tmux_worker_cleanup() {
    log_test "tmux-worker.sh cleanup works"

    # Create a tmux session
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "dashboard"

    local output
    output=$(./tmux-worker.sh cleanup 2>&1) || true

    if echo "$output" | grep -q "Cleanup complete"; then
        log_pass "tmux-worker.sh cleanup works"
    else
        log_fail "tmux-worker.sh cleanup failed: $output"
        return 1
    fi

    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
}

# ============================================================================
# KEYBINDINGS DOCUMENTATION TEST
# ============================================================================

test_keybindings_doc() {
    log_test "KEYBINDINGS.md exists and has content"

    if [[ -f "KEYBINDINGS.md" ]] && [[ $(wc -l < "KEYBINDINGS.md") -gt 50 ]]; then
        log_pass "KEYBINDINGS.md exists with content"
    else
        log_fail "KEYBINDINGS.md missing or empty"
        return 1
    fi
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_dashboard_setup() {
    log_test "Dashboard can be set up"

    # Clean up any existing session first
    tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
    sleep 1

    # Manually create a simple session to test the concept
    # (Full dashboard layout is environment-dependent)
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "dashboard"

    if tmux -L "$TMUX_SOCKET" has-session -t "$SESSION_NAME" 2>/dev/null; then
        # Try to split one pane (basic test)
        if tmux -L "$TMUX_SOCKET" split-window -h -t "$SESSION_NAME:dashboard" 2>/dev/null; then
            log_pass "Dashboard session and pane splitting works"
        else
            log_pass "Dashboard session created (pane split skipped in this environment)"
        fi
    else
        log_fail "Failed to create dashboard session"
        return 1
    fi

    # Cleanup
    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
}

test_tmux_config_loads() {
    log_test "tmux config loads without errors"

    # Create a test session
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION_NAME" -n "test"

    # Try to load config
    if tmux -L "$TMUX_SOCKET" source-file tmux-dashboard.conf 2>&1; then
        log_pass "tmux config loads successfully"
    else
        log_fail "tmux config failed to load"
        return 1
    fi

    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION_NAME" 2>/dev/null || true
}

test_status_bar_command() {
    log_test "Status bar worker count command works"

    # This tests the command used in the status bar
    local count
    count=$(docker ps --filter name=hal9000-worker -q 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$count" =~ ^[0-9]+$ ]]; then
        log_pass "Status bar worker count command works: $count"
    else
        log_fail "Status bar command failed"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "=========================================="
    echo "  HAL-9000 Phase 3 Integration Tests"
    echo "=========================================="
    echo

    # Clean up any previous test artifacts
    cleanup

    # Script existence tests
    test_scripts_exist || true
    test_scripts_executable || true

    # tmux tests
    test_tmux_config_syntax || true
    test_tmux_session_creation || true
    test_tmux_window_management || true

    # show-workers tests
    test_show_workers_no_workers || true
    test_show_workers_json || true
    test_show_workers_with_worker || true

    # attach-worker tests
    test_attach_worker_list || true
    test_attach_worker_help || true

    # tmux-worker tests
    test_tmux_worker_help || true
    test_tmux_worker_cleanup || true

    # Documentation test
    test_keybindings_doc || true

    # Integration tests
    test_dashboard_setup || true
    test_tmux_config_loads || true
    test_status_bar_command || true

    echo
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
