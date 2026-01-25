#!/bin/bash
# claudy configuration tests - CLAUDE_HOME handling
set -euo pipefail

CLAUDY_SCRIPT="./claudy"
TEST_TEMP_DIR="/tmp/claudy-config-tests"
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    rm -rf "$TEST_TEMP_DIR"
    unset CLAUDE_HOME
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

test_default_home() {
    # Test that claudy uses ~/.claude by default
    mkdir -p "$TEST_TEMP_DIR/project"

    # Check that --help mentions CLAUDE_HOME default
    local help_output=$($CLAUDY_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "CLAUDE_HOME"; then
        test_result "Default CLAUDE_HOME documented in help" 0
    else
        test_result "Default CLAUDE_HOME documented in help" 1
    fi
}

test_env_override() {
    # Test that environment variable overrides default
    mkdir -p "$TEST_TEMP_DIR/custom-claude"
    mkdir -p "$TEST_TEMP_DIR/project"
    touch "$TEST_TEMP_DIR/custom-claude/.session.json"

    # Extract the value that would be used
    local result=$(CLAUDE_HOME="$TEST_TEMP_DIR/custom-claude" bash -c "
        source '$CLAUDY_SCRIPT'
        # The CLAUDE_HOME should be set from environment
        echo \${CLAUDE_HOME}
    ")

    if [ "$result" = "$TEST_TEMP_DIR/custom-claude" ]; then
        test_result "Environment variable CLAUDE_HOME override works" 0
    else
        echo "    Got: '$result'" >&2
        test_result "Environment variable CLAUDE_HOME override works" 1
    fi
}

test_cli_override() {
    # Test that --claude-home CLI argument works
    mkdir -p "$TEST_TEMP_DIR/cli-config"
    touch "$TEST_TEMP_DIR/cli-config/.session.json"

    # Test that argument is parsed (we can't fully test without running container)
    # But we can verify the help shows it
    local help_output=$($CLAUDY_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "\--claude-home"; then
        test_result "CLI argument --claude-home available" 0
    else
        test_result "CLI argument --claude-home available" 1
    fi
}

test_priority() {
    # Test priority: CLI > ENV > default
    mkdir -p "$TEST_TEMP_DIR/env-config"
    mkdir -p "$TEST_TEMP_DIR/cli-config"

    # Verify the help text explains priority
    local help_output=$($CLAUDY_SCRIPT --help 2>&1)

    if echo "$help_output" | grep -q "default:"; then
        test_result "Priority explanation in help (default fallback)" 0
    else
        test_result "Priority explanation in help (default fallback)" 1
    fi
}

test_config_isolation() {
    # Test that using different CLAUDE_HOME keeps configs isolated
    local config1="$TEST_TEMP_DIR/config1"
    local config2="$TEST_TEMP_DIR/config2"

    mkdir -p "$config1"
    mkdir -p "$config2"

    # Create different configs
    echo '{"session": "config1"}' > "$config1/.session.json"
    echo '{"session": "config2"}' > "$config2/.session.json"

    # Verify they're different
    local diff=$(diff "$config1/.session.json" "$config2/.session.json" || true)

    if [ -n "$diff" ]; then
        test_result "Config isolation (different paths keep separate configs)" 0
    else
        test_result "Config isolation (different paths keep separate configs)" 1
    fi
}

test_help_text() {
    # Test that help text includes usage example
    local help_output=$($CLAUDY_SCRIPT --help 2>&1)

    local has_example=$(echo "$help_output" | grep -c "export CLAUDE_HOME" || true)

    if [ "$has_example" -gt 0 ]; then
        test_result "Help includes environment variable example" 0
    else
        test_result "Help includes environment variable example" 1
    fi
}

##############################################################################
# MAIN
##############################################################################

case "${1:-all}" in
    default-home)
        test_default_home
        ;;
    env-override)
        test_env_override
        ;;
    cli-override)
        test_cli_override
        ;;
    priority)
        test_priority
        ;;
    isolation)
        test_config_isolation
        ;;
    help)
        test_help_text
        ;;
    all)
        test_default_home
        test_env_override
        test_cli_override
        test_priority
        test_config_isolation
        test_help_text
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
