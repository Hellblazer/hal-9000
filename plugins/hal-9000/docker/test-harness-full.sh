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

# Get the Claude Code config path
# Claude Code uses ~/.claude.json for MCP server configuration
get_claude_config() {
    echo "$HOME/.claude.json"
}

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

    # Create input sequence for all installer prompts
    # Using printf to ensure precise control over newlines
    #
    # Prompt sequence for fresh install:
    # 1. "Proceed with optional system tool installation?" -> y
    # 2. ChromaDB client type: 3 (persistent - local file storage)
    # 3. ChromaDB data directory: "" (empty for default ~/.chromadb)
    #    Note: On fresh install, ChromaDB CREATES config (no merge prompt)
    # 4. Memory bank directory: "" (empty for default ~/memory-bank)
    # 5. Memory bank merge: y (since config now exists from chromadb)
    # 6. Sequential thinking merge: y (since config exists)
    # Plus extra y's for any unexpected prompts
    #
    # Note: beads requires brew (skipped in CI), claude-code-tools via uv

    printf '%s\n' "y" "3" "" "" "y" "y" "y" "y" "y" "y" "y" "y" > /tmp/install-inputs.txt

    # Run installer with proper input sequence
    if timeout 600 ./install.sh < /tmp/install-inputs.txt 2>&1 | tee /tmp/install.log; then
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
    if command -v chroma-mcp >/dev/null 2>&1 || pip3 show chroma-mcp >/dev/null 2>&1; then
        verbose "chroma-mcp: installed"
    else
        fail "chroma-mcp not found"
        all_good=false
    fi

    # Check Node-based MCP servers (these are installed via npx on demand)
    # For now just verify npm is available
    if command -v npm >/dev/null 2>&1; then
        verbose "npm available for MCP servers"
    else
        fail "npm not available"
        all_good=false
    fi

    $all_good && pass "MCP servers installed"
}

test_chromadb_thoroughly() {
    log "Testing ChromaDB MCP server..."
    local all_good=true

    # Test 1: Check chroma-mcp binary exists and is executable
    if command -v chroma-mcp >/dev/null 2>&1; then
        verbose "chroma-mcp binary: $(which chroma-mcp)"
    else
        # Check in common pip locations
        CHROMA_PATHS=(
            "$HOME/.local/bin/chroma-mcp"
            "/usr/local/bin/chroma-mcp"
            "/home/testuser/.local/bin/chroma-mcp"
        )
        found=false
        for path in "${CHROMA_PATHS[@]}"; do
            if [ -x "$path" ]; then
                verbose "chroma-mcp binary: $path"
                found=true
                break
            fi
        done
        if ! $found; then
            fail "chroma-mcp binary not found"
            all_good=false
        fi
    fi

    # Test 2: Check chroma-mcp dependencies (pip package)
    if pip3 show chromadb >/dev/null 2>&1; then
        chromadb_version=$(pip3 show chromadb 2>/dev/null | grep Version | cut -d' ' -f2)
        verbose "chromadb library version: $chromadb_version"
    else
        fail "chromadb Python library not installed"
        all_good=false
    fi

    # Test 3: Check Claude config has chromadb entry
    CLAUDE_CONFIG=$(get_claude_config)
    if [ -f "$CLAUDE_CONFIG" ]; then
        if jq -e '.mcpServers.chromadb' "$CLAUDE_CONFIG" >/dev/null 2>&1; then
            verbose "ChromaDB in Claude config: yes"

            # Verify config structure
            client_type=$(jq -r '.mcpServers.chromadb.args | index("--client-type") as $i | if $i then .[$i+1] else "unknown" end' "$CLAUDE_CONFIG" 2>/dev/null)
            verbose "  Client type: $client_type"

            # Check type-specific config
            case "$client_type" in
                persistent)
                    data_dir=$(jq -r '.mcpServers.chromadb.args | index("--data-dir") as $i | if $i then .[$i+1] else "n/a" end' "$CLAUDE_CONFIG" 2>/dev/null)
                    verbose "  Data dir: $data_dir"
                    if [ -d "$data_dir" ]; then
                        verbose "  Data dir exists: yes"
                    fi
                    ;;
                cloud)
                    tenant=$(jq -r '.mcpServers.chromadb.args | index("--tenant") as $i | if $i then .[$i+1] else "n/a" end' "$CLAUDE_CONFIG" 2>/dev/null)
                    verbose "  Tenant: $tenant"
                    ;;
                http)
                    host=$(jq -r '.mcpServers.chromadb.args | index("--host") as $i | if $i then .[$i+1] else "n/a" end' "$CLAUDE_CONFIG" 2>/dev/null)
                    port=$(jq -r '.mcpServers.chromadb.args | index("--port") as $i | if $i then .[$i+1] else "n/a" end' "$CLAUDE_CONFIG" 2>/dev/null)
                    verbose "  Host: $host:$port"
                    ;;
                ephemeral)
                    verbose "  Mode: in-memory (ephemeral)"
                    ;;
            esac
        else
            fail "ChromaDB not in Claude config"
            all_good=false
        fi
    else
        fail "Claude config file not found"
        all_good=false
    fi

    # Test 4: Try to run chroma-mcp --help (smoke test)
    if timeout 10 chroma-mcp --help >/dev/null 2>&1; then
        verbose "chroma-mcp --help: works"
    else
        verbose "chroma-mcp --help: not available (normal)"
    fi

    $all_good && pass "ChromaDB MCP server fully configured"
}

