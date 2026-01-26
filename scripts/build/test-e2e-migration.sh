#!/usr/bin/env bash
# test-e2e-migration.sh - End-to-end migration testing
#
# Tests the full migration lifecycle:
# 1. Fresh install path (no existing data)
# 2. Upgrade from v0.5.0 (migrate existing data)
# 3. Data preservation (verify data survives migration)
# 4. Rollback functionality (verify rollback works)
#
# This test creates isolated environments to avoid affecting real data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATE="$REPO_ROOT/scripts/migrate-to-dind.sh"
ROLLBACK="$REPO_ROOT/scripts/rollback-dind.sh"
CLAUDY="$REPO_ROOT/claudy"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED=0
FAILED=0

log_test() { printf "${CYAN}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; PASSED=$((PASSED + 1)); }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAILED=$((FAILED + 1)); }
log_info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1"; }

# Test environment
TEST_HAL9000_HOME=""
TEST_VOLUMES_PREFIX="hal9000-test-e2e"

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    log_info "Cleaning up E2E test resources..."

    # Remove test volumes
    for vol in "${TEST_VOLUMES_PREFIX}-chromadb" "${TEST_VOLUMES_PREFIX}-memorybank" "${TEST_VOLUMES_PREFIX}-plugins"; do
        docker volume rm "$vol" 2>/dev/null || true
    done

    # Stop any test containers
    docker stop hal9000-parent 2>/dev/null || true
    docker rm hal9000-parent 2>/dev/null || true

    # Remove temp directory
    [[ -n "$TEST_HAL9000_HOME" ]] && rm -rf "$TEST_HAL9000_HOME" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_test "Checking E2E test prerequisites..."

    # Check scripts exist
    if [[ ! -x "$MIGRATE" ]]; then
        log_fail "migrate-to-dind.sh not found: $MIGRATE"
        exit 1
    fi

    if [[ ! -x "$ROLLBACK" ]]; then
        log_fail "rollback-dind.sh not found: $ROLLBACK"
        exit 1
    fi

    if [[ ! -x "$CLAUDY" ]]; then
        log_fail "claudy not found: $CLAUDY"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &>/dev/null; then
        log_fail "Docker not installed"
        exit 1
    fi

    if ! docker ps &>/dev/null; then
        log_fail "Docker daemon not running"
        exit 1
    fi

    # Check for parent image
    if ! docker image inspect "ghcr.io/hellblazer/hal-9000:parent" &>/dev/null; then
        log_info "Parent image not found, checking if we can build..."
        # Don't fail - test may handle this
    fi

    log_pass "E2E prerequisites OK"
}

# ============================================================================
# FRESH INSTALL PATH
# ============================================================================

test_fresh_install_migration() {
    log_test "E2E: Fresh install migration path"

    # Create fresh test environment
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    log_info "  Test environment: $TEST_HAL9000_HOME"

    # Run migration on fresh install (should work with no data)
    local output
    output=$("$MIGRATE" --dry-run --force 2>&1) || true

    # Should detect no existing data
    if echo "$output" | grep -q "not found (fresh)"; then
        log_pass "Fresh install detected correctly"
    else
        log_fail "Fresh install not detected"
        echo "Output: ${output:0:500}..."
        return 1
    fi

    # Verify dry-run didn't create anything
    if [[ ! -d "$TEST_HAL9000_HOME/backups" ]]; then
        log_pass "Dry run didn't create backup dir"
    else
        log_fail "Dry run created backup dir unexpectedly"
    fi
}

# ============================================================================
# UPGRADE FROM v0.5.0
# ============================================================================

test_upgrade_from_v050() {
    log_test "E2E: Upgrade from v0.5.0 with existing data"

    # Create test environment with mock v0.5.0 data
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    # Simulate v0.5.0 data structure
    mkdir -p "$TEST_HAL9000_HOME/chromadb"
    mkdir -p "$TEST_HAL9000_HOME/membank"
    mkdir -p "$TEST_HAL9000_HOME/plugins"
    mkdir -p "$TEST_HAL9000_HOME/claude/test-session"

    # Add identifiable test data
    echo "chromadb-test-data-$(date +%s)" > "$TEST_HAL9000_HOME/chromadb/test.db"
    echo "membank-test-data-$(date +%s)" > "$TEST_HAL9000_HOME/membank/test.md"
    local test_marker
    test_marker="e2e-test-marker-$(date +%s)"
    echo "$test_marker" > "$TEST_HAL9000_HOME/plugins/marker.txt"

    log_info "  Created mock v0.5.0 data with marker: $test_marker"

    # Run migration with dry-run first
    local output
    output=$("$MIGRATE" --dry-run --force 2>&1) || true

    # Should detect existing data
    if echo "$output" | grep -q "ChromaDB:.*$TEST_HAL9000_HOME/chromadb"; then
        log_pass "Existing ChromaDB data detected"
    else
        log_fail "ChromaDB data not detected"
    fi

    if echo "$output" | grep -q "Memory Bank:.*$TEST_HAL9000_HOME/membank"; then
        log_pass "Existing Memory Bank data detected"
    else
        log_fail "Memory Bank data not detected"
    fi
}

