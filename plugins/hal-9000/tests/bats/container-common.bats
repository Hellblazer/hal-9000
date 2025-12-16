#!/usr/bin/env bats
# Tests for container-common.sh shared library
#
# Run with: bats plugins/hal-9000/tests/bats/

# Setup - source the library being tested
setup() {
    # Get the absolute path to the lib directory
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../../lib" && pwd)"

    # Source the library
    source "$LIB_DIR/container-common.sh"

    # Create temporary directory for tests
    TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    # Cleanup temporary directory
    rm -rf "$TEST_TMP_DIR"
}

# =============================================================================
# Color definitions tests
# =============================================================================

@test "color constants are defined" {
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$BLUE" ]
    [ -n "$CYAN" ]
    [ -n "$NC" ]
}

# =============================================================================
# Logging function tests
# =============================================================================

@test "info function outputs to stderr" {
    run info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "success function outputs to stderr" {
    run success "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "warn function outputs to stderr" {
    run warn "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "error function outputs to stderr" {
    run error "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "die function exits with code 1" {
    run die "fatal error"
    [ "$status" -eq 1 ]
    [[ "$output" == *"fatal error"* ]]
}

# =============================================================================
# Lock function tests
# =============================================================================

@test "acquire_lock creates lock directory" {
    local lockfile="$TEST_TMP_DIR/test.lock"

    acquire_lock "$lockfile"

    [ -d "$lockfile" ]

    # Cleanup
    release_lock "$lockfile"
}

@test "release_lock removes lock directory" {
    local lockfile="$TEST_TMP_DIR/test.lock"

    acquire_lock "$lockfile"
    [ -d "$lockfile" ]

    release_lock "$lockfile"
    [ ! -d "$lockfile" ]
}

@test "acquire_lock blocks when lock exists" {
    local lockfile="$TEST_TMP_DIR/test.lock"

    # Create lock manually
    mkdir "$lockfile"

    # Try to acquire with 1 second timeout - should fail
    run timeout 2 bash -c "source '$LIB_DIR/container-common.sh' && acquire_lock '$lockfile' 1"
    [ "$status" -ne 0 ]

    # Cleanup
    rmdir "$lockfile"
}

# =============================================================================
# Slot management tests
# =============================================================================

@test "get_next_container_slot returns 1 when no containers running" {
    # This test assumes docker is available but no matching containers
    # Skip if docker not available
    if ! command -v docker >/dev/null 2>&1; then
        skip "docker not available"
    fi

    run get_next_container_slot "test-nonexistent-prefix-xyz"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

# =============================================================================
# MCP configuration tests
# =============================================================================

@test "inject_mcp_config creates settings.json if not exists" {
    local settings_file="$TEST_TMP_DIR/settings.json"

    # File should not exist
    [ ! -f "$settings_file" ]

    inject_mcp_config "$settings_file"

    # File should now exist and contain mcpServers
    [ -f "$settings_file" ]

    if command -v jq >/dev/null 2>&1; then
        run jq -e '.mcpServers' "$settings_file"
        [ "$status" -eq 0 ]
    fi
}

@test "inject_mcp_config adds memory-bank server" {
    local settings_file="$TEST_TMP_DIR/settings.json"
    echo '{}' > "$settings_file"

    inject_mcp_config "$settings_file"

    if command -v jq >/dev/null 2>&1; then
        run jq -e '.mcpServers["memory-bank"]' "$settings_file"
        [ "$status" -eq 0 ]
    fi
}

@test "inject_mcp_config adds sequential-thinking server" {
    local settings_file="$TEST_TMP_DIR/settings.json"
    echo '{}' > "$settings_file"

    inject_mcp_config "$settings_file"

    if command -v jq >/dev/null 2>&1; then
        run jq -e '.mcpServers["sequential-thinking"]' "$settings_file"
        [ "$status" -eq 0 ]
    fi
}

@test "inject_mcp_config adds chromadb server" {
    local settings_file="$TEST_TMP_DIR/settings.json"
    echo '{}' > "$settings_file"

    inject_mcp_config "$settings_file"

    if command -v jq >/dev/null 2>&1; then
        run jq -e '.mcpServers["chromadb"]' "$settings_file"
        [ "$status" -eq 0 ]
    fi
}

@test "inject_mcp_config preserves existing mcpServers" {
    local settings_file="$TEST_TMP_DIR/settings.json"
    echo '{"mcpServers": {"existing-server": {"command": "test"}}}' > "$settings_file"

    inject_mcp_config "$settings_file"

    if command -v jq >/dev/null 2>&1; then
        run jq -e '.mcpServers["existing-server"]' "$settings_file"
        [ "$status" -eq 0 ]
    fi
}

# =============================================================================
# Prerequisite check tests
# =============================================================================

@test "check_container_prerequisites passes for common tools" {
    # Most systems have bash and ls
    run check_container_prerequisites "bash"
    [ "$status" -eq 0 ]
}

@test "check_container_prerequisites fails for missing tools" {
    run check_container_prerequisites "nonexistent-tool-xyz123"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Multiple sourcing protection
# =============================================================================

@test "library can be sourced multiple times without error" {
    source "$LIB_DIR/container-common.sh"
    source "$LIB_DIR/container-common.sh"

    # Should still have functions available
    [ "$(type -t info)" = "function" ]
}
