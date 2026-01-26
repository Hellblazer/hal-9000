#!/usr/bin/env bash
# pool-manager.sh - Worker Pool Manager for HAL-9000
#
# Maintains a pool of warm workers for fast container startup.
# Runs as a background daemon in the parent container.
#
# Usage:
#   pool-manager.sh <command> [options]
#
# Commands:
#   start           Start the pool manager daemon
#   stop            Stop the pool manager daemon
#   status          Show pool status
#   scale <n>       Scale pool to n warm workers
#   cleanup         Force cleanup of idle workers
#
# Options:
#   --min-warm N    Minimum warm workers (default: 2)
#   --max-warm N    Maximum warm workers (default: 5)
#   --idle-timeout  Seconds before idle worker cleanup (default: 300)
#   --check-interval Seconds between checks (default: 30)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[pool]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[pool]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[pool]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[pool]${NC} %s\n" "$1" >&2; }

# Configuration
HAL9000_HOME="${HAL9000_HOME:-/root/.hal9000}"
POOL_STATE_DIR="${HAL9000_HOME}/pool"
PID_FILE="${POOL_STATE_DIR}/pool-manager.pid"
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"
PARENT_CONTAINER="${HAL9000_PARENT:-hal9000-parent}"

# Pool settings (can be overridden via environment or arguments)
MIN_WARM_WORKERS="${MIN_WARM_WORKERS:-2}"
MAX_WARM_WORKERS="${MAX_WARM_WORKERS:-5}"
IDLE_TIMEOUT="${IDLE_TIMEOUT:-300}"  # 5 minutes
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"  # 30 seconds

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_help() {
    cat <<EOF
Usage: pool-manager.sh <command> [options]

Manage a pool of warm Claude workers for fast startup.

Commands:
  start             Start the pool manager daemon
  stop              Stop the pool manager daemon
  status            Show pool status (warm, busy, idle workers)
  scale <n>         Scale pool to n warm workers
  cleanup           Force cleanup of idle workers
  warm              Create a single warm worker
  help              Show this help

Options:
  --min-warm N      Minimum warm workers to maintain (default: $MIN_WARM_WORKERS)
  --max-warm N      Maximum warm workers allowed (default: $MAX_WARM_WORKERS)
  --idle-timeout N  Seconds before idle worker cleanup (default: $IDLE_TIMEOUT)
  --check-interval N  Seconds between pool checks (default: $CHECK_INTERVAL)

Environment Variables:
  MIN_WARM_WORKERS  Same as --min-warm
  MAX_WARM_WORKERS  Same as --max-warm
  IDLE_TIMEOUT      Same as --idle-timeout
  WORKER_IMAGE      Docker image for workers

Examples:
  pool-manager.sh start --min-warm 3
  pool-manager.sh status
  pool-manager.sh scale 5
  pool-manager.sh stop
EOF
}

parse_args() {
    COMMAND=""
    SCALE_TARGET=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            start|stop|status|cleanup|warm|help)
                COMMAND="$1"
                shift
                ;;
            scale)
                COMMAND="scale"
                SCALE_TARGET="${2:-}"
                shift 2 || shift
                ;;
            --min-warm)
                MIN_WARM_WORKERS="$2"
                shift 2
                ;;
            --max-warm)
                MAX_WARM_WORKERS="$2"
                shift 2
                ;;
            --idle-timeout)
                IDLE_TIMEOUT="$2"
                shift 2
                ;;
            --check-interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$COMMAND" ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi
}

# ============================================================================
# WORKER MANAGEMENT
# ============================================================================

init_state_dir() {
    mkdir -p "$POOL_STATE_DIR"
    mkdir -p "${POOL_STATE_DIR}/workers"
}

# Get list of warm (idle) workers
get_warm_workers() {
    docker ps --filter "name=hal9000-warm-" --filter "status=running" --format "{{.Names}}" 2>/dev/null || true
}

# Get list of busy (in-use) workers
get_busy_workers() {
    docker ps --filter "name=hal9000-worker-" --filter "status=running" --format "{{.Names}}" 2>/dev/null || true
}

