#!/usr/bin/env bash
# test-seccomp.sh - Test seccomp profiles don't break Claude CLI functionality
#
# Tests various Claude CLI operations with seccomp profiles applied
# to ensure no legitimate syscalls are blocked.

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

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)) || true; }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)) || true; }
log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Seccomp profiles
AUDIT_PROFILE="$SCRIPT_DIR/hal9000-audit.json"
BASE_PROFILE="$SCRIPT_DIR/hal9000-base.json"

# Test mode (audit or enforce)
TEST_MODE="${1:-audit}"

if [[ "$TEST_MODE" == "audit" ]]; then
    SECCOMP_PROFILE="$AUDIT_PROFILE"
    log_info "Testing in AUDIT mode (logs violations, doesn't block)"
elif [[ "$TEST_MODE" == "enforce" ]]; then
    SECCOMP_PROFILE="$BASE_PROFILE"
    log_info "Testing in ENFORCE mode (blocks dangerous syscalls)"
else
    echo "Usage: $0 [audit|enforce]"
    exit 2
fi

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo "ERROR: Docker daemon not running"
    exit 1
fi

# Check profile exists
if [[ ! -f "$SECCOMP_PROFILE" ]]; then
    echo "ERROR: Seccomp profile not found: $SECCOMP_PROFILE"
    exit 1
fi

log_info "Using seccomp profile: $(basename "$SECCOMP_PROFILE")"
echo ""

# Validate JSON syntax
log_test "Validate seccomp profile JSON syntax"
if jq empty "$SECCOMP_PROFILE" 2>/dev/null; then
    log_pass "JSON syntax valid"
else
    log_fail "Invalid JSON in seccomp profile"
    exit 1
fi

# Test 1: Basic container operations
log_test "Test basic container operations with seccomp"
TEST_DIR=$(mktemp -d)

if docker run --rm \
    --security-opt seccomp="$SECCOMP_PROFILE" \
    -v "$TEST_DIR:/workspace" \
    alpine:latest \
    sh -c 'echo "test" > /workspace/test.txt && cat /workspace/test.txt' >/dev/null 2>&1; then
    log_pass "Basic file operations work"
else
    log_fail "Basic file operations failed"
fi

rm -rf "$TEST_DIR"

# Test 2: Network operations
log_test "Test network operations with seccomp"
if docker run --rm \
    --security-opt seccomp="$SECCOMP_PROFILE" \
    alpine:latest \
    sh -c 'ping -c 1 8.8.8.8' >/dev/null 2>&1; then
    log_pass "Network operations work"
else
    log_warn "Network operations failed (may be firewall/network issue)"
fi

# Test 3: Process operations
log_test "Test process fork/exec with seccomp"
if docker run --rm \
    --security-opt seccomp="$SECCOMP_PROFILE" \
    alpine:latest \
    sh -c 'for i in 1 2 3; do echo $i & done; wait' >/dev/null 2>&1; then
    log_pass "Process fork/exec works"
else
    log_fail "Process operations failed"
fi

# Test 4: Node.js operations (simulate Claude CLI environment)
log_test "Test Node.js with seccomp (Claude CLI runtime)"
if docker run --rm \
    --security-opt seccomp="$SECCOMP_PROFILE" \
    node:20-bookworm-slim \
    node -e 'console.log("Node.js works"); process.exit(0)' >/dev/null 2>&1; then
    log_pass "Node.js operations work"
else
    log_fail "Node.js operations failed"
fi

# Test 5: File system operations
log_test "Test filesystem operations with seccomp"
TEST_DIR=$(mktemp -d)

if docker run --rm \
    --security-opt seccomp="$SECCOMP_PROFILE" \
    -v "$TEST_DIR:/workspace" \
    alpine:latest \
    sh -c 'mkdir /workspace/dir && touch /workspace/dir/file && rm -rf /workspace/dir' >/dev/null 2>&1; then
    log_pass "Filesystem operations work"
else
    log_fail "Filesystem operations failed"
fi

rm -rf "$TEST_DIR"

# Test 6: Verify dangerous syscalls are blocked (enforce mode only)
if [[ "$TEST_MODE" == "enforce" ]]; then
    log_test "Verify dangerous syscalls are blocked"

    # Try to mount (should fail)
    if docker run --rm \
        --security-opt seccomp="$SECCOMP_PROFILE" \
        --cap-add=SYS_ADMIN \
        alpine:latest \
        mount -t tmpfs tmpfs /mnt 2>/dev/null; then
        log_fail "Mount syscall not blocked (security risk!)"
    else
        log_pass "Mount syscall properly blocked"
    fi

    # Note: More dangerous syscall tests would require privileged containers
    # and specific setup, so we keep this minimal
fi

# Test 7: JSON structure validation
log_test "Validate seccomp profile structure"
REQUIRED_FIELDS=("defaultAction" "syscalls")
VALID=true

for field in "${REQUIRED_FIELDS[@]}"; do
    if ! jq -e ".$field" "$SECCOMP_PROFILE" >/dev/null 2>&1; then
        log_warn "Missing required field: $field"
        VALID=false
    fi
done

if [[ "$VALID" == "true" ]]; then
    log_pass "Seccomp profile structure valid"
else
    log_fail "Seccomp profile structure invalid"
fi

# Test 8: Validate architecture support
log_test "Validate architecture support in profile"
if jq -e '.archMap[] | select(.architecture == "SCMP_ARCH_X86_64")' "$SECCOMP_PROFILE" >/dev/null 2>&1; then
    log_pass "x86_64 architecture supported"
else
    log_warn "x86_64 architecture not in archMap"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo "=========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✅ All tests passed!"
    echo ""
    if [[ "$TEST_MODE" == "audit" ]]; then
        echo "Next step: Review audit logs for syscall violations"
        echo "  sudo journalctl -k | grep SECCOMP"
        echo ""
        echo "Then test in enforce mode:"
        echo "  $0 enforce"
    else
        echo "Seccomp profile validated in enforce mode!"
        echo "Profile ready for production use."
    fi
    exit 0
else
    echo "❌ Some tests failed"
    echo ""
    echo "Investigate failures before using profile in production."
    exit 1
fi
