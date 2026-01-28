#!/bin/bash
#
# volume-helpers.sh - Docker volume isolation utilities for hal-9000 testing
#
# Provides functions for creating, managing, and cleaning up test-specific
# Docker volumes to ensure test isolation and enable parallel test execution.
#
# VOLUME NAMING CONVENTION:
#   hal9000-test-{TEST_ID}-claude-home     # CLAUDE_HOME equivalent
#   hal9000-test-{TEST_ID}-claude-session  # Claude session state
#   hal9000-test-{TEST_ID}-memory-bank     # Memory bank for cross-session context
#
# USAGE:
#   source /scripts/tests/lib/volume-helpers.sh
#   TEST_ID="AUTH-001"
#   setup_test_volumes "$TEST_ID"
#   # Run test...
#   cleanup_test_volumes "$TEST_ID"

set -Eeuo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#==============================================================================
# Volume Naming Functions
#==============================================================================

# Get the full name of a test volume by type
# Usage: get_test_volume_name TEST_ID VOLUME_TYPE
# Returns: hal9000-test-{TEST_ID}-{VOLUME_TYPE}
get_test_volume_name() {
    local test_id="${1:?Missing TEST_ID}"
    local volume_type="${2:?Missing VOLUME_TYPE}"

    # Validate volume type
    case "$volume_type" in
        claude-home|claude-session|memory-bank)
            ;;
        *)
            echo "Invalid volume type: $volume_type" >&2
            echo "Valid types: claude-home, claude-session, memory-bank" >&2
            return 1
            ;;
    esac

    echo "hal9000-test-${test_id}-${volume_type}"
}

# Get all volume names for a test
# Usage: get_test_volumes TEST_ID
# Returns: Space-separated list of all three test volumes
get_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"

    echo "$(get_test_volume_name "$test_id" claude-home) $(get_test_volume_name "$test_id" claude-session) $(get_test_volume_name "$test_id" memory-bank)"
}

#==============================================================================
# Volume Lifecycle Functions
#==============================================================================

# Create test volumes for a specific test
# Sets up three isolated volumes:
#   - claude-home: CLAUDE_HOME equivalent for plugins, credentials
#   - claude-session: Session state (.claude.json) persistence
#   - memory-bank: Cross-session context
#
# Usage: setup_test_volumes TEST_ID
# Returns: 0 on success, 1 on failure
setup_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"

    if [[ -z "$test_id" ]]; then
        echo -e "${RED}✗ Error: TEST_ID cannot be empty${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}ℹ Setting up test volumes for: $test_id${NC}" >&2

    local volumes=(
        "claude-home"
        "claude-session"
        "memory-bank"
    )

    local failed=0
    for volume_type in "${volumes[@]}"; do
        local volume_name
        volume_name=$(get_test_volume_name "$test_id" "$volume_type")

        # Check if volume already exists
        if docker volume inspect "$volume_name" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Volume already exists: $volume_name${NC}" >&2
            # Skip - volume exists
            continue
        fi

        # Create the volume
        if docker volume create "$volume_name" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Created volume: $volume_name${NC}" >&2
        else
            echo -e "${RED}✗ Failed to create volume: $volume_name${NC}" >&2
            failed=1
        fi
    done

    if [[ $failed -eq 1 ]]; then
        return 1
    fi

    echo -e "${GREEN}✓ Test volumes ready for: $test_id${NC}" >&2
    return 0
}

# Remove test volumes for a specific test
# Cleans up all three test volumes after test completion
#
# Usage: cleanup_test_volumes TEST_ID [FORCE]
#   FORCE: If "true", use --force flag to remove even if in use (not recommended)
#
# Returns: 0 on success, 1 on partial/complete failure
cleanup_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"
    local force="${2:-false}"

    if [[ -z "$test_id" ]]; then
        echo -e "${RED}✗ Error: TEST_ID cannot be empty${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}ℹ Cleaning up test volumes for: $test_id${NC}" >&2

    local volumes=(
        "claude-home"
        "claude-session"
        "memory-bank"
    )

    local failed=0
    for volume_type in "${volumes[@]}"; do
        local volume_name
        volume_name=$(get_test_volume_name "$test_id" "$volume_type")

        # Check if volume exists
        if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Volume not found (already removed?): $volume_name${NC}" >&2
            continue
        fi

        # Remove the volume
        local rm_args=(docker volume rm)
        if [[ "$force" == "true" ]]; then
            rm_args+=(--force)
        fi
        rm_args+=("$volume_name")

        if "${rm_args[@]}" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Removed volume: $volume_name${NC}" >&2
        else
            echo -e "${RED}✗ Failed to remove volume: $volume_name${NC}" >&2
            failed=1
        fi
    done

    if [[ $failed -eq 1 ]]; then
        echo -e "${RED}✗ Cleanup completed with errors${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Test volumes cleaned up: $test_id${NC}" >&2
    return 0
}

