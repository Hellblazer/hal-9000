#!/usr/bin/env bash
# test-category-11-installation-distribution.sh - Test Installation & Distribution
#
# Tests install scripts, version consistency across artifacts,
# and marketplace integration.
#
# Test IDs: INST-001 to INST-012

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
TESTS_SKIPPED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; ((TESTS_PASSED++)) || true; }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; ((TESTS_FAILED++)) || true; }
log_skip() { printf "${YELLOW}[SKIP]${NC} %s\n" "$1"; ((TESTS_SKIPPED++)) || true; }
log_info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/install-hal-9000.sh"
UNINSTALL_SCRIPT="$REPO_ROOT/uninstall-hal-9000.sh"
HAL9000_CMD="$REPO_ROOT/hal-9000"
README="$REPO_ROOT/README.md"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
PLUGIN_JSON="$REPO_ROOT/plugins/hal-9000/.claude-plugin/plugin.json"

echo "=========================================="
echo "Test Category 11: Installation & Distribution"
echo "=========================================="
echo "Repository: $REPO_ROOT"
echo ""

#==========================================
# 11.1 Installation (INST-001 to INST-006)
#==========================================

test_inst_001() {
    log_test "INST-001: install-hal-9000.sh exists and is executable"

    if [[ -f "$INSTALL_SCRIPT" && -x "$INSTALL_SCRIPT" ]]; then
        log_pass "Install script exists and is executable"
    else
        log_fail "Install script missing or not executable at $INSTALL_SCRIPT"
    fi
}

test_inst_002() {
    log_test "INST-002: Install script supports INSTALL_PREFIX override"

    if [[ -f "$INSTALL_SCRIPT" ]]; then
        if grep -q "INSTALL_PREFIX" "$INSTALL_SCRIPT"; then
            log_pass "Install script supports INSTALL_PREFIX variable"
        else
            log_fail "Install script does not support INSTALL_PREFIX"
        fi
    else
        log_skip "Install script not found"
    fi
}

test_inst_003() {
    log_test "INST-003: Install script handles missing write permission"
    log_skip "Manual test - requires non-writable directory"
    echo "  1. INSTALL_PREFIX=/non-writable ./install-hal-9000.sh"
    echo "  2. Verify: Clear error message, no partial install"
}

test_inst_004() {
    log_test "INST-004: curl download end-to-end installation"
    log_skip "Manual test - requires network and GitHub"
    echo "  1. curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash"
    echo "  2. Verify: hal-9000 installed and works"
}

test_inst_005() {
    log_test "INST-005: Install script --verify flag checks prerequisites"

    if [[ -f "$INSTALL_SCRIPT" ]]; then
        if grep -q "\-\-verify" "$INSTALL_SCRIPT"; then
            log_pass "Install script supports --verify flag"
        else
            log_skip "Install script does not have --verify flag"
        fi
    else
        log_skip "Install script not found"
    fi
}

test_inst_006() {
    log_test "INST-006: uninstall-hal-9000.sh exists and is executable"

    if [[ -f "$UNINSTALL_SCRIPT" && -x "$UNINSTALL_SCRIPT" ]]; then
        log_pass "Uninstall script exists and is executable"
    else
        log_skip "Uninstall script not found (may not be implemented yet)"
    fi
}

#==========================================
# 11.2 Version Consistency (INST-007 to INST-009)
#==========================================

test_inst_007() {
    log_test "INST-007: Version consistency across README, plugin.json, hal-9000 script"

    local readme_version=""
    local plugin_version=""
    local script_version=""

    # Extract version from README badge
    if [[ -f "$README" ]]; then
        readme_version=$(grep -o 'version-[0-9.]*-blue' "$README" | head -1 | sed 's/version-\(.*\)-blue/\1/' || echo "")
    fi

    # Extract version from plugin.json
    if [[ -f "$PLUGIN_JSON" ]] && command -v jq &> /dev/null; then
        plugin_version=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "")
    fi

    # Extract version from hal-9000 script
    if [[ -f "$HAL9000_CMD" ]]; then
        script_version=$(grep -o 'SCRIPT_VERSION="[0-9.]*"' "$HAL9000_CMD" | head -1 | sed 's/SCRIPT_VERSION="\(.*\)"/\1/' || echo "")
    fi

    if [[ -n "$readme_version" && -n "$plugin_version" && -n "$script_version" ]]; then
        if [[ "$readme_version" == "$plugin_version" && "$plugin_version" == "$script_version" ]]; then
            log_pass "Version consistent across all files: $script_version"
        else
            log_fail "Version mismatch - README: $readme_version, Plugin: $plugin_version, Script: $script_version"
        fi
    else
        log_skip "Could not extract all versions (README: $readme_version, Plugin: $plugin_version, Script: $script_version)"
    fi
}

