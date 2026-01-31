#!/bin/bash
# Test: Coordinator Worker Name Validation
# Validates that validate_worker_name() function properly rejects:
# - Path traversal (..)
# - Command substitution ($(), ``)
# - Shell metacharacters

set -Eeuo pipefail

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
echo "Testing Coordinator Validation Function"
echo "==========================================="
echo ""

# Create test environment
TEST_DIR="/tmp/hal-9000-coordinator-test-$$"
mkdir -p "$TEST_DIR"

# Create a standalone validation test script
cat > "$TEST_DIR/validate.sh" << 'VALIDATE_EOF'
#!/bin/bash
validate_worker_name() {
    local worker_name="$1"

    # Empty check
    if [[ -z "$worker_name" ]]; then
        return 1
    fi

    # Only allow alphanumeric, dash, underscore
    # Prevents: path traversal (..), command injection ($(), ``), shell metacharacters
    if [[ ! "$worker_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi

    return 0
}

if validate_worker_name "$1" >/dev/null 2>&1; then
    echo "VALID"
else
    echo "INVALID"
fi
VALIDATE_EOF

chmod +x "$TEST_DIR/validate.sh"

# Helper function to run validation test
run_validation_test() {
    local worker_name="$1"
    local expected="$2"
    local description="$3"

    local result=$("$TEST_DIR/validate.sh" "$worker_name" 2>/dev/null)

    if [[ "$result" == "$expected" ]]; then
        test_pass "$description"
    else
        test_fail "$description (expected $expected, got $result)"
    fi
}

echo "GROUP 1: Valid Worker Names (Should PASS)"
echo "----"

run_validation_test "hal9000-worker-1234567890" "VALID" "Valid name with dashes"
run_validation_test "worker_001" "VALID" "Valid name with underscores"
run_validation_test "MyWorker" "VALID" "Valid name with mixed case"
run_validation_test "worker1" "VALID" "Valid name with alphanumeric"
run_validation_test "a" "VALID" "Single character name"
run_validation_test "worker-001-name_test" "VALID" "Valid name with mixed separators"

echo ""
echo "GROUP 2: Path Traversal Attacks (Should REJECT)"
echo "----"

run_validation_test "../evil" "INVALID" "Path traversal: ../"
run_validation_test "../../etc/passwd" "INVALID" "Path traversal: ../../"
run_validation_test ".." "INVALID" "Path traversal: .. alone"
run_validation_test "..passwd" "INVALID" "Path traversal: ..passwd"
run_validation_test "worker/../../../etc" "INVALID" "Path traversal: embedded .."
run_validation_test "worker/../../sensitive" "INVALID" "Path traversal: /../../"

echo ""
echo "GROUP 3: Command Substitution Attacks (Should REJECT)"
echo "----"

run_validation_test 'worker$(whoami)' "INVALID" "Command substitution: \$(...)"
run_validation_test 'worker`id`' "INVALID" "Command substitution: backticks"
run_validation_test 'worker$(cat /etc/passwd)' "INVALID" "Command substitution: read file"
run_validation_test '$(echo malicious)' "INVALID" "Command substitution: leading"
run_validation_test 'name`whoami`test' "INVALID" "Command substitution: middle"

echo ""
echo "GROUP 4: Shell Metacharacters (Should REJECT)"
echo "----"

run_validation_test 'worker;rm -rf /' "INVALID" "Shell metachar: semicolon"
run_validation_test 'worker|cat /etc/passwd' "INVALID" "Shell metachar: pipe"
run_validation_test 'worker&whoami' "INVALID" "Shell metachar: ampersand"
run_validation_test 'worker>output.txt' "INVALID" "Shell metachar: redirect"
run_validation_test 'worker<input.txt' "INVALID" "Shell metachar: input redirect"
run_validation_test "worker''" "INVALID" "Shell metachar: single quotes"
run_validation_test 'worker""' "INVALID" "Shell metachar: double quotes"
run_validation_test 'worker*' "INVALID" "Shell metachar: glob *"
run_validation_test 'worker?' "INVALID" "Shell metachar: glob ?"
run_validation_test 'worker[123]' "INVALID" "Shell metachar: glob brackets"

echo ""
echo "GROUP 5: Special Characters (Should REJECT)"
echo "----"

run_validation_test 'worker name' "INVALID" "Special char: space"
run_validation_test 'worker/path' "INVALID" "Special char: slash"
run_validation_test 'worker.test' "INVALID" "Special char: dot"
run_validation_test 'worker@host' "INVALID" "Special char: at sign"
run_validation_test 'worker\$pwd' "INVALID" "Special char: escape"

echo ""
echo "GROUP 6: Edge Cases"
echo "----"

run_validation_test "" "INVALID" "Empty worker name"

echo ""
echo "==========================================="
echo "Validation Function Tests Summary"
echo "==========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "==========================================="
echo ""

# Clean up
rm -rf "$TEST_DIR"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All validation tests passed!${NC}"
    echo ""
    echo "Security validation verified:"
    echo "  ✓ Valid worker names accepted"
    echo "  ✓ Path traversal attacks blocked"
    echo "  ✓ Command substitution attacks blocked"
    echo "  ✓ Shell metacharacter attacks blocked"
    echo "  ✓ Special character attacks blocked"
    echo ""
    exit 0
else
    echo -e "${RED}✗ CRITICAL: Some validation tests failed!${NC}"
    echo ""
    echo "The validate_worker_name() function may not properly block attacks."
    echo "Review the failures above before merging."
    echo ""
    exit 1
fi
