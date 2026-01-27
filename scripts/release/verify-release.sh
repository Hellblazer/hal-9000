#!/bin/bash
# verify-release.sh - End-to-end release verification for hal-9000

set -u

readonly RELEASE_VERSION="${1:-dev}"
readonly PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0

log_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

pass() {
    echo -e "${GREEN}✓${NC} $*"
    ((CHECKS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $*"
    ((CHECKS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

#==============================================================================
# 1. VERSION VERIFICATION
#==============================================================================

verify_versions() {
    log_section "1. Version Verification"

    local readme_version=$(grep "version-[0-9]*\.[0-9]*\.[0-9]*" "$PROJECT_ROOT/README.md" | grep -o "[0-9]*\.[0-9]*\.[0-9]*" | head -1)
    local cli_version=$(grep "SCRIPT_VERSION=" "$PROJECT_ROOT/hal-9000" | grep -o '"[^"]*"' | tr -d '"')
    local plugin_version=$(jq -r '.version' "$PROJECT_ROOT/plugins/hal-9000/.claude-plugin/plugin.json")
    local marketplace_version=$(jq -r '.plugins[0].version' "$PROJECT_ROOT/.claude-plugin/marketplace.json")

    echo "Versions found:"
    echo "  README.md badge: $readme_version"
    echo "  hal-9000 script: $cli_version"
    echo "  Plugin version: $plugin_version"
    echo "  Marketplace version: $marketplace_version"
    echo ""

    # Check they all match
    if [[ "$readme_version" == "$cli_version" ]]; then
        pass "README and CLI versions match: $cli_version"
    else
        fail "README ($readme_version) ≠ CLI ($cli_version)"
    fi

    if [[ "$cli_version" == "$plugin_version" ]]; then
        pass "CLI and Plugin versions match: $cli_version"
    else
        fail "CLI ($cli_version) ≠ Plugin ($plugin_version)"
    fi

    if [[ "$plugin_version" == "$marketplace_version" ]]; then
        pass "Plugin and Marketplace versions match: $plugin_version"
    else
        fail "Plugin ($plugin_version) ≠ Marketplace ($marketplace_version)"
    fi
}

#==============================================================================
# 2. JSON VALIDATION
#==============================================================================

verify_json() {
    log_section "2. JSON Configuration Validation"

    # Marketplace
    if jq empty "$PROJECT_ROOT/.claude-plugin/marketplace.json" 2>/dev/null; then
        pass "Valid JSON: marketplace.json"
    else
        fail "Invalid JSON: marketplace.json"
    fi

    # Plugin
    if jq empty "$PROJECT_ROOT/plugins/hal-9000/.claude-plugin/plugin.json" 2>/dev/null; then
        pass "Valid JSON: plugin.json"
    else
        fail "Invalid JSON: plugin.json"
    fi
}

#==============================================================================
# 3. DOCKER IMAGES
#==============================================================================

verify_docker_images() {
    log_section "3. Docker Image Verification"

    for profile in "base" "python" "node" "java"; do
        if docker images | grep -q "ghcr.io/hellblazer/hal-9000.*$profile"; then
            pass "Docker image exists: hal-9000:$profile"
        else
            fail "Docker image missing: hal-9000:$profile"
        fi
    done

    # Test base image
    if docker run --rm "ghcr.io/hellblazer/hal-9000:base" claude --version >/dev/null 2>&1; then
        pass "Base image is functional (Claude CLI accessible)"
    else
        fail "Base image is broken (Claude CLI not accessible)"
    fi
}

#==============================================================================
# 4. INSTALLATION SCRIPT
#==============================================================================

verify_install_script() {
    log_section "4. Installation Script Verification"

    if [[ -f "$PROJECT_ROOT/install-hal-9000.sh" && -x "$PROJECT_ROOT/install-hal-9000.sh" ]]; then
        pass "install-hal-9000.sh exists and is executable"
    else
        fail "install-hal-9000.sh missing or not executable"
        return
    fi

    if bash -n "$PROJECT_ROOT/install-hal-9000.sh" >/dev/null 2>&1; then
        pass "install-hal-9000.sh has valid bash syntax"
    else
        fail "install-hal-9000.sh has syntax errors"
    fi

    if [[ -f "$PROJECT_ROOT/hal-9000" ]]; then
        pass "Main hal-9000 script exists"
    else
        fail "Main hal-9000 script missing"
    fi
}

#==============================================================================
# 5. RELEASE NOTES
#==============================================================================

verify_release_notes() {
    log_section "5. Release Notes Verification"

    local release_notes="$PROJECT_ROOT/RELEASE_NOTES_v${RELEASE_VERSION}.md"

    if [[ -f "$release_notes" ]]; then
        pass "Release notes exist: RELEASE_NOTES_v${RELEASE_VERSION}.md"

        for section in "What's New" "Installation" "Verification"; do
            if grep -q "^#.*$section" "$release_notes"; then
                pass "  Contains: $section section"
            else
                warn "  Missing: $section section"
            fi
        done
    else
        fail "Release notes not found: $release_notes"
    fi
}

#==============================================================================
# 6. GIT
#==============================================================================

verify_git() {
    log_section "6. Git Repository Verification"

    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        pass "Git repository detected"
    else
        fail "Not a git repository"
        return
    fi

    if (cd "$PROJECT_ROOT" && git diff-index --quiet HEAD -- 2>/dev/null); then
        pass "Working tree is clean"
    else
        warn "Working tree has uncommitted changes"
    fi

    local tag="v${RELEASE_VERSION}"
    if (cd "$PROJECT_ROOT" && git tag -l | grep -q "^$tag$"); then
        pass "Git tag exists: $tag"
    else
        warn "Git tag not found: $tag"
    fi
}

#==============================================================================
# 7. MARKETPLACE
#==============================================================================

verify_marketplace() {
    log_section "7. Marketplace Verification"

    local marketplace="$PROJECT_ROOT/.claude-plugin/marketplace.json"

    for field in "name" "description" "owner" "plugins"; do
        if jq -e ".$field" "$marketplace" >/dev/null 2>&1; then
            pass "Marketplace has field: $field"
        else
            fail "Marketplace missing field: $field"
        fi
    done
}

#==============================================================================
# 8. DOCUMENTATION
#==============================================================================

verify_docs() {
    log_section "8. Documentation Verification"

    for doc in "README.md" "CLAUDE.md" "CONTRIBUTING.md"; do
        [[ -f "$PROJECT_ROOT/$doc" ]] && pass "Doc exists: $doc" || fail "Doc missing: $doc"
    done
}

#==============================================================================
# 9. INSTALLER URL
#==============================================================================

verify_install_url() {
    log_section "9. Installer URL Accessibility"

    local url="https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh"
    if curl -s --head "$url" 2>/dev/null | grep -q "200"; then
        pass "Installer URL is accessible"
    else
        warn "Could not verify installer URL (may be network issue)"
    fi
}

#==============================================================================
# SUMMARY
#==============================================================================

print_summary() {
    log_section "VERIFICATION SUMMARY"

    local total=$((CHECKS_PASSED + CHECKS_FAILED))
    local percentage=0
    [[ $total -gt 0 ]] && percentage=$((CHECKS_PASSED * 100 / total))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  $CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}  $CHECKS_FAILED"
    echo -e "  ${BLUE}Total:${NC}   $total"
    echo ""
    echo -e "  Score: ${BLUE}${percentage}%${NC}"
    echo ""

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ RELEASE VERIFIED - Ready for production${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Commit version changes: git add -A && git commit"
        echo "  2. Create GitHub release with assets"
        echo "  3. Publish release notes"
        return 0
    else
        echo -e "${RED}✗ VERIFICATION FAILED - Fix issues and retry${NC}"
        return 1
    fi
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  hal-9000 Release Verification v${RELEASE_VERSION}"
    echo -e "${BLUE}║${NC}  Comprehensive end-to-end release validation"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    verify_versions
    verify_json
    verify_docker_images
    verify_install_script
    verify_release_notes
    verify_git
    verify_marketplace
    verify_docs
    verify_install_url

    print_summary
}

main "$@"
