#!/usr/bin/env bash
# benchmark-dind.sh - Performance benchmarking for HAL-9000 DinD architecture
#
# Measures:
# - Cold start time (target: <5s)
# - Warm start time (target: <2s)
# - Container memory overhead (target: <500MB)
# - Network latency (target: <100ms)
#
# Prerequisites:
# - Parent container running (hal9000-parent)
# - Docker available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPAWN_WORKER="$REPO_ROOT/plugins/hal-9000/docker/spawn-worker.sh"
POOL_MANAGER="$REPO_ROOT/plugins/hal-9000/docker/pool-manager.sh"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
ITERATIONS="${BENCHMARK_ITERATIONS:-5}"
PARENT_CONTAINER="${HAL9000_PARENT:-hal9000-parent}"
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"

# Results storage
declare -a COLD_START_TIMES=()
declare -a WARM_START_TIMES=()
declare -a MEMORY_USAGES=()

log_info() { printf "${CYAN}[bench]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[bench]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[bench]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[bench]${NC} %s\n" "$1" >&2; }

# ============================================================================
# PREREQUISITES
# ============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &>/dev/null; then
        log_error "Docker not installed"
        exit 1
    fi

    if ! docker ps &>/dev/null; then
        log_error "Docker daemon not running"
        exit 1
    fi

    # Check if parent container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PARENT_CONTAINER}$"; then
        log_warn "Parent container '$PARENT_CONTAINER' not running"
        log_warn "Cold start benchmarks will be skipped"
        SKIP_PARENT_TESTS=true
    else
        SKIP_PARENT_TESTS=false
    fi

    # Check if worker image exists
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$WORKER_IMAGE"; then
        log_warn "Worker image '$WORKER_IMAGE' not found"
        log_warn "Some benchmarks may fail"
    fi

    log_success "Prerequisites checked"
}

# ============================================================================
# UTILITIES
# ============================================================================

# Get current time in milliseconds
get_time_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use gdate if available, otherwise perl
        if command -v gdate &>/dev/null; then
            gdate +%s%3N
        else
            perl -MTime::HiRes=time -e 'printf("%.0f\n", time() * 1000)'
        fi
    else
        date +%s%3N
    fi
}