# ============================================================================
# DATA PRESERVATION
# ============================================================================

test_data_preservation() {
    log_test "E2E: Data preservation through migration cycle"

    # Create test environment
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    # Create identifiable data
    mkdir -p "$TEST_HAL9000_HOME/chromadb"
    local original_data="original-data-$(date +%s)-$$"
    echo "$original_data" > "$TEST_HAL9000_HOME/chromadb/preserved.txt"

    log_info "  Original data marker: $original_data"

    # Run migration (dry-run with force, then check backup would be created)
    local output
    output=$("$MIGRATE" --dry-run --force 2>&1) || true

    # Verify backup step mentioned
    if echo "$output" | grep -q "Creating backup"; then
        log_pass "Backup creation planned"
    else
        log_fail "No backup step mentioned"
    fi

    # Verify migration step mentioned
    if echo "$output" | grep -q "Migrating data"; then
        log_pass "Data migration planned"
    else
        log_fail "No migration step mentioned"
    fi

    # Original data should still exist (dry-run)
    if [[ -f "$TEST_HAL9000_HOME/chromadb/preserved.txt" ]]; then
        local preserved
        preserved=$(cat "$TEST_HAL9000_HOME/chromadb/preserved.txt")
        if [[ "$preserved" == "$original_data" ]]; then
            log_pass "Original data preserved during dry-run"
        else
            log_fail "Data was modified during dry-run"
        fi
    else
        log_fail "Original file missing after dry-run"
    fi
}

# ============================================================================
# ROLLBACK FUNCTIONALITY
# ============================================================================

test_rollback_functionality() {
    log_test "E2E: Rollback functionality"

    # Create test environment with backup
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    # Create a mock backup (as if migration was run)
    local backup_dir="$TEST_HAL9000_HOME/backups/pre-dind-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir/chromadb"
    mkdir -p "$backup_dir/membank"

    local rollback_marker="rollback-test-$(date +%s)-$$"
    echo "$rollback_marker" > "$backup_dir/chromadb/rollback-test.txt"

    # Create manifest
    cat > "$backup_dir/manifest.json" <<EOF
{
    "created_at": "$(date -Iseconds)",
    "hal9000_home": "$TEST_HAL9000_HOME",
    "source_version": "v0.5.x",
    "target_version": "v0.6.x"
}
EOF

    log_info "  Backup marker: $rollback_marker"

    # Run rollback
    local output
    output=$("$ROLLBACK" --force --keep-volumes 2>&1) || true

    # Check rollback completed
    if echo "$output" | grep -q "Rollback Complete"; then
        log_pass "Rollback completed"
    else
        log_fail "Rollback did not complete"
        echo "Output: ${output:0:500}..."
    fi

    # Check data was restored
    if [[ -f "$TEST_HAL9000_HOME/chromadb/rollback-test.txt" ]]; then
        local restored
        restored=$(cat "$TEST_HAL9000_HOME/chromadb/rollback-test.txt")
        if [[ "$restored" == "$rollback_marker" ]]; then
            log_pass "Rollback restored data correctly"
        else
            log_fail "Restored data doesn't match"
        fi
    else
        log_fail "Rollback didn't restore data file"
    fi
}

# ============================================================================
# FULL CYCLE TEST
# ============================================================================