# Force cleanup (for emergency/cleanup scenarios)
# Removes volumes even if they're in use
force_cleanup_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"
    cleanup_test_volumes "$test_id" "true"
}

#==============================================================================
# Volume Inspection Functions
#==============================================================================

# Check if test volumes exist
# Usage: test_volumes_exist TEST_ID
# Returns: 0 if all volumes exist, 1 otherwise
test_volumes_exist() {
    local test_id="${1:?Missing TEST_ID}"

    local volumes
    volumes=$(get_test_volumes "$test_id")

    for volume in $volumes; do
        if ! docker volume inspect "$volume" >/dev/null 2>&1; then
            return 1
        fi
    done

    return 0
}

# List all test volumes for a specific test
# Usage: list_test_volumes TEST_ID
# Returns: Formatted output of test volumes
list_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"

    echo -e "${BLUE}Test volumes for: $test_id${NC}"
    echo ""

    local volumes
    volumes=$(get_test_volumes "$test_id")

    for volume in $volumes; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            local size_info
            size_info=$(docker volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null || echo "unknown")
            echo -e "  ${GREEN}✓${NC} $volume"
            echo "    Mountpoint: $size_info"
        else
            echo -e "  ${RED}✗${NC} $volume (not found)"
        fi
    done

    echo ""
}

# List all test volumes (for all tests)
# Useful for debugging and cleanup verification
# Usage: list_all_test_volumes
# Returns: Formatted output of all test volumes
list_all_test_volumes() {
    echo -e "${BLUE}All test volumes:${NC}"
    echo ""

    # Find all test volumes
    local test_volumes
    test_volumes=$(docker volume ls --filter name="hal9000-test-" --format "{{.Name}}" 2>/dev/null || echo "")

    if [[ -z "$test_volumes" ]]; then
        echo -e "  ${YELLOW}No test volumes found${NC}"
        return 0
    fi

    echo "$test_volumes" | while read -r volume; do
        echo -e "  ${GREEN}✓${NC} $volume"
    done

    echo ""
}

# Get volume size/usage information
# Usage: get_test_volume_size TEST_ID VOLUME_TYPE
get_test_volume_size() {
    local test_id="${1:?Missing TEST_ID}"
    local volume_type="${2:?Missing VOLUME_TYPE}"

    local volume_name
    volume_name=$(get_test_volume_name "$test_id" "$volume_type")

    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        echo "0"
        return 1
    fi

    # Try to get size from mountpoint
    local mountpoint
    mountpoint=$(docker volume inspect "$volume_name" --format '{{.Mountpoint}}' 2>/dev/null || echo "")

    if [[ -n "$mountpoint" ]] && [[ -d "$mountpoint" ]]; then
        du -sh "$mountpoint" 2>/dev/null | awk '{print $1}' || echo "unknown"
    else
        echo "unknown"
    fi
}

#==============================================================================
# Docker Run Helper (Volume-aware)
#==============================================================================

# Run a Docker container with test volumes mounted
# Usage: run_with_test_volumes TEST_ID IMAGE_NAME [DOCKER_ARGS...]
#
# This is a convenience function for running containers with proper test volume mounts
run_with_test_volumes() {
    local test_id="${1:?Missing TEST_ID}"
    local image="${2:?Missing IMAGE_NAME}"
    shift 2

    # Get volume names
    local home_vol claude_session_vol membank_vol
    home_vol=$(get_test_volume_name "$test_id" "claude-home")
    claude_session_vol=$(get_test_volume_name "$test_id" "claude-session")
    membank_vol=$(get_test_volume_name "$test_id" "memory-bank")

    # Run container with test volumes
    docker run \
        -v "$home_vol:/root/.claude" \
        -v "$claude_session_vol:/root/.claude-session" \
        -v "$membank_vol:/root/memory-bank" \
        "$@" \
        "$image"
}

#==============================================================================
# Cleanup Utilities
#==============================================================================