# Calculate average of array
calculate_avg() {
    local -n arr=$1
    local sum=0
    local count=${#arr[@]}

    if [[ $count -eq 0 ]]; then
        echo "0"
        return
    fi

    for val in "${arr[@]}"; do
        sum=$((sum + val))
    done

    echo $((sum / count))
}

# Calculate min of array
calculate_min() {
    local -n arr=$1
    local min=${arr[0]:-0}

    for val in "${arr[@]}"; do
        if [[ $val -lt $min ]]; then
            min=$val
        fi
    done

    echo "$min"
}

# Calculate max of array
calculate_max() {
    local -n arr=$1
    local max=${arr[0]:-0}

    for val in "${arr[@]}"; do
        if [[ $val -gt $max ]]; then
            max=$val
        fi
    done

    echo "$max"
}

# Clean up test containers
cleanup_test_containers() {
    docker ps -a --filter "name=bench-worker-" --format "{{.Names}}" 2>/dev/null | while read -r name; do
        docker rm -f "$name" 2>/dev/null || true
    done
}

# ============================================================================
# BENCHMARKS
# ============================================================================

benchmark_cold_start() {
    log_info "Benchmarking cold start time (target: <5000ms)..."

    if [[ "${SKIP_PARENT_TESTS:-false}" == "true" ]]; then
        log_warn "Skipping: parent container not running"
        return
    fi

    for i in $(seq 1 "$ITERATIONS"); do
        local worker_name="bench-worker-cold-$i-$$"

        # Clean up any existing container
        docker rm -f "$worker_name" 2>/dev/null || true

        # Measure cold start time
        local start_time end_time duration
        start_time=$(get_time_ms)

        docker run -d \
            --name "$worker_name" \
            --network "container:${PARENT_CONTAINER}" \
            --memory 4g \
            --cpus 2 \
            -w /workspace \
            "$WORKER_IMAGE" \
            bash -c "sleep infinity" >/dev/null 2>&1

        # Wait for container to be running
        while [[ "$(docker inspect -f '{{.State.Running}}' "$worker_name" 2>/dev/null)" != "true" ]]; do
            sleep 0.1
        done

        end_time=$(get_time_ms)
        duration=$((end_time - start_time))

        COLD_START_TIMES+=("$duration")
        log_info "  Iteration $i: ${duration}ms"

        # Cleanup
        docker rm -f "$worker_name" >/dev/null 2>&1 || true
    done

    local avg min max
    avg=$(calculate_avg COLD_START_TIMES)
    min=$(calculate_min COLD_START_TIMES)
    max=$(calculate_max COLD_START_TIMES)

    log_info "Cold start results: avg=${avg}ms, min=${min}ms, max=${max}ms"

    if [[ $avg -lt 5000 ]]; then
        log_success "PASS: Cold start avg ${avg}ms < 5000ms target"
    else
        log_error "FAIL: Cold start avg ${avg}ms >= 5000ms target"
    fi
}

benchmark_warm_start() {
    log_info "Benchmarking warm start time (target: <2000ms)..."

    if [[ "${SKIP_PARENT_TESTS:-false}" == "true" ]]; then
        log_warn "Skipping: parent container not running"
        return
    fi

    for i in $(seq 1 "$ITERATIONS"); do
        local warm_name="bench-warm-$i-$$"
        local claimed_name="bench-worker-warm-$i-$$"

        # Create a warm worker first
        docker run -d \
            --name "$warm_name" \
            --network "container:${PARENT_CONTAINER}" \
            --memory 4g \
            --cpus 2 \
            -w /workspace \
            "$WORKER_IMAGE" \
            bash -c "sleep infinity" >/dev/null 2>&1

        # Wait for it to be ready
        while [[ "$(docker inspect -f '{{.State.Running}}' "$warm_name" 2>/dev/null)" != "true" ]]; do
            sleep 0.1
        done

        # Now measure the claim time (rename operation)
        local start_time end_time duration
        start_time=$(get_time_ms)

        docker rename "$warm_name" "$claimed_name" >/dev/null 2>&1

        end_time=$(get_time_ms)
        duration=$((end_time - start_time))

        WARM_START_TIMES+=("$duration")
        log_info "  Iteration $i: ${duration}ms"

        # Cleanup
        docker rm -f "$claimed_name" >/dev/null 2>&1 || true
    done

    local avg min max
    avg=$(calculate_avg WARM_START_TIMES)
    min=$(calculate_min WARM_START_TIMES)
    max=$(calculate_max WARM_START_TIMES)

    log_info "Warm start results: avg=${avg}ms, min=${min}ms, max=${max}ms"

    if [[ $avg -lt 2000 ]]; then
        log_success "PASS: Warm start avg ${avg}ms < 2000ms target"
    else
        log_error "FAIL: Warm start avg ${avg}ms >= 2000ms target"
    fi
}

benchmark_memory_usage() {
    log_info "Benchmarking memory overhead (target: <500MB)..."

    if [[ "${SKIP_PARENT_TESTS:-false}" == "true" ]]; then
        log_warn "Skipping: parent container not running"
        return
    fi

    for i in $(seq 1 "$ITERATIONS"); do
        local worker_name="bench-worker-mem-$i-$$"

        # Create a worker
        docker run -d \
            --name "$worker_name" \
            --network "container:${PARENT_CONTAINER}" \
            --memory 4g \
            --cpus 2 \
            -w /workspace \
            "$WORKER_IMAGE" \
            bash -c "sleep infinity" >/dev/null 2>&1

        # Wait for it to be running
        while [[ "$(docker inspect -f '{{.State.Running}}' "$worker_name" 2>/dev/null)" != "true" ]]; do
            sleep 0.1
        done

        # Give it a moment to settle
        sleep 1

        # Get memory usage
        local mem_usage
        mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$worker_name" 2>/dev/null | awk '{print $1}')

        # Convert to MB
        local mem_mb=0
        if [[ "$mem_usage" == *"GiB"* ]]; then
            mem_mb=$(echo "$mem_usage" | sed 's/GiB//' | awk '{printf "%.0f", $1 * 1024}')
        elif [[ "$mem_usage" == *"MiB"* ]]; then
            mem_mb=$(echo "$mem_usage" | sed 's/MiB//' | awk '{printf "%.0f", $1}')
        elif [[ "$mem_usage" == *"KiB"* ]]; then
            mem_mb=$(echo "$mem_usage" | sed 's/KiB//' | awk '{printf "%.0f", $1 / 1024}')
        else
            mem_mb=0
        fi

        MEMORY_USAGES+=("$mem_mb")
        log_info "  Iteration $i: ${mem_mb}MB"

        # Cleanup
        docker rm -f "$worker_name" >/dev/null 2>&1 || true
    done

    local avg min max
    avg=$(calculate_avg MEMORY_USAGES)
    min=$(calculate_min MEMORY_USAGES)
    max=$(calculate_max MEMORY_USAGES)

    log_info "Memory results: avg=${avg}MB, min=${min}MB, max=${max}MB"

    if [[ $avg -lt 500 ]]; then
        log_success "PASS: Memory avg ${avg}MB < 500MB target"
    else
        log_error "FAIL: Memory avg ${avg}MB >= 500MB target"
    fi
}

benchmark_image_size() {
    log_info "Checking image size..."

    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$WORKER_IMAGE"; then
        log_warn "Worker image not found, skipping"
        return
    fi

    local size
    size=$(docker images "$WORKER_IMAGE" --format "{{.Size}}")

    log_info "Worker image size: $size"

    # Parse size for comparison
    local size_mb=0
    if [[ "$size" == *"GB"* ]]; then
        size_mb=$(echo "$size" | sed 's/GB//' | awk '{printf "%.0f", $1 * 1024}')
    elif [[ "$size" == *"MB"* ]]; then
        size_mb=$(echo "$size" | sed 's/MB//' | awk '{printf "%.0f", $1}')
    fi

    if [[ $size_mb -lt 1000 ]]; then
        log_success "PASS: Image size ${size} < 1GB"
    else
        log_warn "WARN: Image size ${size} >= 1GB (consider optimization)"
    fi
}

benchmark_network_latency() {
    log_info "Benchmarking network latency..."

    if [[ "${SKIP_PARENT_TESTS:-false}" == "true" ]]; then
        log_warn "Skipping: parent container not running"
        return
    fi

    local worker_name="bench-worker-net-$$"

    # Create a test worker
    docker run -d \
        --name "$worker_name" \
        --network "container:${PARENT_CONTAINER}" \
        -w /workspace \
        "$WORKER_IMAGE" \
        bash -c "sleep infinity" >/dev/null 2>&1

    # Wait for it
    while [[ "$(docker inspect -f '{{.State.Running}}' "$worker_name" 2>/dev/null)" != "true" ]]; do
        sleep 0.1
    done

    # Test localhost access (simulating MCP access)
    local start_time end_time duration
    start_time=$(get_time_ms)

    # Try to connect to localhost (parent's network)
    docker exec "$worker_name" bash -c "curl -s -o /dev/null -w '%{time_total}' http://localhost:8000/api/v2/heartbeat 2>/dev/null || echo '0'" > /dev/null

    end_time=$(get_time_ms)
    duration=$((end_time - start_time))

    log_info "Network latency test: ${duration}ms"

    if [[ $duration -lt 100 ]]; then
        log_success "PASS: Network latency ${duration}ms < 100ms target"
    else
        log_warn "WARN: Network latency ${duration}ms >= 100ms target"
    fi

    # Cleanup
    docker rm -f "$worker_name" >/dev/null 2>&1 || true
}

# ============================================================================
# REPORT
# ============================================================================

generate_report() {
    echo ""
    log_info "=========================================="
    log_info "  HAL-9000 DinD Performance Report"
    log_info "=========================================="
    echo ""

    echo "Configuration:"
    echo "  Iterations: $ITERATIONS"
    echo "  Parent container: $PARENT_CONTAINER"
    echo "  Worker image: $WORKER_IMAGE"
    echo ""

    if [[ ${#COLD_START_TIMES[@]} -gt 0 ]]; then
        echo "Cold Start (target: <5000ms):"
        echo "  Average: $(calculate_avg COLD_START_TIMES)ms"
        echo "  Min: $(calculate_min COLD_START_TIMES)ms"
        echo "  Max: $(calculate_max COLD_START_TIMES)ms"
        echo ""
    fi

    if [[ ${#WARM_START_TIMES[@]} -gt 0 ]]; then
        echo "Warm Start (target: <2000ms):"
        echo "  Average: $(calculate_avg WARM_START_TIMES)ms"
        echo "  Min: $(calculate_min WARM_START_TIMES)ms"
        echo "  Max: $(calculate_max WARM_START_TIMES)ms"
        echo ""
    fi

    if [[ ${#MEMORY_USAGES[@]} -gt 0 ]]; then
        echo "Memory Usage (target: <500MB):"
        echo "  Average: $(calculate_avg MEMORY_USAGES)MB"
        echo "  Min: $(calculate_min MEMORY_USAGES)MB"
        echo "  Max: $(calculate_max MEMORY_USAGES)MB"
        echo ""
    fi

    log_info "=========================================="
}

# ============================================================================
# MAIN
# ============================================================================

show_help() {
    cat <<EOF
Usage: benchmark-dind.sh [options] [benchmark...]

Run performance benchmarks for HAL-9000 DinD architecture.

Benchmarks:
  cold          Cold start time (target: <5s)
  warm          Warm start time (target: <2s)
  memory        Container memory overhead (target: <500MB)
  network       Network latency (target: <100ms)
  image         Image size check
  all           Run all benchmarks (default)

Options:
  -n, --iterations N    Number of iterations per benchmark (default: 5)
  -h, --help            Show this help

Examples:
  benchmark-dind.sh                     # Run all benchmarks
  benchmark-dind.sh cold warm           # Run only cold and warm start benchmarks
  benchmark-dind.sh -n 10 all           # Run all benchmarks with 10 iterations
EOF
}

main() {
    local benchmarks=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            cold|warm|memory|network|image|all)
                benchmarks+=("$1")
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Default to all benchmarks
    if [[ ${#benchmarks[@]} -eq 0 ]]; then
        benchmarks=(all)
    fi

    echo ""
    log_info "=========================================="
    log_info "  HAL-9000 DinD Performance Benchmarks"
    log_info "=========================================="
    echo ""

    check_prerequisites

    # Cleanup any leftover test containers
    cleanup_test_containers

    # Run requested benchmarks
    for bench in "${benchmarks[@]}"; do
        case "$bench" in
            cold)
                benchmark_cold_start
                ;;
            warm)
                benchmark_warm_start
                ;;
            memory)
                benchmark_memory_usage
                ;;
            network)
                benchmark_network_latency
                ;;
            image)
                benchmark_image_size
                ;;
            all)
                benchmark_image_size
                benchmark_cold_start
                benchmark_warm_start
                benchmark_memory_usage
                benchmark_network_latency
                ;;
        esac
    done

    # Cleanup
    cleanup_test_containers

    # Generate report
    generate_report
}

main "$@"
