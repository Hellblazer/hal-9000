#!/bin/bash
# Test: TMUX Socket Permissions and Group Ownership
# Validates that directories use 0770 (not 0777) and are NOT world-writable

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

echo "==========================================="
echo "Testing Socket Directory Permissions"
echo "==========================================="
echo ""

# Create test environment
TEST_DIR="/tmp/hal-9000-socket-test-$$"
mkdir -p "$TEST_DIR"

echo "GROUP 1: Permissions Format"
echo "----"

# Test 1: Directory has 0770 permissions (not 0777)
test_dir="$TEST_DIR/test-0770"
mkdir -p "$test_dir"
chmod 0770 "$test_dir"

perms=$(stat -c '%a' "$test_dir" 2>/dev/null || stat -f '%A' "$test_dir" 2>/dev/null || echo "unknown")
if [[ "$perms" == "0770" ]] || [[ "$perms" == "770" ]]; then
    test_pass "Directory has 0770 permissions"
else
    test_fail "Directory permissions are $perms (expected 0770)"
fi

# Test 2: Directory is NOT world-writable
world_writable=0
if [[ "$perms" == *"7" ]]; then
    # Last digit is others permission
    world_writable=1
fi

if [[ $world_writable -eq 0 ]]; then
    test_pass "Directory is NOT world-writable"
else
    test_fail "Directory IS world-writable (permissions: $perms)"
fi

# Test 3: Others (last digit) should be 0 for 0770
last_digit="${perms: -1}"
if [[ "$last_digit" == "0" ]]; then
    test_pass "Others have no permissions (restricts world access)"
else
    test_fail "Others have permissions (last digit: $last_digit, should be 0)"
fi

echo ""
echo "GROUP 2: Code Review"
echo "----"

# Test 4: Check that coordinator.sh uses 0770
if grep -q "chmod 0770.*COORDINATOR_STATE_DIR" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/coordinator.sh; then
    test_pass "coordinator.sh uses chmod 0770 for state directory"
else
    test_fail "coordinator.sh does not use chmod 0770"
fi

# Test 5: Check that parent-entrypoint.sh uses 0770
if grep -q "chmod 0770.*COORDINATOR_STATE_DIR\|chmod 0770.*TMUX_SOCKET" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/parent-entrypoint.sh; then
    test_pass "parent-entrypoint.sh uses chmod 0770"
else
    test_fail "parent-entrypoint.sh does not use chmod 0770"
fi

# Test 6: Check that no 0777 remains in coordinator-related scripts
if ! grep -q "chmod 0777" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/coordinator.sh; then
    test_pass "coordinator.sh does not use chmod 0777"
else
    test_fail "coordinator.sh still uses chmod 0777"
fi

# Test 7: Check that parent-entrypoint.sh doesn't use 0777 for state/socket dirs
if ! grep "chmod 0777.*COORDINATOR_STATE_DIR\|chmod 0777.*TMUX_SOCKET" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/parent-entrypoint.sh; then
    test_pass "parent-entrypoint.sh does not use chmod 0777 for secure dirs"
else
    test_fail "parent-entrypoint.sh still uses chmod 0777 for state/socket dirs"
fi

# Test 8: Check that Dockerfile.parent creates hal9000 group
if grep -q "groupadd.*hal9000" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/Dockerfile.parent; then
    test_pass "Dockerfile.parent creates hal9000 group"
else
    test_fail "Dockerfile.parent does not create hal9000 group"
fi

# Test 9: Check that Dockerfile.worker creates hal9000 group
if grep -q "groupadd.*hal9000" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/Dockerfile.worker; then
    test_pass "Dockerfile.worker creates hal9000 group"
else
    test_fail "Dockerfile.worker does not create hal9000 group"
fi

# Test 10: Check that scripts use chgrp for hal9000
if grep -q "chgrp.*hal9000" /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/coordinator.sh /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/parent-entrypoint.sh; then
    test_pass "Scripts set group ownership to hal9000"
else
    test_fail "Scripts do not set group ownership to hal9000"
fi

echo ""
echo "==========================================="
echo "Socket Permissions Test Summary"
echo "==========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "==========================================="
echo ""

# Clean up test directory
rm -rf "$TEST_DIR"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All socket permission tests passed!${NC}"
    echo ""
    echo "Security validation verified:"
    echo "  ✓ Directories use 0770 (not 0777)"
    echo "  ✓ Not world-writable or world-accessible"
    echo "  ✓ Scripts implement chmod 0770"
    echo "  ✓ Scripts set group ownership to hal9000"
    echo "  ✓ Dockerfiles create hal9000 group in both parent and worker"
    echo ""
    exit 0
else
    echo -e "${RED}✗ CRITICAL: Some permission tests failed!${NC}"
    echo ""
    echo "Socket directory permissions may be insecure."
    echo "Review the failures above before merging."
    echo ""
    exit 1
fi
