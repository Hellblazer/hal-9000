#!/usr/bin/env bash
#
# HAL-9000 Installation Test Script
# Tests installation across different container environments
#
# Usage:
#   ./test-installation.sh [options]
#
# Options:
#   --distro DISTRO    Test specific distro (debian, ubuntu, fedora, alpine)
#   --all              Test all supported distros
#   --verbose          Show detailed output
#   --no-cleanup       Keep containers after test
#
# Examples:
#   ./test-installation.sh --distro debian
#   ./test-installation.sh --all
#   ./test-installation.sh --distro ubuntu --verbose --no-cleanup

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Default options
VERBOSE=false
CLEANUP=true
TEST_ALL=false
DISTRO=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAL_9000_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Supported distributions
declare -A DISTROS=(
    ["debian"]="debian:bookworm-slim"
    ["ubuntu"]="ubuntu:24.04"
    ["fedora"]="fedora:39"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --distro)
            DISTRO="$2"
            shift 2
            ;;
        --all)
            TEST_ALL=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --help)
            head -n 20 "$0" | tail -n +2 | sed 's/^# //'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate distro
if [[ -n "$DISTRO" ]] && [[ ! -v DISTROS[$DISTRO] ]]; then
    echo -e "${RED}Error: Unknown distro '$DISTRO'${NC}"
    echo "Supported: ${!DISTROS[@]}"
    exit 1
fi

# Print message
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# Test installation in a specific distro
test_distro() {
    local distro_name=$1
    local image=${DISTROS[$distro_name]}

    echo ""
    log "═══════════════════════════════════════════════════════"
    log "Testing: $distro_name ($image)"
    log "═══════════════════════════════════════════════════════"
    echo ""

    local container_name="hal9000-test-${distro_name}-$$"
    local exit_code=0

    # Create test script
    local test_script=$(mktemp)
    cat > "$test_script" <<'EOF'
#!/bin/bash
set -euo pipefail

# Install prerequisites
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq curl nodejs npm python3 python3-pip git > /dev/null 2>&1
elif command -v dnf &> /dev/null; then
    dnf install -y -q nodejs npm python3 python3-pip git > /dev/null 2>&1
fi

# Set PATH before installation to avoid interactive prompts
export PATH="/root/.local/bin:$PATH"

# Run installation with all required inputs
cd /workspace
# Provide inputs: mode=2 (Host Only), chromadb type=2 (Local), path=default (blank)
{ echo "2"; echo "2"; echo ""; echo "n"; } | ./plugins/hal-9000/install.sh 2>&1 | tee /tmp/install.log

# Verify installation

echo ""
echo "Verifying installation..."

# Check for chroma-mcp
if ! command -v chroma-mcp &> /dev/null; then
    echo "ERROR: chroma-mcp not found"
    exit 1
fi

# Check for memory-bank-server
if ! command -v memory-bank-server &> /dev/null; then
    echo "ERROR: memory-bank-server not found"
    exit 1
fi

# Verify PEP 668 handling
if grep -q "Detected PEP 668 protected environment" /tmp/install.log; then
    echo "✓ PEP 668 protection detected and handled"
elif grep -q "externally-managed-environment" /tmp/install.log; then
    echo "ERROR: PEP 668 not handled correctly"
    exit 1
fi

echo "✓ chroma-mcp installed"
echo "✓ memory-bank-server installed"
echo ""
echo "SUCCESS: All checks passed!"
EOF

    # Run test in container
    if $VERBOSE; then
        docker run --rm \
            --name "$container_name" \
            -v "$HAL_9000_ROOT:/workspace:ro" \
            -v "$test_script:/test.sh:ro" \
            "$image" \
            bash /test.sh || exit_code=$?
    else
        docker run --rm \
            --name "$container_name" \
            -v "$HAL_9000_ROOT:/workspace:ro" \
            -v "$test_script:/test.sh:ro" \
            "$image" \
            bash /test.sh > /dev/null 2>&1 || exit_code=$?
    fi

    # Cleanup
    rm -f "$test_script"

    # Report results
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_success "$distro_name: Installation test PASSED"
    else
        log_error "$distro_name: Installation test FAILED (exit code: $exit_code)"
    fi
    echo ""

    return $exit_code
}

# Main execution
main() {
    log "HAL-9000 Installation Test Suite"
    log "Testing installation across different environments"
    echo ""

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi

    # Determine which distros to test
    local distros_to_test=()
    if [[ -n "$DISTRO" ]]; then
        distros_to_test=("$DISTRO")
    elif $TEST_ALL; then
        distros_to_test=("${!DISTROS[@]}")
    else
        # Default: test Debian only
        distros_to_test=("debian")
    fi

    log "Testing ${#distros_to_test[@]} distribution(s): ${distros_to_test[*]}"

    # Run tests
    local failed_tests=()
    for distro in "${distros_to_test[@]}"; do
        if ! test_distro "$distro"; then
            failed_tests+=("$distro")
        fi
    done

    # Summary
    echo ""
    log "═══════════════════════════════════════════════════════"
    log "Test Summary"
    log "═══════════════════════════════════════════════════════"
    echo ""

    local total=${#distros_to_test[@]}
    local failed=${#failed_tests[@]}
    local passed=$((total - failed))

    log_success "Passed: $passed/$total"

    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed/$total"
        echo ""
        log_error "Failed distributions:"
        for distro in "${failed_tests[@]}"; do
            echo "  - $distro"
        done
        echo ""
        exit 1
    else
        echo ""
        log_success "All tests passed!"
        echo ""
        exit 0
    fi
}

# Run main
main "$@"
