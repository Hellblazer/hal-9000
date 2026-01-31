#!/usr/bin/env bash
# run-all-tests.sh - Master test runner for HAL-9000 test suite
#
# Runs all test categories in sequence and reports aggregate results.
# Usage: ./run-all-tests.sh [--verbose] [--category=N] [--stop-on-fail]

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Options
VERBOSE=false
SPECIFIC_CATEGORY=""
STOP_ON_FAIL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --category=*)
            SPECIFIC_CATEGORY="${1#*=}"
            shift
            ;;
        --stop-on-fail|-s)
            STOP_ON_FAIL=true
            shift
            ;;
        --help|-h)
            cat << 'EOF'
HAL-9000 Test Suite Runner

Usage: ./run-all-tests.sh [OPTIONS]

Options:
  --verbose, -v           Show detailed test output
  --category=N            Run only category N (e.g., --category=01)
  --stop-on-fail, -s      Stop on first test failure
  --help, -h              Show this help

Test Categories:
  01 - Help & Version Commands
  02 - Setup & Authentication
  03 - Profile Detection
  04 - Session Management
  05 - Command-Line Arguments
  06 - Environment Variables
  10 - Error Handling & Edge Cases
  12 - Configuration & State Files

Examples:
  ./run-all-tests.sh                    # Run all tests
  ./run-all-tests.sh --verbose          # Run all with details
  ./run-all-tests.sh --category=02      # Run only category 2
  ./run-all-tests.sh --stop-on-fail     # Stop at first failure
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

# Test categories (in logical order)
TESTS=(
    "01:Help & Version Commands:test-category-01-help-version.sh"
    "02:Setup & Authentication:test-category-02-setup-authentication.sh"
    "03:Profile Detection:test-category-03-profile-detection.sh"
    "04:Session Management:test-category-04-session-management.sh"
    "05:Command-Line Arguments:test-category-05-command-line-arguments.sh"
    "06:Environment Variables:test-category-06-environment-variables.sh"
    "07:Docker Integration:test-category-07-docker-integration.sh"
    "08:Daemon & Pool Management:test-category-08-daemon-pool-management.sh"
    "09:Claude Passthrough:test-category-09-claude-passthrough.sh"
    "10:Error Handling & Edge Cases:test-category-10-error-handling.sh"
    "11:Installation & Distribution:test-category-11-installation-distribution.sh"
    "12:Configuration & State Files:test-category-12-configuration-state.sh"
    "13:Performance & Resource Usage:test-category-13-performance-resource-usage.sh"
    "14:Regression Test Suite:test-category-14-regression-suite.sh"
)

# Aggregate results
TOTAL_CATEGORIES=0
CATEGORIES_PASSED=0
CATEGORIES_FAILED=0
CATEGORIES_SKIPPED=0

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Header
echo ""
printf "${BOLD}${CYAN}================================================${NC}\n"
printf "${BOLD}${CYAN}    HAL-9000 Comprehensive Test Suite${NC}\n"
printf "${BOLD}${CYAN}================================================${NC}\n"
echo ""

# Check if Docker is available
DOCKER_AVAILABLE=false
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    DOCKER_AVAILABLE=true
    printf "${GREEN}✓${NC} Docker available\n"
else
    printf "${YELLOW}⚠${NC} Docker not available (some tests will be skipped)\n"
fi

echo ""