# Count workers
count_warm_workers() {
    local workers
    workers=$(get_warm_workers)
    if [[ -z "$workers" ]]; then
        echo "0"
    else
        echo "$workers" | wc -l | tr -d ' '
    fi
}

count_busy_workers() {
    local workers
    workers=$(get_busy_workers)
    if [[ -z "$workers" ]]; then
        echo "0"
    else
        echo "$workers" | wc -l | tr -d ' '
    fi
}

# Create a warm worker
create_warm_worker() {
    local worker_name="hal9000-warm-$(date +%s)-$$-$RANDOM"
    local worker_state="${POOL_STATE_DIR}/workers/${worker_name}.json"

    log_info "Creating warm worker: $worker_name"

    # Create worker container in detached mode
    local container_id
    container_id=$(docker run -d \
        --name "$worker_name" \
        --network "container:${PARENT_CONTAINER}" \
        -v hal9000-chromadb:/data/chromadb \
        -v hal9000-memorybank:/data/membank \
        -v hal9000-plugins:/data/plugins \
        -w /workspace \
        "$WORKER_IMAGE" \
        bash -c "sleep infinity" 2>/dev/null) || {
        log_error "Failed to create warm worker"
        return 1
    }

    # Record worker state
    cat > "$worker_state" <<EOF
{
    "name": "$worker_name",
    "container_id": "${container_id:0:12}",
    "created_at": "$(date -Iseconds)",
    "status": "warm",
    "last_used": null
}
EOF

    log_success "Created warm worker: $worker_name (${container_id:0:12})"
    echo "$worker_name"
}

# Claim a warm worker for use
claim_warm_worker() {
    local project_dir="${1:-/workspace}"
    local new_name="${2:-hal9000-worker-$(date +%s)}"

    # Find an available warm worker
    local warm_workers
    warm_workers=$(get_warm_workers | head -1)

    if [[ -z "$warm_workers" ]]; then
        log_warn "No warm workers available"
        return 1
    fi

    local warm_name="$warm_workers"
    log_info "Claiming warm worker: $warm_name -> $new_name"

    # Rename the container
    docker rename "$warm_name" "$new_name" 2>/dev/null || {
        log_error "Failed to rename worker"
        return 1
    }

    # Update state file
    local old_state="${POOL_STATE_DIR}/workers/${warm_name}.json"
    local new_state="${POOL_STATE_DIR}/workers/${new_name}.json"

    if [[ -f "$old_state" ]]; then
        # Update the state with new name and claimed status
        cat > "$new_state" <<EOF
{
    "name": "$new_name",
    "container_id": "$(docker inspect --format '{{.Id}}' "$new_name" 2>/dev/null | cut -c1-12)",
    "created_at": "$(date -Iseconds)",
    "status": "busy",
    "claimed_at": "$(date -Iseconds)",
    "project_dir": "$project_dir"
}
EOF
        rm -f "$old_state"
    fi

    log_success "Claimed worker: $new_name"
    echo "$new_name"
}

# Remove a specific worker
remove_worker() {
    local worker_name="$1"

    log_info "Removing worker: $worker_name"

    docker stop "$worker_name" >/dev/null 2>&1 || true
    docker rm "$worker_name" >/dev/null 2>&1 || true

    rm -f "${POOL_STATE_DIR}/workers/${worker_name}.json"

    log_success "Removed worker: $worker_name"
}

# Check if worker is idle (no processes running)
is_worker_idle() {
    local worker_name="$1"
    local state_file="${POOL_STATE_DIR}/workers/${worker_name}.json"

    # Check if it's a warm worker (never been claimed)
    if [[ "$worker_name" == hal9000-warm-* ]]; then
        return 0  # Warm workers are considered idle
    fi

    # Check last activity (simplified - could check for tmux sessions)
    if docker exec "$worker_name" pgrep -x "claude" >/dev/null 2>&1; then
        return 1  # Claude is running, not idle
    fi

    return 0  # No Claude process, considered idle
}