test_inst_008() {
    log_test "INST-008: hal-9000 --version output matches script version"

    if [[ ! -x "$HAL9000_CMD" ]]; then
        log_skip "hal-9000 command not found"
        return
    fi

    local output_version
    local script_version

    output_version=$("$HAL9000_CMD" --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "")
    script_version=$(grep -o 'SCRIPT_VERSION="[0-9.]*"' "$HAL9000_CMD" | head -1 | sed 's/SCRIPT_VERSION="\(.*\)"/\1/' || echo "")

    if [[ -n "$output_version" && -n "$script_version" ]]; then
        if [[ "$output_version" == "$script_version" ]]; then
            log_pass "--version output matches script version: $output_version"
        else
            log_fail "--version output ($output_version) != script version ($script_version)"
        fi
    else
        log_skip "Could not extract versions (output: $output_version, script: $script_version)"
    fi
}

test_inst_009() {
    log_test "INST-009: marketplace.json version matches"

    if [[ ! -f "$MARKETPLACE_JSON" ]]; then
        log_skip "marketplace.json not found at $MARKETPLACE_JSON"
        return
    fi

    if ! command -v jq &> /dev/null; then
        log_skip "jq not installed - cannot validate JSON"
        return
    fi

    local marketplace_version
    local plugin_version

    marketplace_version=$(jq -r '.plugins[] | select(.name=="hal-9000") | .version' "$MARKETPLACE_JSON" 2>/dev/null || echo "")

    if [[ -f "$PLUGIN_JSON" ]]; then
        plugin_version=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "")
    fi

    if [[ -n "$marketplace_version" && -n "$plugin_version" ]]; then
        if [[ "$marketplace_version" == "$plugin_version" ]]; then
            log_pass "marketplace.json version matches plugin.json: $marketplace_version"
        else
            log_fail "Marketplace version ($marketplace_version) != plugin version ($plugin_version)"
        fi
    else
        log_skip "Could not extract versions (marketplace: $marketplace_version, plugin: $plugin_version)"
    fi
}

#==========================================
# 11.3 Marketplace Integration (INST-010 to INST-012)
#==========================================

test_inst_010() {
    log_test "INST-010: plugin.json is valid JSON"

    if [[ ! -f "$PLUGIN_JSON" ]]; then
        log_fail "plugin.json not found at $PLUGIN_JSON"
        return
    fi

    if ! command -v jq &> /dev/null; then
        log_skip "jq not installed - cannot validate JSON"
        return
    fi

    if jq empty "$PLUGIN_JSON" 2>/dev/null; then
        log_pass "plugin.json is valid JSON"
    else
        log_fail "plugin.json has invalid JSON syntax"
    fi
}

test_inst_011() {
    log_test "INST-011: marketplace.json is valid JSON with correct structure"

    if [[ ! -f "$MARKETPLACE_JSON" ]]; then
        log_fail "marketplace.json not found at $MARKETPLACE_JSON"
        return
    fi

    if ! command -v jq &> /dev/null; then
        log_skip "jq not installed - cannot validate JSON"
        return
    fi

    if ! jq empty "$MARKETPLACE_JSON" 2>/dev/null; then
        log_fail "marketplace.json has invalid JSON syntax"
        return
    fi

    # Check structure has required fields
    local has_plugins
    has_plugins=$(jq 'has("plugins")' "$MARKETPLACE_JSON" 2>/dev/null || echo "false")

    if [[ "$has_plugins" == "true" ]]; then
        local plugin_count
        plugin_count=$(jq '.plugins | length' "$MARKETPLACE_JSON" 2>/dev/null || echo "0")
        log_pass "marketplace.json is valid with $plugin_count plugin(s)"
    else
        log_fail "marketplace.json missing 'plugins' field"
    fi
}

test_inst_012() {
    log_test "INST-012: Plugin installation from marketplace"
    log_skip "Manual test - requires Claude Code marketplace"
    echo "  1. Add marketplace to Claude Code settings"
    echo "  2. Install hal-9000 plugin from marketplace"
    echo "  3. Verify: Plugin available in Claude, MCP servers loaded"
}

#==========================================
# Main Test Runner
#==========================================

main() {
    # 11.1 Installation
    test_inst_001 || true
    test_inst_002 || true
    test_inst_003 || true
    test_inst_004 || true
    test_inst_005 || true
    test_inst_006 || true

    # 11.2 Version Consistency
    test_inst_007 || true
    test_inst_008 || true
    test_inst_009 || true

    # 11.3 Marketplace Integration
    test_inst_010 || true
    test_inst_011 || true
    test_inst_012 || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (manual or missing dependencies)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Manual tests require:"
        echo "  - Network access for curl installation"
        echo "  - Claude Code marketplace integration"
        echo "  - Write permission testing"
        echo ""
        echo "See test output above for manual test procedures."
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
