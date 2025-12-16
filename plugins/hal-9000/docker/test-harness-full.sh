#!/bin/bash
# HAL-9000 Full Integration Test Harness
# Runs comprehensive tests on Ubuntu environment
#
# Usage:
#   ./run-full-tests.sh              # Run all tests
#   ./run-full-tests.sh --verbose    # Verbose output
#   ./run-full-tests.sh --skip-install  # Skip installation (test pre-installed)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false
SKIP_INSTALL=false
PASSED=0
FAILED=0
SKIPPED=0

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --skip-install) SKIP_INSTALL=true; shift ;;
        *) shift ;;
    esac
done

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIPPED=$((SKIPPED + 1)); }
verbose() { $VERBOSE && echo -e "       $1" || true; }

# Test functions
test_prerequisites() {
    log "Testing prerequisites..."
    local all_good=true

    for cmd in bash curl git python3 pip3 node npm tmux jq; do
        if command -v $cmd >/dev/null 2>&1; then
            verbose "$cmd: $(command -v $cmd)"
        else
            fail "Missing: $cmd"
            all_good=false
        fi
    done

    $all_good && pass "All prerequisites installed"
}

test_hal9000_install() {
    log "Testing hal-9000 installation..."

    if $SKIP_INSTALL; then
        skip "Installation (--skip-install)"
        return 0
    fi

    cd /hal-9000-src

    # Run installer in host-only mode (option 2)
    if echo "2" | timeout 600 ./install.sh 2>&1 | tee /tmp/install.log; then
        pass "Installation completed"
        verbose "See /tmp/install.log for details"
    else
        fail "Installation failed"
        echo "--- Last 50 lines of install log ---"
        tail -50 /tmp/install.log
        return 1
    fi
}

test_mcp_servers_installed() {
    log "Testing MCP server installation..."
    local all_good=true

    # Check Python-based MCP servers
    if command -v chroma-mcp >/dev/null 2>&1 || pip3 show chromadb-mcp >/dev/null 2>&1; then
        verbose "chroma-mcp: installed"
    else
        fail "chroma-mcp not found"
        all_good=false
    fi

    # Check Node-based MCP servers
    if npm list -g @allpepper/memory-bank-mcp >/dev/null 2>&1; then
        verbose "memory-bank-mcp: installed"
    else
        fail "memory-bank-mcp not found"
        all_good=false
    fi

    if npm list -g @modelcontextprotocol/server-sequential-thinking >/dev/null 2>&1; then
        verbose "sequential-thinking: installed"
    else
        fail "sequential-thinking not found"
        all_good=false
    fi

    $all_good && pass "MCP servers installed"
}

test_safety_hooks_installed() {
    log "Testing safety hooks installation..."

    HOOKS_DIR="$HOME/.claude/hooks/claude-code-tools"

    if [ -d "$HOOKS_DIR" ]; then
        local hook_count=$(ls -1 "$HOOKS_DIR"/*.py 2>/dev/null | wc -l)
        if [ "$hook_count" -ge 6 ]; then
            pass "Safety hooks installed ($hook_count hooks)"
            verbose "Location: $HOOKS_DIR"
        else
            fail "Expected 6+ hooks, found $hook_count"
        fi
    else
        fail "Hooks directory not found: $HOOKS_DIR"
    fi
}

test_agents_installed() {
    log "Testing custom agents installation..."

    AGENTS_DIR="$HOME/.claude/agents"

    if [ -d "$AGENTS_DIR" ]; then
        local agent_count=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
        if [ "$agent_count" -ge 10 ]; then
            pass "Custom agents installed ($agent_count agents)"
            verbose "Location: $AGENTS_DIR"
        else
            fail "Expected 10+ agents, found $agent_count"
        fi
    else
        fail "Agents directory not found: $AGENTS_DIR"
    fi
}

test_commands_installed() {
    log "Testing session commands installation..."

    COMMANDS_DIR="$HOME/.claude/commands"

    if [ -d "$COMMANDS_DIR" ]; then
        local cmd_count=$(ls -1 "$COMMANDS_DIR"/*.md 2>/dev/null | wc -l)
        if [ "$cmd_count" -ge 3 ]; then
            pass "Session commands installed ($cmd_count commands)"
        else
            fail "Expected 3+ commands, found $cmd_count"
        fi
    else
        fail "Commands directory not found: $COMMANDS_DIR"
    fi
}

test_tmux_cli_installed() {
    log "Testing tmux-cli installation..."

    if command -v tmux-cli >/dev/null 2>&1; then
        pass "tmux-cli installed"
        verbose "$(tmux-cli --version 2>&1 | head -1 || echo 'version unknown')"
    else
        fail "tmux-cli not found"
    fi
}

test_docker_available() {
    log "Testing Docker availability..."

    if [ -S /var/run/docker.sock ]; then
        if docker info >/dev/null 2>&1; then
            pass "Docker available"
            verbose "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'version unknown')"
        else
            fail "Docker socket exists but daemon not accessible"
        fi
    else
        skip "Docker socket not mounted"
    fi
}

test_hal9000_container() {
    log "Testing hal9000 container from ghcr.io..."

    if ! [ -S /var/run/docker.sock ]; then
        skip "Docker not available"
        return 0
    fi

    # Pull and test the container
    if docker pull ghcr.io/hellblazer/hal-9000:latest >/dev/null 2>&1; then
        if docker run --rm ghcr.io/hellblazer/hal-9000:latest echo "hal9000 works" >/dev/null 2>&1; then
            pass "hal9000 container runs successfully"
        else
            fail "hal9000 container failed to run"
        fi
    else
        fail "Could not pull hal9000 container"
    fi
}

# Main test runner
main() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  HAL-9000 Full Integration Tests (Ubuntu)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    # Phase 1: Prerequisites
    echo -e "${YELLOW}Phase 1: Prerequisites${NC}"
    test_prerequisites
    echo ""

    # Phase 2: Installation
    echo -e "${YELLOW}Phase 2: Installation${NC}"
    test_hal9000_install
    echo ""

    # Phase 3: MCP Servers
    echo -e "${YELLOW}Phase 3: MCP Servers${NC}"
    test_mcp_servers_installed
    echo ""

    # Phase 4: Components
    echo -e "${YELLOW}Phase 4: Components${NC}"
    test_safety_hooks_installed
    test_agents_installed
    test_commands_installed
    test_tmux_cli_installed
    echo ""

    # Phase 5: Container Tests
    echo -e "${YELLOW}Phase 5: Container Tests${NC}"
    test_docker_available
    test_hal9000_container
    echo ""

    # Summary
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"

    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}TESTS FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    fi
}

main "$@"