# Get worker idle time in seconds
get_worker_idle_time() {
    local worker_name="$1"
    local state_file="${POOL_STATE_DIR}/workers/${worker_name}.json"

    if [[ ! -f "$state_file" ]]; then
        echo "0"
        return
    fi

    # For simplicity, use container start time
    local started_at
    started_at=$(docker inspect --format '{{.State.StartedAt}}' "$worker_name" 2>/dev/null) || {
        echo "0"
        return
    }

    # Convert to epoch and calculate difference
    local start_epoch
    start_epoch=$(date -d "$started_at" +%s 2>/dev/null) || start_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S" "${started_at%%.*}" +%s 2>/dev/null) || {
        echo "0"
        return
    }

    local now_epoch
    now_epoch=$(date +%s)

    echo $((now_epoch - start_epoch))
}

# ============================================================================
# POOL MAINTENANCE
# ============================================================================

maintain_pool() {
    local current_warm
    current_warm=$(count_warm_workers)

    log_info "Pool check: $current_warm warm workers (min: $MIN_WARM_WORKERS, max: $MAX_WARM_WORKERS)"

    # Scale up if below minimum
    if [[ "$current_warm" -lt "$MIN_WARM_WORKERS" ]]; then
        local to_create=$((MIN_WARM_WORKERS - current_warm))
        log_info "Scaling up: creating $to_create warm workers"

        for ((i = 0; i < to_create; i++)); do
            create_warm_worker || log_warn "Failed to create warm worker $i"
        done
    fi

    # Check for idle workers to cleanup
    cleanup_idle_workers
}

cleanup_idle_workers() {
    local current_warm
    current_warm=$(count_warm_workers)

    # Don't cleanup if at or below minimum
    if [[ "$current_warm" -le "$MIN_WARM_WORKERS" ]]; then
        return
    fi

    # Check each warm worker for idle timeout
    local workers
    workers=$(get_warm_workers)

    for worker in $workers; do
        # Keep minimum warm workers
        current_warm=$(count_warm_workers)
        if [[ "$current_warm" -le "$MIN_WARM_WORKERS" ]]; then
            break
        fi

        local idle_time
        idle_time=$(get_worker_idle_time "$worker")

        if [[ "$idle_time" -gt "$IDLE_TIMEOUT" ]]; then
            log_info "Worker $worker idle for ${idle_time}s (timeout: ${IDLE_TIMEOUT}s)"
            remove_worker "$worker"
        fi
    done

    # Also cleanup any busy workers that have been idle too long
    local busy_workers
    busy_workers=$(get_busy_workers)

    for worker in $busy_workers; do
        if is_worker_idle "$worker"; then
            local idle_time
            idle_time=$(get_worker_idle_time "$worker")

            if [[ "$idle_time" -gt "$IDLE_TIMEOUT" ]]; then
                log_info "Busy worker $worker idle for ${idle_time}s, cleaning up"
                remove_worker "$worker"
            fi
        fi
    done
}

# ============================================================================
# DAEMON MANAGEMENT
# ============================================================================

is_daemon_running() {
    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    # Stale PID file
    rm -f "$PID_FILE"
    return 1
}

start_daemon() {
    if is_daemon_running; then
        log_warn "Pool manager already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    init_state_dir

    log_info "Starting pool manager daemon..."
    log_info "  Min warm workers: $MIN_WARM_WORKERS"
    log_info "  Max warm workers: $MAX_WARM_WORKERS"
    log_info "  Idle timeout: ${IDLE_TIMEOUT}s"
    log_info "  Check interval: ${CHECK_INTERVAL}s"

    # Fork to background
    (
        echo $$ > "$PID_FILE"

        # Trap signals for graceful shutdown
        trap 'log_info "Shutting down pool manager..."; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

        # Initial pool creation
        maintain_pool

        # Main loop
        while true; do
            sleep "$CHECK_INTERVAL"
            maintain_pool
        done
    ) &

    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"

    sleep 1

    if is_daemon_running; then
        log_success "Pool manager started (PID: $daemon_pid)"
    else
        log_error "Pool manager failed to start"
        return 1
    fi
}

