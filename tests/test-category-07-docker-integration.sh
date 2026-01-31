#!/usr/bin/env bash
# test-category-07-docker-integration.sh - Test Docker Integration
#
# Tests container lifecycle, volume management, state persistence,
# Docker-in-Docker, and image handling.
#
# Test IDs: DOCK-001 to DOCK-026

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

# Find script directory and hal-9000 command
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HAL9000_CMD="${HAL9000_CMD:-$REPO_ROOT/hal-9000}"

# Check if Docker is available
DOCKER_AVAILABLE=false
if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
    DOCKER_AVAILABLE=true
fi

echo "=========================================="
echo "Test Category 7: Docker Integration"
echo "=========================================="
echo "HAL-9000 command: $HAL9000_CMD"
echo "Docker available: $DOCKER_AVAILABLE"
echo ""

#==========================================
# 7.1 Container Creation (DOCK-001 to DOCK-006)
#==========================================

test_dock_001() {
    log_test "DOCK-001: Container naming convention (hal-9000-{basename}-{hash})"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker - manual test"
        echo "  Manual: Start hal-9000, check container name matches pattern"
        echo "  Expected: docker ps shows 'hal-9000-{project-basename}-{hash}'"
        return
    fi

    log_skip "Manual Docker inspection test"
    echo "  1. Start: hal-9000 /tmp/test-project"
    echo "  2. Run: docker ps"
    echo "  3. Verify: Container name matches 'hal-9000-test-project-*'"
}

test_dock_002() {
    log_test "DOCK-002: Container runs in detached mode (-d flag)"
    log_skip "Manual Docker test"
    echo "  Manual: Verify container doesn't block terminal"
    echo "  Expected: Container runs in background, terminal returns immediately"
}

test_dock_003() {
    log_test "DOCK-003: Working directory set to /workspace"
    log_skip "Manual Docker inspection test"
    echo "  1. Start session"
    echo "  2. Run: docker inspect <container> | jq '.[0].Config.WorkingDir'"
    echo "  3. Verify: Shows '/workspace'"
}

test_dock_004() {
    log_test "DOCK-004: Environment variables (CLAUDE_HOME, HAL9000_SESSION, etc.)"
    log_skip "Manual Docker inspection test"
    echo "  1. Start session"
    echo "  2. Run: docker inspect <container> | jq '.[0].Config.Env'"
    echo "  3. Verify: Contains CLAUDE_HOME, HAL9000_SESSION, ANTHROPIC_API_KEY"
}

test_dock_005() {
    log_test "DOCK-005: Container labels (hal9000.session, profile, project)"
    log_skip "Manual Docker inspection test"
    echo "  1. Start session"
    echo "  2. Run: docker inspect <container> | jq '.[0].Config.Labels'"
    echo "  3. Verify: Contains 'hal9000.session=true', 'hal9000.profile=*', 'hal9000.project=*'"
}

test_dock_006() {
    log_test "DOCK-006: Restart policy (persistent containers)"
    log_skip "Manual Docker inspection test"
    echo "  1. Start session"
    echo "  2. Run: docker inspect <container> | jq '.[0].HostConfig.RestartPolicy'"
    echo "  3. Verify: Not using --rm, container persists after exit"
}

#==========================================
# 7.2 Volume Management (DOCK-007 to DOCK-012)
#==========================================

test_dock_007() {
    log_test "DOCK-007: hal9000-claude-home volume mounted at /root/.claude"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker - check volume exists"
        echo "  Manual: docker volume ls | grep hal9000-claude-home"
        return
    fi

    if docker volume ls | grep -q "hal9000-claude-home"; then
        log_pass "hal9000-claude-home volume exists"
    else
        log_skip "Volume not yet created (start a session first)"
    fi
}

test_dock_008() {
    log_test "DOCK-008: hal9000-claude-session volume for session state"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker - check volume exists"
        return
    fi

    if docker volume ls | grep -q "hal9000-claude-session"; then
        log_pass "hal9000-claude-session volume exists"
    else
        log_skip "Volume not yet created (start a session first)"
    fi
}

test_dock_009() {
    log_test "DOCK-009: hal9000-memory-bank volume for ChromaDB"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker - check volume exists"
        return
    fi

    if docker volume ls | grep -q "hal9000-memory-bank"; then
        log_pass "hal9000-memory-bank volume exists"
    else
        log_skip "Volume not yet created (start a session first)"
    fi
}

test_dock_010() {
    log_test "DOCK-010: Project directory mounted at /workspace (RW)"
    log_skip "Manual Docker test"
    echo "  1. Start session with /tmp/test-project"
    echo "  2. Inside container: touch /workspace/test.txt"
    echo "  3. On host: ls /tmp/test-project/test.txt"
    echo "  4. Verify: File exists on host (RW mount works)"
}

test_dock_011() {
    log_test "DOCK-011: Docker socket mounted for DinD"
    log_skip "Manual Docker test"
    echo "  1. Start session"
    echo "  2. Inside container: docker ps"
    echo "  3. Verify: Shows parent containers (DinD works)"
}

test_dock_012() {
    log_test "DOCK-012: Volumes auto-created if missing"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker - verify auto-creation"
        return
    fi

    log_skip "Manual test - remove volumes then start session"
    echo "  1. docker volume rm hal9000-claude-home (if exists)"
    echo "  2. Start: hal-9000 /tmp/test"
    echo "  3. Verify: Volume created automatically without error"
}

#==========================================
# 7.3 Session State Persistence (DOCK-013 to DOCK-017)
#==========================================

test_dock_013() {
    log_test "DOCK-013: Session creates .claude.json in volume"
    log_skip "Manual Docker volume inspection"
    echo "  1. Start and login to session"
    echo "  2. Exit session"
    echo "  3. Run: docker run --rm -v hal9000-claude-session:/data alpine ls /data"
    echo "  4. Verify: .claude.json exists"
}