# Remove all test volumes (DANGEROUS - use with caution!)
# Usage: cleanup_all_test_volumes [PATTERN]
# PATTERN: Optional regex pattern to filter volumes (default: "hal9000-test-*")
cleanup_all_test_volumes() {
    local pattern="${1:-hal9000-test-*}"

    echo -e "${RED}WARNING: Removing all test volumes matching: $pattern${NC}" >&2
    echo -e "${RED}This action cannot be undone!${NC}" >&2
    echo ""
    read -p "Type 'yes' to confirm: " -r confirm
    echo ""

    if [[ "$confirm" != "yes" ]]; then
        echo -e "${YELLOW}Cancelled${NC}" >&2
        return 0
    fi

    local test_volumes
    test_volumes=$(docker volume ls --filter name="$pattern" --format "{{.Name}}" 2>/dev/null || echo "")

    if [[ -z "$test_volumes" ]]; then
        echo -e "${YELLOW}No volumes matching pattern: $pattern${NC}" >&2
        return 0
    fi

    local count=0
    echo "$test_volumes" | while read -r volume; do
        if docker volume rm "$volume" 2>/dev/null; then
            echo -e "${GREEN}✓ Removed: $volume${NC}" >&2
            ((count++)) || true
        else
            echo -e "${RED}✗ Failed to remove: $volume${NC}" >&2
        fi
    done

    echo -e "${GREEN}Cleanup complete${NC}" >&2
}

#==============================================================================
# Validation Functions
#==============================================================================

# Validate that Docker is available and volumes can be created
# Usage: validate_volume_support
# Returns: 0 if Docker volumes are supported, 1 otherwise
validate_volume_support() {
    # Check Docker availability
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker not found${NC}" >&2
        return 1
    fi

    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        echo -e "${RED}✗ Docker daemon not running or not accessible${NC}" >&2
        return 1
    fi

    # Try to create and remove a test volume
    local test_vol="hal9000-test-validate-$$"
    if ! docker volume create "$test_vol" >/dev/null 2>&1; then
        echo -e "${RED}✗ Cannot create Docker volumes${NC}" >&2
        return 1
    fi

    if ! docker volume rm "$test_vol" >/dev/null 2>&1; then
        echo -e "${RED}✗ Cannot remove Docker volumes${NC}" >&2
        docker volume rm "$test_vol" 2>/dev/null || true
        return 1
    fi

    echo -e "${GREEN}✓ Docker volume support validated${NC}" >&2
    return 0
}

#==============================================================================
# Test Lifecycle Hooks
#==============================================================================

# Setup hook - call at beginning of test
# Sets up volumes and validates environment
# Usage: setup_test_environment TEST_ID
setup_test_environment() {
    local test_id="${1:?Missing TEST_ID}"

    echo -e "${BLUE}ℹ Preparing test environment: $test_id${NC}" >&2

    # Validate Docker support
    if ! validate_volume_support; then
        echo -e "${RED}✗ Docker volume support validation failed${NC}" >&2
        return 1
    fi

    # Setup volumes
    if ! setup_test_volumes "$test_id"; then
        echo -e "${RED}✗ Failed to setup test volumes${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Test environment ready${NC}" >&2
    return 0
}

# Teardown hook - call at end of test
# Cleans up volumes and reports status
# Usage: teardown_test_environment TEST_ID [TEST_RESULT]
# TEST_RESULT: Optional "pass" or "fail" (for logging purposes)
teardown_test_environment() {
    local test_id="${1:?Missing TEST_ID}"
    local test_result="${2:-unknown}"

    echo -e "${BLUE}ℹ Cleaning up test environment: $test_id (result: $test_result)${NC}" >&2

    # Cleanup volumes
    if ! cleanup_test_volumes "$test_id"; then
        echo -e "${RED}✗ Failed to cleanup test volumes${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Test environment cleaned up${NC}" >&2
    return 0
}

#==============================================================================
# Export functions (if sourced)
#==============================================================================

# These functions are now available to sourcing scripts
export -f get_test_volume_name
export -f get_test_volumes
export -f setup_test_volumes
export -f cleanup_test_volumes
export -f force_cleanup_test_volumes
export -f test_volumes_exist
export -f list_test_volumes
export -f list_all_test_volumes
export -f get_test_volume_size
export -f run_with_test_volumes
export -f cleanup_all_test_volumes
export -f validate_volume_support
export -f setup_test_environment
export -f teardown_test_environment