stop_daemon() {
    if ! is_daemon_running; then
        log_info "Pool manager not running"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    log_info "Stopping pool manager (PID: $pid)..."

    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true

    rm -f "$PID_FILE"

    log_success "Pool manager stopped"
}

show_status() {
    local warm_count busy_count total_count
    warm_count=$(count_warm_workers)
    busy_count=$(count_busy_workers)
    total_count=$((warm_count + busy_count))

    echo ""
    log_info "=========================================="
    log_info "  HAL-9000 Worker Pool Status"
    log_info "=========================================="
    echo ""

    # Daemon status
    if is_daemon_running; then
        log_success "  Pool manager: Running (PID: $(cat "$PID_FILE"))"
    else
        log_warn "  Pool manager: Not running"
    fi

    echo ""
    log_info "  Workers:"
    log_info "    Warm (ready):  $warm_count"
    log_info "    Busy (in use): $busy_count"
    log_info "    Total:         $total_count"
    echo ""
    log_info "  Configuration:"
    log_info "    Min warm: $MIN_WARM_WORKERS"
    log_info "    Max warm: $MAX_WARM_WORKERS"
    log_info "    Idle timeout: ${IDLE_TIMEOUT}s"
    echo ""

    # List warm workers
    if [[ "$warm_count" -gt 0 ]]; then
        log_info "  Warm workers:"
        local workers
        workers=$(get_warm_workers)
        for worker in $workers; do
            local idle_time
            idle_time=$(get_worker_idle_time "$worker")
            printf "    - %s (idle: %ss)\n" "$worker" "$idle_time"
        done
        echo ""
    fi

    # List busy workers
    if [[ "$busy_count" -gt 0 ]]; then
        log_info "  Busy workers:"
        local workers
        workers=$(get_busy_workers)
        for worker in $workers; do
            local idle_time
            idle_time=$(get_worker_idle_time "$worker")
            printf "    - %s (age: %ss)\n" "$worker" "$idle_time"
        done
        echo ""
    fi
}

scale_pool() {
    local target="$1"

    if [[ -z "$target" ]]; then
        log_error "Scale target not specified"
        return 1
    fi

    if [[ ! "$target" =~ ^[0-9]+$ ]]; then
        log_error "Invalid scale target: $target"
        return 1
    fi

    if [[ "$target" -gt "$MAX_WARM_WORKERS" ]]; then
        log_warn "Target $target exceeds max ($MAX_WARM_WORKERS), capping"
        target="$MAX_WARM_WORKERS"
    fi

    local current_warm
    current_warm=$(count_warm_workers)

    log_info "Scaling pool: $current_warm -> $target warm workers"

    if [[ "$target" -gt "$current_warm" ]]; then
        # Scale up
        local to_create=$((target - current_warm))
        for ((i = 0; i < to_create; i++)); do
            create_warm_worker || log_warn "Failed to create warm worker"
        done
    elif [[ "$target" -lt "$current_warm" ]]; then
        # Scale down
        local to_remove=$((current_warm - target))
        local workers
        workers=$(get_warm_workers | head -n "$to_remove")
        for worker in $workers; do
            remove_worker "$worker"
        done
    fi

    log_success "Pool scaled to $target warm workers"
}

force_cleanup() {
    log_info "Force cleanup of all idle workers..."

    # Remove all warm workers
    local workers
    workers=$(get_warm_workers)
    for worker in $workers; do
        remove_worker "$worker"
    done

    # Check busy workers for idle ones
    workers=$(get_busy_workers)
    for worker in $workers; do
        if is_worker_idle "$worker"; then
            remove_worker "$worker"
        fi
    done

    log_success "Cleanup complete"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    case "$COMMAND" in
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        status)
            show_status
            ;;
        scale)
            scale_pool "$SCALE_TARGET"
            ;;
        cleanup)
            force_cleanup
            ;;
        warm)
            init_state_dir
            create_warm_worker
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
