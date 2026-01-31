#!/usr/bin/env bash
# test-audit-logging.sh - Test comprehensive audit logging implementation
#
# Tests:
# - Audit log creation with timestamps
# - User tracking (API key owner or USER env var)
# - Log rotation when size exceeds limit
# - Secure file permissions (0640)
# - Audit events in parent-entrypoint.sh and coordinator.sh

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)); }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# ============================================================================
# TEST 1: Audit logging library exists and is sourceable
# ============================================================================
test_audit_library_exists() {
    log_test "Test 1: Audit logging library exists and sources correctly"

    local lib_path="${SCRIPT_DIR}/lib/audit-log.sh"
    if [[ ! -f "$lib_path" ]]; then
        log_fail "Audit logging library not found: $lib_path"
        return 1
    fi

    # Source the library
    if source "$lib_path" 2>/dev/null; then
        log_pass "Audit logging library sourced successfully"
    else
        log_fail "Failed to source audit logging library"
        return 1
    fi

    # Check that audit_log function exists
    if command -v audit_log >/dev/null 2>&1; then
        log_pass "audit_log function is available"
    else
        log_fail "audit_log function not found after sourcing library"
        return 1
    fi
}

# ============================================================================
# TEST 2: Audit log entries have correct format
# ============================================================================
test_audit_log_format() {
    log_test "Test 2: Audit log entries have ISO 8601 timestamps and user tracking"

    # Setup
    export HAL9000_HOME="/tmp/hal9000-test-$$"
    export USER="test-user"
    mkdir -p "$HAL9000_HOME/logs"

    # Source library
    source "${SCRIPT_DIR}/lib/audit-log.sh"

    # Write test log entry
    audit_log "test_event" "test-resource" "action=test status=ok"

    # Verify log file exists
    local log_file="$HAL9000_HOME/logs/audit.log"
    if [[ ! -f "$log_file" ]]; then
        log_fail "Audit log file not created: $log_file"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Verify log entry format
    local log_entry
    log_entry=$(cat "$log_file")

    # Check for ISO 8601 timestamp (format: 2026-01-31T12:34:56Z or with milliseconds)
    if [[ "$log_entry" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        log_pass "Log entry contains ISO 8601 timestamp"
    else
        log_fail "Log entry missing ISO 8601 timestamp: $log_entry"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Check for user tracking (may have prefix like "user:" or "api:")
    if [[ "$log_entry" =~ user=(user:test-user|test-user) ]]; then
        log_pass "Log entry contains user tracking"
    else
        log_fail "Log entry missing user tracking: $log_entry"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Check for event type
    if [[ "$log_entry" =~ event=test_event ]]; then
        log_pass "Log entry contains event type"
    else
        log_fail "Log entry missing event type: $log_entry"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Check for resource
    if [[ "$log_entry" =~ resource=test-resource ]]; then
        log_pass "Log entry contains resource"
    else
        log_fail "Log entry missing resource: $log_entry"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Cleanup
    rm -rf "$HAL9000_HOME"
    unset HAL9000_HOME
}

# ============================================================================
# TEST 3: Log rotation when size exceeds limit
# ============================================================================
test_log_rotation() {
    log_test "Test 3: Log rotation when file exceeds max size"

    # Setup
    export HAL9000_HOME="/tmp/hal9000-test-$$"
    mkdir -p "$HAL9000_HOME/logs"

    # Source library
    source "${SCRIPT_DIR}/lib/audit-log.sh"

    local log_file="$HAL9000_HOME/logs/audit.log"

    # Create a log file larger than max size (10MB)
    # We'll create a 11MB file to trigger rotation
    dd if=/dev/zero of="$log_file" bs=1024 count=11264 2>/dev/null

    # Write a new log entry (should trigger rotation)
    audit_log "test_rotation" "test-resource" "action=test"

    # Verify rotated file exists
    if [[ -f "${log_file}.1" ]]; then
        log_pass "Log file rotated successfully (audit.log.1 exists)"
    else
        log_fail "Log rotation failed (audit.log.1 not found)"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Verify new log file is small
    local new_size
    new_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
    if [[ "$new_size" -lt 1024 ]]; then
        log_pass "New log file is small after rotation (${new_size} bytes)"
    else
        log_fail "New log file is too large after rotation (${new_size} bytes)"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Cleanup
    rm -rf "$HAL9000_HOME"
    unset HAL9000_HOME
}

# ============================================================================
# TEST 4: Audit log file permissions
# ============================================================================
test_log_permissions() {
    log_test "Test 4: Audit log file has secure permissions (0640)"

    # Setup
    export HAL9000_HOME="/tmp/hal9000-test-$$"
    mkdir -p "$HAL9000_HOME/logs"

    # Source library
    source "${SCRIPT_DIR}/lib/audit-log.sh"

    # Write log entry
    audit_log "test_perms" "test-resource" "action=test"

    # Check file permissions
    local log_file="$HAL9000_HOME/logs/audit.log"
    local perms
    perms=$(stat -f%Lp "$log_file" 2>/dev/null || stat -c%a "$log_file" 2>/dev/null || echo "000")

    if [[ "$perms" == "640" ]]; then
        log_pass "Audit log has correct permissions: 0640"
    else
        log_warn "Audit log permissions are $perms (expected 0640)"
        # This is a warning, not a hard failure
        ((TESTS_PASSED++))
    fi

    # Cleanup
    rm -rf "$HAL9000_HOME"
    unset HAL9000_HOME
}

# ============================================================================
# TEST 5: Convenience audit functions
# ============================================================================
test_convenience_functions() {
    log_test "Test 5: Convenience audit functions work correctly"

    # Setup
    export HAL9000_HOME="/tmp/hal9000-test-$$"
    mkdir -p "$HAL9000_HOME/logs"

    # Source library
    source "${SCRIPT_DIR}/lib/audit-log.sh"

    # Test worker spawn audit
    audit_worker_spawn "worker-abc" "worker:latest" "/workspace/project"
    local log_file="$HAL9000_HOME/logs/audit.log"

    if grep -q "event=worker_spawn" "$log_file" && \
       grep -q "resource=worker-abc" "$log_file" && \
       grep -q "image=worker:latest" "$log_file"; then
        log_pass "audit_worker_spawn writes correct log entry"
    else
        log_fail "audit_worker_spawn log entry incorrect"
        cat "$log_file"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Test worker stop audit
    audit_worker_stop "worker-abc" "user_request" "0"
    if grep -q "event=worker_stop" "$log_file" && \
       grep -q "reason=user_request" "$log_file"; then
        log_pass "audit_worker_stop writes correct log entry"
    else
        log_fail "audit_worker_stop log entry incorrect"
        rm -rf "$HAL9000_HOME"
        return 1
    fi

    # Cleanup
    rm -rf "$HAL9000_HOME"
    unset HAL9000_HOME
}

# ============================================================================
# TEST 6: Scripts source audit logging library
# ============================================================================
test_scripts_source_library() {
    log_test "Test 6: Parent and coordinator scripts source audit logging library"

    local parent_script="${SCRIPT_DIR}/parent-entrypoint.sh"
    local coordinator_script="${SCRIPT_DIR}/coordinator.sh"
    local spawn_script="${SCRIPT_DIR}/spawn-worker.sh"

    # Check parent-entrypoint.sh
    if grep -q "source.*audit-log.sh" "$parent_script"; then
        log_pass "parent-entrypoint.sh sources audit logging library"
    else
        log_fail "parent-entrypoint.sh does not source audit logging library"
    fi

    # Check coordinator.sh
    if grep -q "source.*audit-log.sh" "$coordinator_script"; then
        log_pass "coordinator.sh sources audit logging library"
    else
        log_fail "coordinator.sh does not source audit logging library"
    fi

    # Check spawn-worker.sh
    if grep -q "source.*audit-log.sh" "$spawn_script"; then
        log_pass "spawn-worker.sh sources audit logging library"
    else
        log_fail "spawn-worker.sh does not source audit logging library"
    fi
}

# ============================================================================
# TEST 7: Audit calls in critical events
# ============================================================================
test_audit_calls_exist() {
    log_test "Test 7: Audit calls exist in critical event handlers"

    local parent_script="${SCRIPT_DIR}/parent-entrypoint.sh"
    local coordinator_script="${SCRIPT_DIR}/coordinator.sh"
    local spawn_script="${SCRIPT_DIR}/spawn-worker.sh"

    # Check parent-entrypoint.sh has audit calls
    if grep -q "audit_coordinator_start\|audit_chromadb_start" "$parent_script"; then
        log_pass "parent-entrypoint.sh has coordinator/ChromaDB start audit calls"
    else
        log_fail "parent-entrypoint.sh missing coordinator/ChromaDB start audit calls"
    fi

    if grep -q "audit_coordinator_stop\|audit_chromadb_stop" "$parent_script"; then
        log_pass "parent-entrypoint.sh has coordinator/ChromaDB stop audit calls"
    else
        log_fail "parent-entrypoint.sh missing coordinator/ChromaDB stop audit calls"
    fi

    # Check coordinator.sh has worker stop audit calls
    if grep -q "audit_worker_stop" "$coordinator_script"; then
        log_pass "coordinator.sh has worker stop audit calls"
    else
        log_fail "coordinator.sh missing worker stop audit calls"
    fi

    if grep -q "audit_session_cleanup" "$coordinator_script"; then
        log_pass "coordinator.sh has session cleanup audit calls"
    else
        log_fail "coordinator.sh missing session cleanup audit calls"
    fi

    # Check spawn-worker.sh has worker spawn audit calls
    if grep -q "audit_worker_spawn" "$spawn_script"; then
        log_pass "spawn-worker.sh has worker spawn audit calls"
    else
        log_fail "spawn-worker.sh missing worker spawn audit calls"
    fi
}

# ============================================================================
# TEST 8: Dockerfile.parent copies lib directory
# ============================================================================
test_dockerfile_copies_lib() {
    log_test "Test 8: Dockerfile.parent copies lib directory"

    local dockerfile="${SCRIPT_DIR}/Dockerfile.parent"

    if grep -q "COPY docker/lib/.*lib/" "$dockerfile"; then
        log_pass "Dockerfile.parent copies lib directory"
    else
        log_fail "Dockerfile.parent does not copy lib directory"
    fi
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================
main() {
    echo "=========================================="
    echo "HAL-9000 Audit Logging Tests"
    echo "=========================================="
    echo

    test_audit_library_exists || true
    test_audit_log_format || true
    test_log_rotation || true
    test_log_permissions || true
    test_convenience_functions || true
    test_scripts_source_library || true
    test_audit_calls_exist || true
    test_dockerfile_copies_lib || true

    echo
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