# Run tests
for test_spec in "${TESTS[@]}"; do
    IFS=':' read -r category_num category_name script_name <<< "$test_spec"

    # Skip if specific category requested and this isn't it
    if [[ -n "$SPECIFIC_CATEGORY" ]] && [[ "$category_num" != "$SPECIFIC_CATEGORY" ]]; then
        continue
    fi

    ((TOTAL_CATEGORIES++))

    TEST_SCRIPT="$SCRIPT_DIR/$script_name"

    if [[ ! -x "$TEST_SCRIPT" ]]; then
        printf "${RED}✗${NC} Category $category_num ($category_name): Script not found or not executable\n"
        ((CATEGORIES_FAILED++))
        continue
    fi

    printf "${BOLD}Running Category $category_num: $category_name${NC}\n"
    printf "${CYAN}────────────────────────────────────────────────${NC}\n"

    # Run test and capture output
    local test_output
    local test_exit_code=0

    if [[ "$VERBOSE" == "true" ]]; then
        # Show full output
        "$TEST_SCRIPT" || test_exit_code=$?
    else
        # Capture output, show summary only
        test_output=$("$TEST_SCRIPT" 2>&1) || test_exit_code=$?

        # Extract summary from output
        if echo "$test_output" | grep -q "Test Results"; then
            echo "$test_output" | sed -n '/Test Results/,/====/p'
        else
            echo "$test_output"
        fi
    fi

    # Parse results from output
    local passed skipped failed
    passed=$(echo "$test_output" | grep -oP 'Passed:\s+\K\d+' || echo "0")
    failed=$(echo "$test_output" | grep -oP 'Failed:\s+\K\d+' || echo "0")
    skipped=$(echo "$test_output" | grep -oP 'Skipped:\s+\K\d+' || echo "0")

    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed + skipped))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))

    # Category status
    if [[ $test_exit_code -eq 0 ]] && [[ $failed -eq 0 ]]; then
        printf "${GREEN}✓${NC} Category $category_num: PASSED\n"
        ((CATEGORIES_PASSED++))
    else
        printf "${RED}✗${NC} Category $category_num: FAILED\n"
        ((CATEGORIES_FAILED++))

        if [[ "$STOP_ON_FAIL" == "true" ]]; then
            printf "\n${RED}Stopping due to test failure (--stop-on-fail)${NC}\n"
            break
        fi
    fi

    echo ""
done

# Final summary
printf "${BOLD}${CYAN}================================================${NC}\n"
printf "${BOLD}${CYAN}    Final Test Results${NC}\n"
printf "${BOLD}${CYAN}================================================${NC}\n"
echo ""

printf "${BOLD}Categories:${NC}\n"
printf "  Total:   %d\n" "$TOTAL_CATEGORIES"
printf "  ${GREEN}Passed:  %d${NC}\n" "$CATEGORIES_PASSED"
if [[ $CATEGORIES_FAILED -gt 0 ]]; then
    printf "  ${RED}Failed:  %d${NC}\n" "$CATEGORIES_FAILED"
else
    printf "  Failed:  %d\n" "$CATEGORIES_FAILED"
fi
if [[ $CATEGORIES_SKIPPED -gt 0 ]]; then
    printf "  ${YELLOW}Skipped: %d${NC}\n" "$CATEGORIES_SKIPPED"
fi
echo ""

printf "${BOLD}Individual Tests:${NC}\n"
printf "  Total:   %d\n" "$TOTAL_TESTS"
printf "  ${GREEN}Passed:  %d${NC}\n" "$TOTAL_PASSED"
if [[ $TOTAL_FAILED -gt 0 ]]; then
    printf "  ${RED}Failed:  %d${NC}\n" "$TOTAL_FAILED"
else
    printf "  Failed:  %d\n" "$TOTAL_FAILED"
fi
if [[ $TOTAL_SKIPPED -gt 0 ]]; then
    printf "  ${YELLOW}Skipped: %d (manual/Docker-required)${NC}\n" "$TOTAL_SKIPPED"
fi
echo ""

# Exit status
if [[ $CATEGORIES_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}✓ All automated tests passed!${NC}\n"
    echo ""
    if [[ $TOTAL_SKIPPED -gt 0 ]]; then
        printf "${YELLOW}Note: $TOTAL_SKIPPED tests require manual execution or Docker${NC}\n"
        echo "See individual test scripts for manual test instructions."
    fi
    exit 0
else
    printf "${RED}${BOLD}✗ Some tests failed${NC}\n"
    echo ""
    printf "Run with ${CYAN}--verbose${NC} to see detailed output\n"
    exit 1
fi
