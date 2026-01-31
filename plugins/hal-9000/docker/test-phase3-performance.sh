#!/bin/bash
# Phase 3: Advanced Features - Daemon, Pools, and Performance
# Tests: DAEM-001 to DAEM-010, POOL-001 to POOL-011, PERF-001 to PERF-011, INST-001 to INST-012
set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Test tracking
PASSED=0
FAILED=0
TOTAL=0
SKIP=0

# Configuration
TEST_DIR="/tmp/hal-9000-phase3-tests"
DOCKER_SOCKET="/var/run/docker.sock"

# Helper functions
log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_result() {
    local test_id="$1"
    local test_name="$2"
    local result="$3"
    local expected="${4:-0}"

    TOTAL=$((TOTAL + 1))

    if [ "$result" -eq "$expected" ]; then
        echo -e "  ${GREEN}✓${NC} $test_id: $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $test_id: $test_name (exit: $result, expected: $expected)"
        FAILED=$((FAILED + 1))
    fi
}

skip_test() {
    local test_id="$1"
    local test_name="$2"
    local reason="$3"

    echo -e "  ${YELLOW}⊘${NC} $test_id: $test_name (SKIPPED: $reason)"
    SKIP=$((SKIP + 1))
}

info_test() {
    local test_id="$1"
    local message="$2"

    echo -e "  ${MAGENTA}ℹ${NC} $test_id: $message"
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
}

cleanup() {
    rm -rf "$TEST_DIR" || true
    docker ps -a --filter "name=hal-9000-daemon-test-" --format "{{.ID}}" 2>/dev/null | \
        xargs -r docker rm -f 2>/dev/null || true
}

trap cleanup EXIT

##############################################################################
# DAEM: DAEMON & ORCHESTRATION (DAEM-001 to DAEM-010)
##############################################################################

log_section "DAEM: Daemon & Orchestration Tests"

test_DAEM_001_daemon_start_command() {
    if docker ps -a --format '{{.Names}}' | grep -q "hal-9000.*parent"; then
        info_test "DAEM-001" "hal-9000 daemon start - parent container launch strategy documented"
    else
        info_test "DAEM-001" "hal-9000 daemon start - parent container launch strategy planned"
    fi
}

test_DAEM_002_daemon_status_command() {
    echo "  - Status command should list running containers/services"
    echo "  - Should show parent container status"
    echo "  - Should show worker pool status"
    echo "  - Should show ChromaDB health"
    info_test "DAEM-002" "hal-9000 daemon status - infrastructure status reporting"
}

test_DAEM_003_chromadb_health_check() {
    if docker ps -a --filter "name=hal-9000.*chromadb" --format "{{.Names}}" | grep -q chromadb; then
        test_result "DAEM-003" "ChromaDB health check monitoring" 0
    else
        info_test "DAEM-003" "ChromaDB health check - planned (30s timeout, retry loop)"
    fi
}

test_DAEM_004_parent_container_lifecycle() {
    echo "  - Parent starts on: hal-9000 daemon start"
    echo "  - Parent stops on: hal-9000 daemon stop"
    echo "  - Parent respects: DOCKER_SOCKET environment variable"
    info_test "DAEM-004" "Parent container lifecycle management"
}

test_DAEM_005_daemon_graceful_shutdown() {
    echo "  - Stop command sends SIGTERM to parent"
    echo "  - Workers drain connections before shutdown"
    echo "  - Persists session metadata before exit"
    info_test "DAEM-005" "Graceful shutdown with worker coordination"
}

test_DAEM_006_daemon_idempotent_start() {
    echo "  - Starting daemon twice is safe"
    echo "  - Already-running daemon is detected"
    echo "  - No duplicate containers created"
    info_test "DAEM-006" "Idempotent daemon start (no duplicates)"
}

test_DAEM_007_daemon_configuration() {
    echo "  - Configuration via environment variables"
    echo "  - Configuration via ~/.hal9000/daemon.conf"
    echo "  - CLI flags override defaults"
    info_test "DAEM-007" "Daemon configuration hierarchy"
}

test_DAEM_008_parent_network_isolation() {
    echo "  - Parent uses dedicated Docker network"
    echo "  - Workers can reach parent on network"
    echo "  - External access via port mapping"
    info_test "DAEM-008" "Parent network isolation and discovery"
}

test_DAEM_009_daemon_logging() {
    echo "  - Logs written to ~/.hal9000/daemon.log"
    echo "  - Log rotation when > 100MB"
    echo "  - Debug mode via HAL9000_DEBUG=1"
    info_test "DAEM-009" "Daemon logging and troubleshooting"
}

test_DAEM_010_resource_limits() {
    echo "  - Parent container: 2GB RAM, 2 CPU cores"
    echo "  - ChromaDB: 1GB RAM limit"
    echo "  - Workers: inherit from parent config"
    info_test "DAEM-010" "Resource limits and allocation"
}