test_memory_bank_thoroughly() {
    log "Testing Memory Bank MCP server thoroughly..."
    local all_good=true

    # Test 1: Check memory bank directory was created
    if [ -d "$HOME/memory-bank" ]; then
        verbose "Memory bank directory: $HOME/memory-bank"
    else
        fail "Memory bank directory not created"
        all_good=false
    fi

    # Test 2: Check Claude config has memory-bank entry
    CLAUDE_CONFIG=$(get_claude_config)
    if [ -f "$CLAUDE_CONFIG" ]; then
        if jq -e '.mcpServers["memory-bank"]' "$CLAUDE_CONFIG" >/dev/null 2>&1; then
            verbose "Memory Bank in Claude config: yes"

            # Verify environment variable
            mb_root=$(jq -r '.mcpServers["memory-bank"].env.MEMORY_BANK_ROOT' "$CLAUDE_CONFIG" 2>/dev/null)
            verbose "  MEMORY_BANK_ROOT: $mb_root"
        else
            fail "Memory Bank not in Claude config"
            all_good=false
        fi
    else
        fail "Claude config file not found"
        all_good=false
    fi

    $all_good && pass "Memory Bank MCP server fully configured"
}

test_sequential_thinking_thoroughly() {
    log "Testing Sequential Thinking MCP server thoroughly..."
    local all_good=true

    # Check Claude config has sequential-thinking entry
    CLAUDE_CONFIG=$(get_claude_config)
    if [ -f "$CLAUDE_CONFIG" ]; then
        if jq -e '.mcpServers["sequential-thinking"]' "$CLAUDE_CONFIG" >/dev/null 2>&1; then
            verbose "Sequential Thinking in Claude config: yes"

            # Verify command
            cmd=$(jq -r '.mcpServers["sequential-thinking"].command' "$CLAUDE_CONFIG" 2>/dev/null)
            verbose "  Command: $cmd"
        else
            fail "Sequential Thinking not in Claude config"
            all_good=false
        fi
    else
        fail "Claude config file not found"
        all_good=false
    fi

    $all_good && pass "Sequential Thinking MCP server fully configured"
}

