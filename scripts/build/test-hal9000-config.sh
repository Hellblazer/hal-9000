#!/bin/bash
# hal-9000 configuration tests - Docker volume handling
set -euo pipefail

HAL9000_SCRIPT="./hal-9000"
TEST_TEMP_DIR="/tmp/hal-9000-config-tests"
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEST_TEMP_DIR"
}

trap cleanup EXIT

mkdir -p "$TEST_TEMP_DIR"

test_result() {
    local test_name="$1"
    local result="$2"

    if [ "$result" -eq 0 ]; then
        echo "  ✓ $test_name"
    else
        echo "  ✗ $test_name"
        FAILED=$((FAILED + 1))
    fi
}

##############################################################################
# TEST CASES
##############################################################################

test_volume_documentation() {
    # Test that help mentions Docker volumes (user-isolated)
    local help_output=$($HAL9000_SCRIPT --help 2>&1)

    # User-isolated volumes use hal9000-<type>-<hash> pattern
    if echo "$help_output" | grep -q "hal9000-claude-home-<hash>"; then
        test_result "Help documents hal9000-claude-home-<hash> volume" 0
    else
        test_result "Help documents hal9000-claude-home-<hash> volume" 1
    fi

    if echo "$help_output" | grep -q "hal9000-memory-bank-<hash>"; then
        test_result "Help documents hal9000-memory-bank-<hash> volume" 0
    else
        test_result "Help documents hal9000-memory-bank-<hash> volume" 1
    fi

    # Check for user isolation documentation
    if echo "$help_output" | grep -q "User-Isolated"; then
        test_result "Help documents user isolation" 0
    else
        test_result "Help documents user isolation" 1
    fi
}

test_command_passthrough() {
    # Test that help shows command passthrough examples
    local help_output=$($HAL9000_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "plugin install"; then
        test_result "Help shows plugin install passthrough" 0
    else
        test_result "Help shows plugin install passthrough" 1
    fi

    if echo "$help_output" | grep -q "mcp list"; then
        test_result "Help shows mcp list passthrough" 0
    else
        test_result "Help shows mcp list passthrough" 1
    fi
}

test_diagnose_shows_volumes() {
    # Test that --diagnose shows volume information
    local diag_output=$($HAL9000_SCRIPT --diagnose 2>&1) || true

    if echo "$diag_output" | grep -q "Docker Volumes"; then
        test_result "Diagnose shows Docker Volumes section" 0
    else
        test_result "Diagnose shows Docker Volumes section" 1
    fi
}

test_api_key_env() {
    # Test that help mentions ANTHROPIC_API_KEY
    local help_output=$($HAL9000_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "ANTHROPIC_API_KEY"; then
        test_result "Help documents ANTHROPIC_API_KEY" 0
    else
        test_result "Help documents ANTHROPIC_API_KEY" 1
    fi
}

test_no_legacy_options() {
    # Test that removed options are not present
    local help_output=$($HAL9000_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "\-\-claude-home"; then
        test_result "Removed option --claude-home NOT in help" 1
    else
        test_result "Removed option --claude-home NOT in help" 0
    fi

    if echo "$help_output" | grep -q "\-\-legacy"; then
        test_result "Removed option --legacy NOT in help" 1
    else
        test_result "Removed option --legacy NOT in help" 0
    fi
}

test_version() {
    # Test that version is 0.7.0+
    local version=$($HAL9000_SCRIPT --version 2>&1 | head -1)

    if echo "$version" | grep -qE "0\.[7-9]|[1-9]\.[0-9]"; then
        test_result "Version is 0.7.0+: $version" 0
    else
        test_result "Version is 0.7.0+: $version" 1
    fi
}

##############################################################################
# MAIN
##############################################################################

case "${1:-all}" in
    volumes)
        test_volume_documentation
        ;;
    passthrough)
        test_command_passthrough
        ;;
    diagnose)
        test_diagnose_shows_volumes
        ;;
    api-key)
        test_api_key_env
        ;;
    no-legacy)
        test_no_legacy_options
        ;;
    version)
        test_version
        ;;
    all)
        test_volume_documentation
        test_command_passthrough
        test_diagnose_shows_volumes
        test_api_key_env
        test_no_legacy_options
        test_version
        ;;
    *)
        echo "Unknown test: $1"
        exit 1
        ;;
esac

if [ $FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}✗ $FAILED test(s) failed${NC}"
    exit 1
fi
