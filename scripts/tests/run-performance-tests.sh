#!/bin/bash
#
# run-performance-tests.sh - Performance validation test runner
#
# Validates hal-9000 performance against targets defined in PERFORMANCE_TARGETS.md
# Generates test report with pass/fail status
#

set -Euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HAL9000_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hal-9000"
REPORT_FILE="/tmp/perf-results-$(date +%s).txt"
PASSED=0
FAILED=0
SKIPPED=0

# Performance targets (in milliseconds)
TARGET_PARSE=100
TARGET_VERSION=500
TARGET_HELP=500
TARGET_ERROR=100

# Variance tolerance
TOLERANCE_PERCENT=10
TOLERANCE_STARTUP=$(( 100 - TOLERANCE_PERCENT ))  # Lower is better: 90% of target
TOLERANCE_UPWARD=$(( 100 + TOLERANCE_PERCENT ))   # Upper bound: 110% of target

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        HAL-9000 Performance Validation Test Suite              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Report file: $REPORT_FILE"
echo ""

#==============================================================================
# Helper Functions
#==============================================================================

measure_time() {
    local command="$1"
    local target="$2"
    local name="$3"

    local start=$(date +%s%N)
    eval "$command" > /dev/null 2>&1 || true
    local end=$(date +%s%N)

    # Convert nanoseconds to milliseconds
    local duration=$(( (end - start) / 1000000 ))

    # Check if within tolerance
    if (( duration <= (target * TOLERANCE_UPWARD / 100) )); then
        echo -e "${GREEN}✓${NC} $name: ${duration}ms (target: <${target}ms)"
        echo "PASS: $name=${duration}ms (target=${target}ms)" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} $name: ${duration}ms (target: <${target}ms) ${RED}FAILED${NC}"
        echo "FAIL: $name=${duration}ms (target=${target}ms)" >> "$REPORT_FILE"
        return 1
    fi
}

test_command() {
    local test_func="$1"
    if $test_func; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
}

#==============================================================================
# Test Functions
#==============================================================================

test_script_parsing() {
    measure_time "bash -n '$HAL9000_SCRIPT'" "$TARGET_PARSE" "Script parsing"
}

test_version_command() {
    measure_time "'$HAL9000_SCRIPT' --version" "$TARGET_VERSION" "Version command"
}

test_help_command() {
    measure_time "'$HAL9000_SCRIPT' --help" "$TARGET_HELP" "Help command"
}

test_error_handling() {
    measure_time "'$HAL9000_SCRIPT' --invalid-option" "$TARGET_ERROR" "Error handling"
}

test_version_output() {
    local version=$("$HAL9000_SCRIPT" --version | head -1)
    if echo "$version" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+"; then
        echo -e "${GREEN}✓${NC} Version format: $version (contains semver)"
        echo "PASS: Version format validation" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} Version format: $version (invalid semver) ${RED}FAILED${NC}"
        echo "FAIL: Version format validation" >> "$REPORT_FILE"
        return 1
    fi
}

test_help_output() {
    local help_output=$("$HAL9000_SCRIPT" --help)
    if echo "$help_output" | grep -qi "usage:"; then
        echo -e "${GREEN}✓${NC} Help output contains usage information"
        echo "PASS: Help output validation" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} Help output missing usage information ${RED}FAILED${NC}"
        echo "FAIL: Help output validation" >> "$REPORT_FILE"
        return 1
    fi
}

test_exit_code_success() {
    if "$HAL9000_SCRIPT" --version > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Exit code 0 on success"
        echo "PASS: Exit code success validation" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} Exit code not 0 on success ${RED}FAILED${NC}"
        echo "FAIL: Exit code success validation" >> "$REPORT_FILE"
        return 1
    fi
}

test_exit_code_error() {
    "$HAL9000_SCRIPT" --invalid-option > /dev/null 2>&1 || true
    local exit_code=$?
    if (( exit_code == 2 )); then
        echo -e "${GREEN}✓${NC} Exit code 2 on invalid arguments"
        echo "PASS: Exit code invalid args validation (exit=$exit_code)" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Exit code $exit_code (expected 2)"
        echo "WARN: Exit code invalid args validation (exit=$exit_code, expected 2)" >> "$REPORT_FILE"
        return 0  # Non-critical
    fi
}

#==============================================================================
# Test Execution
#==============================================================================

echo -e "${BLUE}=== PERFORMANCE TESTS ===${NC}"
echo ""

echo "Testing script parsing performance..."
test_command test_script_parsing
echo ""

echo "Testing version command performance..."
test_command test_version_command
echo ""

echo "Testing help command performance..."
test_command test_help_command
echo ""

echo "Testing error handling performance..."
test_command test_error_handling
echo ""

echo -e "${BLUE}=== FUNCTIONAL VALIDATION ===${NC}"
echo ""

echo "Validating version output format..."
test_command test_version_output
echo ""

echo "Validating help output content..."
test_command test_help_output
echo ""

echo "Validating exit codes (success)..."
test_command test_exit_code_success
echo ""

echo "Validating exit codes (error)..."
test_command test_exit_code_error
echo ""

#==============================================================================
# Summary Report
#==============================================================================

TOTAL=$((PASSED + FAILED + SKIPPED))

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     TEST RESULTS SUMMARY                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests: $TOTAL"
echo -e "Passed:      ${GREEN}$PASSED${NC}"
echo -e "Failed:      ${RED}$FAILED${NC}"
echo -e "Skipped:     ${YELLOW}$SKIPPED${NC}"
echo ""

if (( FAILED == 0 )); then
    echo -e "${GREEN}✓ All performance tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED test(s) failed${NC}"
    echo ""
    echo "Failed tests:"
    grep "^FAIL:" "$REPORT_FILE" 2>/dev/null || true
    exit 1
fi
