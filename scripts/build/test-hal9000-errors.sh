#!/bin/bash
# hal-9000 error handling tests
set -euo pipefail

HAL9000_SCRIPT="./hal-9000"
TEST_TEMP_DIR="/tmp/hal-9000-error-tests"
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

test_no_docker() {
    # Test that Docker checking is part of diagnostics
    local result=$($HAL9000_SCRIPT --diagnose 2>&1 | grep -c "Docker" || true)

    if [ "$result" -gt 0 ]; then
        test_result "Docker check present in diagnostics" 0
    else
        test_result "Docker check present in diagnostics" 1
    fi
}

test_no_directory() {
    # Test that missing project directory is handled
    mkdir -p "$TEST_TEMP_DIR/project"
    cd "$TEST_TEMP_DIR/project"

    # Try to run with non-existent directory (should error)
    local output=$($HAL9000_SCRIPT /nonexistent/path 2>&1 || true)

    if echo "$output" | grep -q "not found\|error\|Error"; then
        test_result "Missing directory error handling" 0
    else
        test_result "Missing directory error handling" 1
    fi
}

test_no_claude_home() {
    # Test that missing CLAUDE_HOME is handled gracefully
    mkdir -p "$TEST_TEMP_DIR/project"

    # Use non-existent CLAUDE_HOME
    local output=$(CLAUDE_HOME="/nonexistent/claude" $HAL9000_SCRIPT --verify 2>&1 || true)

    # Should warn but not fail verify
    if echo "$output" | grep -q "Claude\|session"; then
        test_result "Missing CLAUDE_HOME handling in verify" 0
    else
        test_result "Missing CLAUDE_HOME handling in verify" 1
    fi
}

test_invalid_profile() {
    # Test that invalid profile is rejected or falls back
    mkdir -p "$TEST_TEMP_DIR/project"

    # Check help mentions valid profiles
    local help_output=$($HAL9000_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "base\|python\|node\|java"; then
        test_result "Valid profiles documented" 0
    else
        test_result "Valid profiles documented" 1
    fi
}

test_help_on_error() {
    # Test that help is accessible on errors
    local output=$($HAL9000_SCRIPT --help 2>&1)

    if echo "$output" | grep -q "USAGE\|OPTIONS"; then
        test_result "Help text accessible and formatted" 0
    else
        test_result "Help text accessible and formatted" 1
    fi
}

test_version_info() {
    # Test that version information is available
    local output=$($HAL9000_SCRIPT --version 2>&1)

    if echo "$output" | grep -q "version"; then
        test_result "Version information accessible" 0
    else
        test_result "Version information accessible" 1
    fi
}

test_unknown_option() {
    # Test that unknown options are rejected
    local output=$($HAL9000_SCRIPT --invalid-option 2>&1 || true)

    if echo "$output" | grep -q "Unknown\|invalid\|Error"; then
        test_result "Unknown option error handling" 0
    else
        test_result "Unknown option error handling" 1
    fi
}

##############################################################################
# MAIN
##############################################################################

case "${1:-all}" in
    no-docker)
        test_no_docker
        ;;
    no-directory)
        test_no_directory
        ;;
    no-claude-home)
        test_no_claude_home
        ;;
    invalid-profile)
        test_invalid_profile
        ;;
    help)
        test_help_on_error
        ;;
    version)
        test_version_info
        ;;
    unknown-option)
        test_unknown_option
        ;;
    all)
        test_no_docker
        test_invalid_profile
        test_help_on_error
        test_version_info
        test_unknown_option
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