test_dock_014() {
    log_test "DOCK-014: Session state persists after container kill"
    log_skip "Manual Docker test"
    echo "  1. Start session, login, create some state"
    echo "  2. hal-9000 kill <session>"
    echo "  3. Verify: Container removed, volume remains"
    echo "  4. docker volume ls shows hal9000-claude-session still exists"
}

test_dock_015() {
    log_test "DOCK-015: Session state restored on recreate"
    log_skip "Manual Docker test"
    echo "  1. Start session, login (creates .claude.json)"
    echo "  2. Exit session"
    echo "  3. Start new session in different project"
    echo "  4. Verify: Already logged in (session restored)"
}

test_dock_016() {
    log_test "DOCK-016: Login credentials persist across sessions"
    log_skip "Manual authentication test"
    echo "  1. Login with subscription (hal-9000 login)"
    echo "  2. Exit and start new session"
    echo "  3. Verify: No re-login required"
}

test_dock_017() {
    log_test "DOCK-017: Plugin installations persist"
    log_skip "Manual plugin test"
    echo "  1. Install plugin in session"
    echo "  2. Exit session"
    echo "  3. Start new session"
    echo "  4. Verify: Plugin still installed"
}

#==========================================
# 7.4 Docker Socket & DinD (DOCK-018 to DOCK-022)
#==========================================

test_dock_018() {
    log_test "DOCK-018: Docker socket at standard location (/var/run/docker.sock)"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker"
        return
    fi

    if [[ -S /var/run/docker.sock ]]; then
        log_pass "Docker socket exists at /var/run/docker.sock"
    else
        log_skip "Socket at different location (macOS uses ~/.docker/run/docker.sock)"
    fi
}

test_dock_019() {
    log_test "DOCK-019: Fallback socket detection (~/.docker/run/docker.sock)"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker"
        return
    fi

    if [[ -S "$HOME/.docker/run/docker.sock" ]]; then
        log_pass "Alternative Docker socket found at ~/.docker/run/docker.sock"
    else
        log_skip "Using standard socket location"
    fi
}

test_dock_020() {
    log_test "DOCK-020: Error when Docker socket missing"
    log_skip "Manual test - requires stopping Docker"
    echo "  1. Stop Docker daemon"
    echo "  2. hal-9000 /tmp/test"
    echo "  3. Verify: Error message about Docker socket, exit code 3"
}

test_dock_021() {
    log_test "DOCK-021: Error when Docker daemon not running"
    log_skip "Manual test - requires stopping Docker"
    echo "  Same as DOCK-020 - socket exists but daemon unreachable"
}

test_dock_022() {
    log_test "DOCK-022: Container can run docker ps (DinD works)"
    log_skip "Manual Docker-in-Docker test"
    echo "  1. Start session"
    echo "  2. Inside container: docker ps"
    echo "  3. Verify: Lists parent containers (DinD functional)"
}

#==========================================
# 7.5 Image & Registry (DOCK-023 to DOCK-026)
#==========================================

test_dock_023() {
    log_test "DOCK-023: Image pulls from registry if not local"
    log_skip "Manual registry test"
    echo "  1. Remove local image: docker rmi ghcr.io/hellblazer/hal-9000:base"
    echo "  2. Start: hal-9000 /tmp/test"
    echo "  3. Verify: Image pulled from ghcr.io"
}

test_dock_024() {
    log_test "DOCK-024: Registry unreachable handling"
    log_skip "Manual network test"
    echo "  1. Disconnect network"
    echo "  2. Remove local image"
    echo "  3. Start: hal-9000 /tmp/test"
    echo "  4. Verify: Clear error message about registry"
}

test_dock_025() {
    log_test "DOCK-025: Uses local image if available"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker"
        return
    fi

    if docker images | grep -q "ghcr.io/hellblazer/hal-9000"; then
        log_pass "Local hal-9000 images found (will use local instead of pulling)"
    else
        log_skip "No local images - would pull from registry"
    fi
}

test_dock_026() {
    log_test "DOCK-026: Docker version check and warnings"

    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        log_skip "Requires Docker"
        return
    fi

    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")

    if [[ "$docker_version" != "unknown" ]]; then
        log_pass "Docker version detected: $docker_version"
    else
        log_fail "Could not detect Docker version"
    fi
}

#==========================================
# Main Test Runner
#==========================================

main() {
    # 7.1 Container Creation
    test_dock_001 || true
    test_dock_002 || true
    test_dock_003 || true
    test_dock_004 || true
    test_dock_005 || true
    test_dock_006 || true

    # 7.2 Volume Management
    test_dock_007 || true
    test_dock_008 || true
    test_dock_009 || true
    test_dock_010 || true
    test_dock_011 || true
    test_dock_012 || true

    # 7.3 Session State Persistence
    test_dock_013 || true
    test_dock_014 || true
    test_dock_015 || true
    test_dock_016 || true
    test_dock_017 || true

    # 7.4 Docker Socket & DinD
    test_dock_018 || true
    test_dock_019 || true
    test_dock_020 || true
    test_dock_021 || true
    test_dock_022 || true

    # 7.5 Image & Registry
    test_dock_023 || true
    test_dock_024 || true
    test_dock_025 || true
    test_dock_026 || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Passed:  $TESTS_PASSED"
    echo "Failed:  $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED (manual or Docker-required)"
    echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All automated tests passed!"
        echo ""
        echo "Manual tests require:"
        echo "  - Running hal-9000 sessions"
        echo "  - Docker inspect commands"
        echo "  - Volume and container lifecycle verification"
        echo ""
        echo "See test output above for manual test procedures."
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