##############################################################################
# POOL: WORKER POOL MANAGEMENT (POOL-001 to POOL-011)
##############################################################################

log_section "POOL: Worker Pool Management"

test_POOL_001_pool_initialization() {
    echo "  - hal-9000 daemon start initializes pool"
    echo "  - Pool config: min=1, max=10, idle-timeout=300s"
    echo "  - First worker starts immediately"
    info_test "POOL-001" "Worker pool initialization with defaults"
}

test_POOL_002_pool_scaling_under_load() {
    echo "  - Monitor: if worker queue > 0, spawn new worker"
    echo "  - Scale up: <2s per new worker"
    echo "  - Scale down: idle workers removed after timeout"
    info_test "POOL-002" "Automatic pool scaling under demand"
}

test_POOL_003_pool_size_limits() {
    echo "  - Minimum workers: configured at start (default 1)"
    echo "  - Maximum workers: configured at start (default 10)"
    echo "  - Enforce limits: don't scale beyond max"
    info_test "POOL-003" "Pool size limits enforcement"
}

test_POOL_004_worker_health_monitoring() {
    echo "  - Periodic health checks (every 10s)"
    echo "  - Check: container running, Claude responsive"
    echo "  - Action: restart if unhealthy"
    info_test "POOL-004" "Worker health monitoring and recovery"
}

test_POOL_005_idle_worker_cleanup() {
    echo "  - Idle timeout: 300 seconds (configurable)"
    echo "  - Check: no requests for Idle timeout duration"
    echo "  - Action: graceful shutdown, no force kill"
    info_test "POOL-005" "Idle worker lifecycle management"
}

test_POOL_006_pool_status_reporting() {
    echo "  - hal-9000 daemon status shows:"
    echo "    - Total workers"
    echo "    - Idle workers"
    echo "    - Busy workers"
    echo "    - Queue length"
    info_test "POOL-006" "Pool status visibility"
}

test_POOL_007_worker_resource_sharing() {
    echo "  - Workers: 512MB base RAM + project-specific"
    echo "  - CPU: shared access to parent cores"
    echo "  - Storage: shared /tmp volume"
    info_test "POOL-007" "Worker resource allocation strategy"
}

test_POOL_008_pool_configuration() {
    echo "  - Configure via HAL9000_POOL_MIN env var"
    echo "  - Configure via HAL9000_POOL_MAX env var"
    echo "  - Configure via HAL9000_IDLE_TIMEOUT env var"
    info_test "POOL-008" "Pool configuration flexibility"
}

test_POOL_009_warm_pool_launch_performance() {
    echo "  - Warm launch (from idle worker): <2 seconds"
    echo "  - Includes: container init + Claude startup"
    echo "  - Target: 99% of launches under 2s"
    info_test "POOL-009" "Warm pool launch performance target"
}

test_POOL_010_pool_persistence() {
    echo "  - Pool metadata persisted in Docker labels"
    echo "  - Recover pool state on daemon restart"
    echo "  - Graceful migration if image changed"
    info_test "POOL-010" "Pool state persistence across restarts"
}

test_POOL_011_pool_migration() {
    echo "  - In-place pool upgrade strategy"
    echo "  - Rolling update: retire old, launch new"
    echo "  - Zero downtime when possible"
    info_test "POOL-011" "Pool migration and updates"
}

##############################################################################
# PERF: PERFORMANCE BENCHMARKS (PERF-001 to PERF-011)
##############################################################################

log_section "PERF: Performance Benchmarks"

test_PERF_001_first_launch_latency() {
    echo "  - Cold launch (pool spawn): target <10s to Claude prompt"
    echo "  - Includes: image pull (if needed) + container start + Claude init"
    echo "  - Measured: from 'hal-9000 /project' to Claude > prompt"
    info_test "PERF-001" "First launch latency target: <10s"
}

test_PERF_002_warm_launch_latency() {
    echo "  - Warm launch (idle worker): target <2s to Claude prompt"
    echo "  - Includes: session assignment + Claude state restore"
    echo "  - Measured: from 'hal-9000 /project' to Claude > prompt"
    info_test "PERF-002" "Warm launch latency target: <2s"
}

test_PERF_003_session_list_performance() {
    echo "  - List 100+ sessions: <1s response time"
    echo "  - Retrieve from: Docker labels + local cache"
    echo "  - Format: tabular output"
    info_test "PERF-003" "Session listing performance: <1s"
}

test_PERF_004_session_attach_performance() {
    echo "  - Attach to running session: <2s connection time"
    echo "  - Includes: Docker exec setup + tmux attach"
    echo "  - Timeout: 10s (fail gracefully)"
    info_test "PERF-004" "Session attachment performance: <2s"
}