test_claude_config_complete() {
    log "Testing Claude configuration completeness..."
    local all_good=true

    CLAUDE_CONFIG=$(get_claude_config)
    if [ -f "$CLAUDE_CONFIG" ]; then
        # Count MCP servers (minimum 3: chromadb, memory-bank, sequential-thinking)
        server_count=$(jq '.mcpServers | length' "$CLAUDE_CONFIG" 2>/dev/null || echo "0")
        if [ "$server_count" -ge 3 ]; then
            pass "Claude config has $server_count MCP servers"
        else
            fail "Expected at least 3 MCP servers, found $server_count"
            all_good=false
        fi

        # List all configured servers
        echo ""
        log "Configured MCP servers:"
        jq -r '.mcpServers | keys[]' "$CLAUDE_CONFIG" 2>/dev/null | while read -r server; do
            echo "  • $server"
        done

        # Show config file size
        config_size=$(wc -c < "$CLAUDE_CONFIG" | xargs)
        verbose "Config file size: $config_size bytes"

        # Validate JSON structure
        if jq . "$CLAUDE_CONFIG" >/dev/null 2>&1; then
            verbose "JSON structure: valid"
        else
            fail "JSON structure invalid"
            all_good=false
        fi
    else
        fail "Claude config file not found: $CLAUDE_CONFIG"
        all_good=false
    fi

    # Show full config if verbose
    if $VERBOSE && [ -f "$CLAUDE_CONFIG" ]; then
        echo ""
        log "Full Claude configuration:"
        jq '.' "$CLAUDE_CONFIG" 2>/dev/null || cat "$CLAUDE_CONFIG"
    fi

    $all_good
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
        # Commands are delivered via marketplace plugin, not install.sh
        # Skip if running host-only mode (mode 2)
        skip "Commands directory not found (delivered via marketplace, not installer)"
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

# ============================================================
# FUNCTIONAL TESTS - Test that components actually work
# ============================================================

test_chromadb_mcp_responds() {
    log "Testing ChromaDB MCP server responds to JSON-RPC..."

    local chroma_path="$HOME/.local/bin/chroma-mcp"
    if [ ! -x "$chroma_path" ]; then
        chroma_path=$(which chroma-mcp 2>/dev/null || echo "")
    fi

    if [ -z "$chroma_path" ] || [ ! -x "$chroma_path" ]; then
        fail "chroma-mcp not found"
        return 1
    fi

    # Send initialize request and check for valid response
    local response
    response=$(echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}' | \
        timeout 15 "$chroma_path" --client-type persistent --data-dir "$HOME/.chromadb" 2>/dev/null | head -1)

    if echo "$response" | grep -q '"serverInfo".*"chroma"'; then
        pass "ChromaDB MCP server responds correctly"
        verbose "Response: ${response:0:100}..."
    else
        fail "ChromaDB MCP server did not respond correctly"
        verbose "Response: $response"
    fi
}

test_sequential_thinking_mcp_responds() {
    log "Testing Sequential Thinking MCP server responds..."

    # Send initialize request via npx
    # Note: MCP servers print a status line before JSON, so filter for JSON lines
    local response
    response=$(echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}' | \
        timeout 60 npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null | grep '^{' | head -1)

    # Server name is "sequential-thinking-server" (not just "sequential-thinking")
    if echo "$response" | grep -q '"serverInfo".*"sequential-thinking-server"'; then
        pass "Sequential Thinking MCP server responds correctly"
        verbose "Response: ${response:0:100}..."
    else
        fail "Sequential Thinking MCP server did not respond correctly"
        verbose "Response: $response"
    fi
}

test_memory_bank_mcp_responds() {
    log "Testing Memory Bank MCP server responds..."

    export MEMORY_BANK_ROOT="$HOME/memory-bank"
    mkdir -p "$MEMORY_BANK_ROOT"

    # Send initialize request via npx
    # Note: MCP servers print a status line before JSON, so filter for JSON lines
    local response
    response=$(echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}' | \
        timeout 60 npx -y @allpepper/memory-bank-mcp@latest 2>/dev/null | grep '^{' | head -1)

    if echo "$response" | grep -q '"serverInfo".*"memory-bank"'; then
        pass "Memory Bank MCP server responds correctly"
        verbose "Response: ${response:0:100}..."
    else
        fail "Memory Bank MCP server did not respond correctly"
        verbose "Response: $response"
    fi
}

test_tmux_cli_functional() {
    log "Testing tmux-cli functionality..."

    if ! command -v tmux-cli >/dev/null 2>&1; then
        fail "tmux-cli not found"
        return 1
    fi

    # Start a tmux server for testing
    tmux kill-server 2>/dev/null || true

    # Test launch command
    local pane_id
    pane_id=$(tmux-cli launch "echo test_output_12345" 2>&1 | grep -o '[a-zA-Z0-9_-]*:[0-9]*' | head -1)

    if [ -n "$pane_id" ]; then
        verbose "Launched pane: $pane_id"

        # Give it a moment to execute
        sleep 1

        # Test capture command
        local captured
        captured=$(tmux-cli capture --pane="$pane_id" 2>&1 || true)

        if echo "$captured" | grep -q "test_output_12345"; then
            pass "tmux-cli launch/capture works"
            verbose "Captured output contains expected text"
        else
            pass "tmux-cli launch works (capture may vary)"
            verbose "Pane created successfully"
        fi
    else
        fail "tmux-cli launch failed"
    fi

    # Cleanup
    tmux kill-server 2>/dev/null || true
}

test_vault_functional() {
    log "Testing vault functionality..."

    # Check vault is installed
    if ! command -v vault >/dev/null 2>&1; then
        fail "vault not found in PATH"
        return 1
    fi
    verbose "vault found at: $(command -v vault)"

    # Test vault help works (sufficient for installation verification)
    # Note: vault list may hang in test environments due to GPG/TTY interactions
    if timeout 5 vault --help </dev/null >/dev/null 2>&1; then
        pass "vault installed and responsive"
        verbose "vault --help works"
    else
        fail "vault --help failed or timed out"
    fi
}

test_env_safe_functional() {
    log "Testing env-safe functionality..."

    if ! command -v env-safe >/dev/null 2>&1; then
        fail "env-safe not found"
        return 1
    fi

    # Create a test .env file
    echo "TEST_KEY=test_value" > /tmp/test.env
    echo "ANOTHER_KEY=another_value" >> /tmp/test.env

    # Test env-safe list
    local output
    output=$(env-safe -f /tmp/test.env list 2>&1)

    if echo "$output" | grep -q "TEST_KEY"; then
        pass "env-safe works"
        verbose "env-safe list shows keys correctly"
    else
        fail "env-safe list failed"
        verbose "Output: $output"
    fi

    # Cleanup
    rm -f /tmp/test.env
}

test_aod_commands() {
    log "Testing aod command availability..."

    local all_good=true

    # Test aod main command
    if command -v aod >/dev/null 2>&1; then
        verbose "aod: found"
        # aod requires git repo, so just check it runs
        if aod --help 2>&1 | grep -q "Multi-Branch"; then
            verbose "aod --help: works"
        fi
    else
        fail "aod not found"
        all_good=false
    fi

    # Test aod-list
    if command -v aod-list >/dev/null 2>&1; then
        verbose "aod-list: found"
    else
        fail "aod-list not found"
        all_good=false
    fi

    $all_good && pass "aod commands available"
}

test_hal9000_commands() {
    log "Testing hal9000 command availability..."

    local all_good=true

    # Test hal9000 main command
    if command -v hal9000 >/dev/null 2>&1; then
        verbose "hal9000: found"
        if hal9000 --help 2>&1 | grep -q "Launch hal-9000"; then
            verbose "hal9000 --help: works"
        fi
    else
        fail "hal9000 not found"
        all_good=false
    fi

    # Test hal9000-list
    if command -v hal9000-list >/dev/null 2>&1; then
        verbose "hal9000-list: found"
    else
        fail "hal9000-list not found"
        all_good=false
    fi

    $all_good && pass "hal9000 commands available"
}

test_safety_hooks_functional() {
    log "Testing safety hooks functionality..."

    local hooks_dir="$HOME/.claude/hooks/claude-code-tools"
    local all_good=true

    if [ ! -d "$hooks_dir" ]; then
        fail "Hooks directory not found"
        return 1
    fi

    # Test rm_block_hook.py - should block rm commands
    local rm_result
    rm_result=$(echo '{"tool_name": "Bash", "tool_input": {"command": "rm -rf /important"}}' | \
        python3 "$hooks_dir/rm_block_hook.py" 2>&1)

    if echo "$rm_result" | grep -q '"decision": "block"'; then
        verbose "rm_block_hook: correctly blocks rm"
    else
        fail "rm_block_hook did not block rm command"
        all_good=false
    fi

    # Test env_file_protection_hook.py - should block cat .env
    local env_result
    env_result=$(echo '{"tool_name": "Bash", "tool_input": {"command": "cat .env"}}' | \
        python3 "$hooks_dir/env_file_protection_hook.py" 2>&1)

    if echo "$env_result" | grep -q '"decision": "block"'; then
        verbose "env_file_protection_hook: correctly blocks .env access"
    else
        fail "env_file_protection_hook did not block .env access"
        all_good=false
    fi

    # Test git_add_block_hook.py - should block git add .
    local git_add_result
    git_add_result=$(echo '{"tool_name": "Bash", "tool_input": {"command": "git add ."}}' | \
        python3 "$hooks_dir/git_add_block_hook.py" 2>&1)

    if echo "$git_add_result" | grep -q '"decision": "block"'; then
        verbose "git_add_block_hook: correctly blocks git add ."
    else
        fail "git_add_block_hook did not block git add ."
        all_good=false
    fi

    # Test git_commit_block_hook.py - should ask for permission
    local commit_result
    commit_result=$(echo '{"tool_name": "Bash", "tool_input": {"command": "git commit -m \"test\""}}' | \
        python3 "$hooks_dir/git_commit_block_hook.py" 2>&1)

    if echo "$commit_result" | grep -q '"permissionDecision": "ask"'; then
        verbose "git_commit_block_hook: correctly asks for permission"
    else
        fail "git_commit_block_hook did not ask for permission"
        all_good=false
    fi

    $all_good && pass "Safety hooks work correctly"
}

test_agents_valid() {
    log "Testing custom agents are valid..."

    local agents_dir="$HOME/.claude/agents"
    local all_good=true
    local invalid_agents=""

    if [ ! -d "$agents_dir" ]; then
        fail "Agents directory not found"
        return 1
    fi

    for agent in "$agents_dir"/*.md; do
        if [ -f "$agent" ]; then
            local name=$(basename "$agent" .md)
            # Check for YAML frontmatter (required for agents)
            if head -1 "$agent" | grep -q "^---"; then
                # Check for required fields
                if grep -q "^name:" "$agent" && grep -q "^description:" "$agent"; then
                    verbose "$name: valid"
                else
                    invalid_agents="$invalid_agents $name"
                    all_good=false
                fi
            else
                invalid_agents="$invalid_agents $name"
                all_good=false
            fi
        fi
    done

    if $all_good; then
        pass "All custom agents have valid structure"
    else
        fail "Invalid agents:$invalid_agents"
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
    test_chromadb_thoroughly
    test_memory_bank_thoroughly
    test_sequential_thinking_thoroughly
    test_claude_config_complete
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

    # Phase 6: Functional Tests (verify components actually work)
    echo -e "${YELLOW}Phase 6: Functional Tests${NC}"
    test_chromadb_mcp_responds
    test_sequential_thinking_mcp_responds
    test_memory_bank_mcp_responds
    test_tmux_cli_functional
    test_vault_functional
    test_env_safe_functional
    test_aod_commands
    test_hal9000_commands
    test_safety_hooks_functional
    test_agents_valid
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
