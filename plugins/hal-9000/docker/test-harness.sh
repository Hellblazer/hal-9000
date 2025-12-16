#!/bin/bash
# HAL-9000 Integration Test Harness
# Runs comprehensive tests of hal-9000 installation and functionality
#
# Usage:
#   ./run-tests.sh              # Run all tests
#   ./run-tests.sh --quick      # Run quick smoke tests only
#   ./run-tests.sh --verbose    # Verbose output

set -e

# Force unbuffered output
exec 1>&1 2>&1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false
QUICK=false
PASSED=0
FAILED=0
SKIPPED=0

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --quick|-q) QUICK=true; shift ;;
        *) shift ;;
    esac
done

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIPPED=$((SKIPPED + 1)); }
verbose() { $VERBOSE && echo -e "       $1" || true; }

# Test functions
test_docker_available() {
    log "Testing Docker availability..."
    if docker info >/dev/null 2>&1; then
        pass "Docker daemon is running"
        verbose "$(docker version --format '{{.Server.Version}}')"
        return 0
    else
        fail "Docker daemon not available"
        return 1
    fi
}

test_install_prerequisites() {
    log "Testing prerequisites..."
    local all_good=true

    for cmd in bash curl git python3 node npm tmux jq; do
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

    if $QUICK; then
        skip "Full installation (--quick mode)"
        return 0
    fi

    cd /hal-9000-src/plugins/hal-9000

    # Run installer in host-only mode (option 2) for faster testing
    if echo "2" | timeout 300 ./install.sh 2>&1 | tee /tmp/install.log; then
        pass "Installation completed"
        verbose "See /tmp/install.log for details"
    else
        fail "Installation failed"
        cat /tmp/install.log
        return 1
    fi
}

test_mcp_servers_installed() {
    log "Testing MCP server installation..."

    if $QUICK; then
        skip "MCP server check (--quick mode, no install)"
        return 0
    fi

    local all_good=true

    # Check Python-based MCP servers
    if command -v chroma-mcp >/dev/null 2>&1; then
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

    if $QUICK; then
        skip "Safety hooks check (--quick mode, no install)"
        return 0
    fi

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

test_beads_installed() {
    log "Testing beads (bd) installation..."

    if command -v bd >/dev/null 2>&1; then
        pass "bd CLI installed"
        verbose "$(bd --version 2>&1 | head -1)"
    else
        skip "bd not installed (requires Homebrew on macOS)"
    fi
}

test_agents_installed() {
    log "Testing custom agents installation..."

    if $QUICK; then
        skip "Agents check (--quick mode, no install)"
        return 0
    fi

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

    if $QUICK; then
        skip "Commands check (--quick mode, no install)"
        return 0
    fi

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

test_hal9000_container_build() {
    log "Testing hal9000 container build..."

    if $QUICK; then
        skip "Container build (--quick mode)"
        return 0
    fi

    # Pull the base image
    if docker pull ghcr.io/hellblazer/hal-9000:latest >/dev/null 2>&1; then
        pass "hal9000 base image available"
        verbose "ghcr.io/hellblazer/hal-9000:latest"
    else
        fail "Could not pull hal9000 base image"
        return 1
    fi
}

test_hal9000_container_run() {
    log "Testing hal9000 container execution..."

    if $QUICK; then
        skip "Container execution (--quick mode)"
        return 0
    fi

    # Run a simple command in hal9000 container
    if docker run --rm ghcr.io/hellblazer/hal-9000:latest echo "hal9000 works" >/dev/null 2>&1; then
        pass "hal9000 container runs successfully"
    else
        fail "hal9000 container failed to run"
    fi
}

test_mcp_servers_in_container() {
    log "Testing MCP servers in container..."

    if $QUICK; then
        skip "Container MCP test (--quick mode)"
        return 0
    fi

    # Verify MCP servers are available in container
    local result=$(docker run --rm ghcr.io/hellblazer/hal-9000:latest \
        bash -c "which mcp-server-memory-bank && which chroma-mcp && echo OK" 2>&1)

    if echo "$result" | grep -q "OK"; then
        pass "MCP servers available in container"
    else
        fail "MCP servers missing in container"
        verbose "$result"
    fi
}

test_tmux_available() {
    log "Testing tmux availability..."

    if command -v tmux >/dev/null 2>&1; then
        pass "tmux installed"
        verbose "$(tmux -V)"
    else
        fail "tmux not installed"
    fi
}

# Main test runner
main() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  HAL-9000 Integration Tests${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    # Phase 1: Environment
    echo -e "${YELLOW}Phase 1: Environment${NC}"
    test_docker_available
    test_install_prerequisites
    test_tmux_available
    echo ""

    # Phase 2: Installation
    echo -e "${YELLOW}Phase 2: Installation${NC}"
    test_hal9000_install
    echo ""

    # Phase 3: Component Verification
    echo -e "${YELLOW}Phase 3: Component Verification${NC}"
    test_mcp_servers_installed
    test_safety_hooks_installed
    test_agents_installed
    test_commands_installed
    test_beads_installed
    echo ""

    # Phase 4: Container Tests
    echo -e "${YELLOW}Phase 4: Container Tests${NC}"
    test_hal9000_container_build
    test_hal9000_container_run
    test_mcp_servers_in_container
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