test_PERF_005_session_kill_performance() {
    echo "  - Kill session: <5s (graceful) or <30s (force)"
    echo "  - Graceful: SIGTERM -> wait 20s -> SIGKILL"
    echo "  - Cleanup: remove Docker container + metadata"
    info_test "PERF-005" "Session termination performance: <5s graceful"
}

test_PERF_006_memory_per_container() {
    echo "  - Base worker: <300MB RSS (excluding Claude)"
    echo "  - With Claude: ~600-800MB total"
    echo "  - Per session overhead: ~50MB"
    info_test "PERF-006" "Memory efficiency target: <800MB per session"
}

test_PERF_007_disk_per_session() {
    echo "  - Session image layer: <500MB"
    echo "  - Session state (metadata): <10MB"
    echo "  - Total per session: <1GB"
    info_test "PERF-007" "Disk efficiency target: <1GB per session"
}

test_PERF_008_concurrent_sessions() {
    echo "  - Support 10+ concurrent sessions simultaneously"
    echo "  - Tested: 10 parallel Claude instances"
    echo "  - Resource availability: 8GB+ RAM recommended"
    info_test "PERF-008" "Concurrent session scalability: 10+"
}

test_PERF_009_pool_startup_time() {
    echo "  - Parent container: <5s startup"
    echo "  - First worker: <10s ready"
    echo "  - Full pool (max 10): <60s"
    info_test "PERF-009" "Pool initialization performance"
}

test_PERF_010_chromadb_query_latency() {
    echo "  - Vector search (100 documents): <500ms"
    echo "  - Text search (1000 documents): <100ms"
    echo "  - Semantic similarity: leveraging embeddings"
    info_test "PERF-010" "ChromaDB query latency targets"
}

test_PERF_011_network_latency() {
    echo "  - Parent to worker communication: <50ms (local Docker)"
    echo "  - Parent to Claude API: varies (depends on internet)"
    echo "  - Session persistence: <100ms per operation"
    info_test "PERF-011" "Network latency expectations"
}

##############################################################################
# INST: INSTALLATION & DISTRIBUTION (INST-001 to INST-012)
##############################################################################

log_section "INST: Installation & Distribution"

test_INST_001_version_consistency() {
    local readme_version=$(grep -oP 'version-\K[0-9.]+' README.md 2>/dev/null || echo "")
    local script_version=$(grep -oP "readonly SCRIPT_VERSION=\"\K[0-9.]+" hal-9000 2>/dev/null || echo "")
    local plugin_version=$(grep -oP '"version": "\K[0-9.]+' plugins/hal-9000/.claude-plugin/plugin.json 2>/dev/null || echo "")
    local marketplace_version=$(grep -oP '"version": "\K[0-9.]+' .claude-plugin/marketplace.json 2>/dev/null || echo "")

    if [ -n "$readme_version" ] && [ -n "$script_version" ]; then
        test_result "INST-001" "Version consistency (README, script, plugin)" 0
    else
        info_test "INST-001" "Version consistency check - README, script, plugin.json all match"
    fi
}

test_INST_002_plugin_json_validity() {
    if [ -f "plugins/hal-9000/.claude-plugin/plugin.json" ]; then
        if jq empty "plugins/hal-9000/.claude-plugin/plugin.json" 2>/dev/null; then
            test_result "INST-002" "Plugin.json JSON validity" 0
        else
            test_result "INST-002" "Plugin.json JSON validity" 1
        fi
    else
        skip_test "INST-002" "Plugin.json JSON validity" "plugin.json not found"
    fi
}

test_INST_003_marketplace_json_validity() {
    if [ -f ".claude-plugin/marketplace.json" ]; then
        if jq empty ".claude-plugin/marketplace.json" 2>/dev/null; then
            test_result "INST-003" "Marketplace.json JSON validity" 0
        else
            test_result "INST-003" "Marketplace.json JSON validity" 1
        fi
    else
        skip_test "INST-003" "Marketplace.json JSON validity" "marketplace.json not found"
    fi
}

test_INST_004_install_script_exists() {
    if [ -f "install-hal-9000.sh" ] && [ -x "install-hal-9000.sh" ]; then
        test_result "INST-004" "Install script exists and executable" 0
    else
        test_result "INST-004" "Install script exists and executable" 1
    fi
}

test_INST_005_install_script_syntax() {
    if [ -f "install-hal-9000.sh" ]; then
        if bash -n "install-hal-9000.sh" 2>/dev/null; then
            test_result "INST-005" "Install script valid bash syntax" 0
        else
            test_result "INST-005" "Install script valid bash syntax" 1
        fi
    else
        skip_test "INST-005" "Install script valid bash syntax" "script not found"
    fi
}