test_full_migration_cycle() {
    log_test "E2E: Full migration cycle (migrate -> use -> rollback)"

    # Create test environment
    TEST_HAL9000_HOME=$(mktemp -d)
    export HAL9000_HOME="$TEST_HAL9000_HOME"

    # Create v0.5.0 style data
    mkdir -p "$TEST_HAL9000_HOME/chromadb"
    mkdir -p "$TEST_HAL9000_HOME/membank"
    local cycle_marker="cycle-test-$(date +%s)-$$"
    echo "$cycle_marker" > "$TEST_HAL9000_HOME/chromadb/cycle.txt"

    log_info "  Step 1: Created v0.5.0 data with marker: $cycle_marker"

    # Step 1: Verify data exists before migration
    if [[ -f "$TEST_HAL9000_HOME/chromadb/cycle.txt" ]]; then
        log_pass "Step 1: v0.5.0 data exists"
    else
        log_fail "Step 1: v0.5.0 data missing"
        return 1
    fi

    # Step 2: Run migration (dry-run)
    log_info "  Step 2: Running migration (dry-run)"
    local output
    output=$("$MIGRATE" --dry-run --force 2>&1) || true

    if echo "$output" | grep -q "Migration Complete"; then
        log_pass "Step 2: Migration plan completed"
    else
        log_fail "Step 2: Migration plan failed"
    fi

    # Step 3: Verify original data still exists
    if [[ -f "$TEST_HAL9000_HOME/chromadb/cycle.txt" ]]; then
        local check
        check=$(cat "$TEST_HAL9000_HOME/chromadb/cycle.txt")
        if [[ "$check" == "$cycle_marker" ]]; then
            log_pass "Step 3: Data preserved after dry-run"
        else
            log_fail "Step 3: Data was modified"
        fi
    else
        log_fail "Step 3: Data file missing"
    fi

    # Step 4: Create backup structure manually (simulate real migration backup)
    local backup_dir="$TEST_HAL9000_HOME/backups/pre-dind-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir/chromadb"
    cp "$TEST_HAL9000_HOME/chromadb/cycle.txt" "$backup_dir/chromadb/"
    cat > "$backup_dir/manifest.json" <<EOF
{"created_at": "$(date -Iseconds)"}
EOF

    log_info "  Step 4: Created backup at $backup_dir"

    # Step 5: Simulate post-migration (remove local data)
    rm -rf "$TEST_HAL9000_HOME/chromadb"

    if [[ ! -d "$TEST_HAL9000_HOME/chromadb" ]]; then
        log_pass "Step 5: Simulated post-migration state"
    fi

    # Step 6: Run rollback
    log_info "  Step 6: Running rollback"
    output=$("$ROLLBACK" --force --keep-volumes 2>&1) || true

    if echo "$output" | grep -q "Rollback Complete"; then
        log_pass "Step 6: Rollback completed"
    else
        log_fail "Step 6: Rollback failed"
    fi

    # Step 7: Verify data restored
    if [[ -f "$TEST_HAL9000_HOME/chromadb/cycle.txt" ]]; then
        local restored
        restored=$(cat "$TEST_HAL9000_HOME/chromadb/cycle.txt")
        if [[ "$restored" == "$cycle_marker" ]]; then
            log_pass "Step 7: Full cycle complete - data restored"
        else
            log_fail "Step 7: Restored data doesn't match original"
        fi
    else
        log_fail "Step 7: Data not restored after rollback"
    fi
}

# ============================================================================
# LEGACY MODE COMPATIBILITY
# ============================================================================

test_legacy_mode_works() {
    log_test "E2E: Legacy mode works after migration tools installed"

    # Test that --legacy flag is recognized
    local output
    output=$("$CLAUDY" --legacy --help 2>&1) || output=$("$CLAUDY" --help 2>&1) || true

    if echo "$output" | grep -q "\-\-legacy"; then
        log_pass "Legacy flag documented in help"
    else
        log_fail "Legacy flag not in help"
    fi

    # Test legacy mode triggers deprecation warning
    output=$("$CLAUDY" --legacy /nonexistent 2>&1) || true
    if echo "$output" | grep -qi "deprecat"; then
        log_pass "Legacy mode shows deprecation warning"
    else
        log_fail "No deprecation warning for legacy mode"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local test_filter="${1:-all}"

    echo "=========================================="
    echo "  E2E Migration Tests"
    echo "=========================================="
    echo ""

    check_prerequisites

    case "$test_filter" in
        all)
            test_fresh_install_migration
            test_upgrade_from_v050
            test_data_preservation
            test_rollback_functionality
            test_full_migration_cycle
            test_legacy_mode_works
            ;;
        *)
            if declare -f "$test_filter" >/dev/null 2>&1; then
                "$test_filter"
            else
                echo "Unknown test: $test_filter"
                exit 1
            fi
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "  Results: $PASSED passed, $FAILED failed"
    echo "=========================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
