#!/bin/bash
#
# example-test.sh - Example test demonstrating volume isolation
#
# This is a template for writing tests that use the volume isolation framework.
# Each test:
#   1. Sources volume-helpers.sh
#   2. Sets up its own isolated volumes
#   3. Runs test logic using those volumes
#   4. Cleans up volumes automatically
#
# USAGE:
#   bash scripts/tests/example-test.sh AUTH-001
#   bash scripts/tests/example-test.sh INFO-002

set -Eeuo pipefail

# Get test ID from argument (or use placeholder)
TEST_ID="${1:-EXAMPLE-001}"

# Source the volume helpers (provides colors and functions)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

if [[ ! -f "$LIB_DIR/volume-helpers.sh" ]]; then
    echo "✗ Error: volume-helpers.sh not found" >&2
    exit 1
fi

source "$LIB_DIR/volume-helpers.sh"

#==============================================================================
# Test Implementation
#==============================================================================

# This test demonstrates volume isolation by:
# 1. Creating isolated volumes for the test
# 2. Running hal-9000 commands with those volumes
# 3. Verifying the commands executed correctly
# 4. Cleaning up automatically

run_test() {
    echo -e "${BLUE}Running test: $TEST_ID${NC}"
    echo ""

    # Verify volumes exist
    if ! test_volumes_exist "$TEST_ID"; then
        echo -e "${RED}✗ Test volumes not ready${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Test volumes ready:${NC}"
    list_test_volumes "$TEST_ID" | sed 's/^/  /'

    echo ""
    echo -e "${BLUE}Test Execution:${NC}"

    # Example: Verify hal-9000 --help works
    if bash /Users/hal.hildebrand/git/hal-9000/hal-9000 --help > /dev/null 2>&1; then
        echo -e "${GREEN}✓ hal-9000 --help succeeded${NC}"
    else
        echo -e "${RED}✗ hal-9000 --help failed${NC}" >&2
        return 1
    fi

    # Example: Verify exit code handling
    if bash /Users/hal.hildebrand/git/hal-9000/hal-9000 --invalid-option 2>&1 | grep -q "Unknown option"; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            echo -e "${GREEN}✓ Exit code 2 for invalid option${NC}"
        else
            echo -e "${YELLOW}⚠ Expected exit code 2, got $exit_code${NC}" >&2
        fi
    fi

    # Example: Verify Docker availability
    if docker ps &> /dev/null; then
        echo -e "${GREEN}✓ Docker is available${NC}"
    else
        echo -e "${RED}✗ Docker is not available${NC}" >&2
        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Test completed: $TEST_ID${NC}"
    return 0
}

#==============================================================================
# Main
#==============================================================================

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}hal-9000 Test with Volume Isolation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Setup test environment (volumes, Docker checks)
    if ! setup_test_environment "$TEST_ID"; then
        echo -e "${RED}✗ Failed to setup test environment${NC}" >&2
        exit 1
    fi

    echo ""

    # Run the actual test
    local test_result="fail"
    if run_test; then
        test_result="pass"
    else
        echo -e "${RED}✗ Test failed${NC}" >&2
    fi

    echo ""

    # Teardown test environment (cleanup volumes)
    if ! teardown_test_environment "$TEST_ID" "$test_result"; then
        echo -e "${YELLOW}⚠ Warning: issues during cleanup${NC}" >&2
    fi

    echo ""

    if [[ "$test_result" == "pass" ]]; then
        echo -e "${GREEN}✓ Test completed successfully${NC}"
        exit 0
    else
        echo -e "${RED}✗ Test failed${NC}" >&2
        exit 1
    fi
}

main "$@"