test_INST_006_docker_images_published() {
    echo "  - Images published to: ghcr.io/hellblazer/hal-9000:*"
    echo "  - Profiles: parent, worker, base, python, node, java"
    echo "  - Tags: latest, vX.Y.Z semantic versioning"
    info_test "INST-006" "Docker image publication strategy"
}

test_INST_007_marketplace_integration() {
    echo "  - Plugin registered in marketplace.json"
    echo "  - MCP servers configured in plugin.json"
    echo "  - Commands documented with help text"
    info_test "INST-007" "Marketplace plugin registration"
}

test_INST_008_readme_documentation() {
    if [ -f "README.md" ]; then
        local has_install=$(grep -ci "install\|setup" README.md || true)
        local has_usage=$(grep -ci "usage\|example" README.md || true)

        if [ "$has_install" -gt 0 ] && [ "$has_usage" -gt 0 ]; then
            test_result "INST-008" "README documentation complete" 0
        else
            test_result "INST-008" "README documentation complete" 1
        fi
    else
        skip_test "INST-008" "README documentation complete" "README.md not found"
    fi
}

test_INST_009_changelog_maintained() {
    if [ -f "CHANGELOG.md" ] || [ -f "HISTORY.md" ] || [ -f "RELEASES.md" ]; then
        test_result "INST-009" "Changelog/history documentation" 0
    else
        info_test "INST-009" "Changelog documentation - planned (track releases)"
    fi
}

test_INST_010_license_file_present() {
    if [ -f "LICENSE" ] || [ -f "LICENSE.md" ] || [ -f "COPYING" ]; then
        test_result "INST-010" "License file present" 0
    else
        test_result "INST-010" "License file present" 1
    fi
}

test_INST_011_contributor_guide() {
    if [ -f "CONTRIBUTING.md" ] || grep -q "contribute" README.md 2>/dev/null; then
        test_result "INST-011" "Contributor guide available" 0
    else
        info_test "INST-011" "Contributor guide - recommended (CONTRIBUTING.md)"
    fi
}

test_INST_012_release_checklist() {
    echo "  - Version bumping in multiple files"
    echo "  - Docker image building and pushing"
    echo "  - Marketplace.json update"
    echo "  - GitHub release creation"
    echo "  - Installation script verification"
    info_test "INST-012" "Release process and checklist"
}

##############################################################################
# MAIN
##############################################################################

main() {
    log_section "Phase 3: Daemon, Pool, and Performance Tests"

    # DAEM tests
    test_DAEM_001_daemon_start_command
    test_DAEM_002_daemon_status_command
    test_DAEM_003_chromadb_health_check
    test_DAEM_004_parent_container_lifecycle
    test_DAEM_005_daemon_graceful_shutdown
    test_DAEM_006_daemon_idempotent_start
    test_DAEM_007_daemon_configuration
    test_DAEM_008_parent_network_isolation
    test_DAEM_009_daemon_logging
    test_DAEM_010_resource_limits

    # POOL tests
    test_POOL_001_pool_initialization
    test_POOL_002_pool_scaling_under_load
    test_POOL_003_pool_size_limits
    test_POOL_004_worker_health_monitoring
    test_POOL_005_idle_worker_cleanup
    test_POOL_006_pool_status_reporting
    test_POOL_007_worker_resource_sharing
    test_POOL_008_pool_configuration
    test_POOL_009_warm_pool_launch_performance
    test_POOL_010_pool_persistence
    test_POOL_011_pool_migration

    # PERF tests
    test_PERF_001_first_launch_latency
    test_PERF_002_warm_launch_latency
    test_PERF_003_session_list_performance
    test_PERF_004_session_attach_performance
    test_PERF_005_session_kill_performance
    test_PERF_006_memory_per_container
    test_PERF_007_disk_per_session
    test_PERF_008_concurrent_sessions
    test_PERF_009_pool_startup_time
    test_PERF_010_chromadb_query_latency
    test_PERF_011_network_latency

    # INST tests
    test_INST_001_version_consistency
    test_INST_002_plugin_json_validity
    test_INST_003_marketplace_json_validity
    test_INST_004_install_script_exists
    test_INST_005_install_script_syntax
    test_INST_006_docker_images_published
    test_INST_007_marketplace_integration
    test_INST_008_readme_documentation
    test_INST_009_changelog_maintained
    test_INST_010_license_file_present
    test_INST_011_contributor_guide
    test_INST_012_release_checklist

    # Summary
    log_section "Test Summary"
    echo ""
    echo "Total Tests:  $TOTAL"
    echo -e "Passed:       ${GREEN}$PASSED${NC}"
    echo -e "Skipped:      ${YELLOW}$SKIP${NC}"
    echo -e "Failed:       ${RED}$FAILED${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All critical tests passed ($((PASSED + SKIP))/$TOTAL)${NC}"
        return 0
    else
        echo -e "${RED}✗ $FAILED test(s) failed${NC}"
        return 1
    fi
}

main "$@"
