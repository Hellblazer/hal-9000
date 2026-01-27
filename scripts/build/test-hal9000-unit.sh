#!/bin/bash
# hal-9000 unit tests - profile detection, session naming, help system
set -euo pipefail

HAL9000_SCRIPT="./hal-9000"
TEST_TEMP_DIR="/tmp/hal-9000-unit-tests"
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

# Source hal-9000 functions for testing (extract functions from script)
source_hal-9000_functions() {
    # Source the hal-9000 script to get functions
    # Extract and source only the functions (skip main execution)
    source <(grep -E "^(detect_profile|get_session_name|show_help)\(\)|^[a-z_]+\(\)" "$HAL9000_SCRIPT" | head -100)
}

##############################################################################
# TEST CASES
##############################################################################

test_detect_java() {
    mkdir -p "$TEST_TEMP_DIR/java"
    touch "$TEST_TEMP_DIR/java/pom.xml"

    # Source the function and test it
    local result=$(bash -c "
        source '$HAL9000_SCRIPT'
        detect_profile '$TEST_TEMP_DIR/java'
    ")

    if [ "$result" = "java" ]; then
        test_result "Detect Java profile (pom.xml)" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Detect Java profile (pom.xml)" 1
    fi
}

test_detect_python() {
    mkdir -p "$TEST_TEMP_DIR/python"
    touch "$TEST_TEMP_DIR/python/pyproject.toml"

    local result=$(bash -c "
        source '$HAL9000_SCRIPT'
        detect_profile '$TEST_TEMP_DIR/python'
    ")

    if [ "$result" = "python" ]; then
        test_result "Detect Python profile (pyproject.toml)" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Detect Python profile (pyproject.toml)" 1
    fi
}

test_detect_node() {
    mkdir -p "$TEST_TEMP_DIR/node"
    touch "$TEST_TEMP_DIR/node/package.json"

    local result=$(bash -c "
        source '$HAL9000_SCRIPT'
        detect_profile '$TEST_TEMP_DIR/node'
    ")

    if [ "$result" = "node" ]; then
        test_result "Detect Node profile (package.json)" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Detect Node profile (package.json)" 1
    fi
}

test_detect_base() {
    mkdir -p "$TEST_TEMP_DIR/base"

    local result=$(bash -c "
        source '$HAL9000_SCRIPT'
        detect_profile '$TEST_TEMP_DIR/base'
    ")

    if [ "$result" = "base" ]; then
        test_result "Detect base profile (no markers)" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Detect base profile (no markers)" 1
    fi
}

test_session_naming() {
    mkdir -p "$TEST_TEMP_DIR/myproject"

    local result=$(bash -c "
        source '$HAL9000_SCRIPT'
        get_session_name '$TEST_TEMP_DIR/myproject'
    ")

    # Should be in format hal-9000-myproject-<hash>
    if [[ "$result" =~ ^hal-9000-myproject-[a-f0-9]{8}$ ]]; then
        test_result "Session naming format (hal-9000-{project}-{hash})" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Session naming format (hal-9000-{project}-{hash})" 1
    fi
}

test_session_deterministic() {
    mkdir -p "$TEST_TEMP_DIR/testproj"

    local result1=$(bash -c "
        source '$HAL9000_SCRIPT'
        get_session_name '$TEST_TEMP_DIR/testproj'
    ")

    local result2=$(bash -c "
        source '$HAL9000_SCRIPT'
        get_session_name '$TEST_TEMP_DIR/testproj'
    ")

    if [ "$result1" = "$result2" ]; then
        test_result "Session naming deterministic (same path = same name)" 0
    else
        echo "    Got: '$result1' vs '$result2'" >&2
        test_result "Session naming deterministic (same path = same name)" 1
    fi
}

test_help_system() {
    local result=$($HAL9000_SCRIPT --help 2>&1 | grep -c "USAGE:" || true)

    if [ "$result" -gt 0 ]; then
        test_result "Help system (--help output)" 0
    else
        test_result "Help system (--help output)" 1
    fi
}

test_version_system() {
    local result=$($HAL9000_SCRIPT --version 2>&1 | grep -c "hal-9000 version" || true)

    if [ "$result" -gt 0 ]; then
        test_result "Version system (--version output)" 0
    else
        test_result "Version system (--version output)" 1
    fi
}

##############################################################################
# MAIN
##############################################################################

case "${1:-all}" in
    detect-java)
        test_detect_java
        ;;
    detect-python)
        test_detect_python
        ;;
    detect-node)
        test_detect_node
        ;;
    detect-base)
        test_detect_base
        ;;
    session-naming)
        test_session_naming
        test_session_deterministic
        ;;
    help-system)
        test_help_system
        test_version_system
        ;;
    all)
        test_detect_java
        test_detect_python
        test_detect_node
        test_detect_base
        test_session_naming
        test_session_deterministic
        test_help_system
        test_version_system
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
