#!/usr/bin/env bash
# parent-entrypoint.sh - HAL-9000 Parent Container Entrypoint
#
# Responsibilities:
# 1. Verify Docker socket is accessible
# 2. Initialize state directories
# 3. Start tmux server for session management
# 4. Launch coordinator or execute passed command
#
# Startup Optimization (P6-4):
# - Parallel initialization: ChromaDB starts in background while other init runs
# - Lazy image pull: Skip if image exists or SKIP_IMAGE_PULL=true
# - Pre-warming: Pool manager runs in background after core services ready

set -euo pipefail

# Startup timing
STARTUP_START=$(date +%s%N 2>/dev/null || date +%s)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { printf "${CYAN}[parent]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[parent]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[parent]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[parent]${NC} %s\n" "$1" >&2; }

# Source audit logging library
if [[ -f "/scripts/lib/audit-log.sh" ]]; then
    source /scripts/lib/audit-log.sh
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
fi

# ============================================================================
# RESILIENCE FUNCTIONS
# ============================================================================

# retry_with_backoff: Execute command with exponential backoff
# Usage: retry_with_backoff "command" [max_retries]
# Default: 3 retries with backoff of 1s, 2s, 4s
retry_with_backoff() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local attempt=1
    local wait_time=1

    while [[ $attempt -le $max_retries ]]; do
        if eval "$cmd"; then
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            log_warn "Command failed (attempt $attempt/$max_retries), retrying in ${wait_time}s: $cmd"
            sleep "$wait_time"
            wait_time=$((wait_time * 2))
        else
            log_error "Command failed after $max_retries attempts: $cmd"
            return 1
        fi

        ((attempt++))
    done

    return 1
}

# circuit_breaker: Track failures and open circuit after threshold
# Global circuit state: CIRCUIT_BREAKER_STATE and CIRCUIT_BREAKER_FAILURES
declare -gA CIRCUIT_BREAKER_STATE
declare -gA CIRCUIT_BREAKER_FAILURES
declare -gA CIRCUIT_BREAKER_LAST_ATTEMPT

circuit_breaker() {
    local service_name="$1"
    local cmd="$2"
    local failure_threshold="${3:-5}"
    local half_open_wait="${4:-30}"

    local state="${CIRCUIT_BREAKER_STATE[$service_name]:-closed}"
    local failures="${CIRCUIT_BREAKER_FAILURES[$service_name]:-0}"
    local last_attempt="${CIRCUIT_BREAKER_LAST_ATTEMPT[$service_name]:-0}"
    local now
    now=$(date +%s)

    # OPEN: Circuit is open, reject immediately
    if [[ "$state" == "open" ]]; then
        local elapsed=$((now - last_attempt))
        if [[ $elapsed -ge $half_open_wait ]]; then
            log_warn "Circuit breaker transitioning to half-open ($service_name)"
            CIRCUIT_BREAKER_STATE[$service_name]="half-open"
            state="half-open"
        else
            log_error "Circuit breaker OPEN ($service_name) - rejecting request (wait ${half_open_wait}s)"
            return 1
        fi
    fi

    # HALF-OPEN or CLOSED: Try to execute command
    if eval "$cmd"; then
        # Success: reset failures and close circuit
        CIRCUIT_BREAKER_FAILURES[$service_name]=0
        CIRCUIT_BREAKER_STATE[$service_name]="closed"
        if [[ "$state" == "half-open" ]]; then
            log_success "Circuit breaker CLOSED ($service_name) - service recovered"
        fi
        return 0
    else
        # Failure: increment counter
        ((failures++))
        CIRCUIT_BREAKER_FAILURES[$service_name]=$failures

        if [[ $failures -ge $failure_threshold ]]; then
            log_error "Circuit breaker OPEN ($service_name) - $failures failures reached threshold ($failure_threshold)"
            CIRCUIT_BREAKER_STATE[$service_name]="open"
            CIRCUIT_BREAKER_LAST_ATTEMPT[$service_name]=$now
            return 1
        else
            log_warn "Circuit breaker failure count: $failures/$failure_threshold ($service_name)"
            return 1
        fi
    fi
}

# ============================================================================
# INITIALIZATION
# ============================================================================

init_directories() {
    log_info "Initializing directories..."

    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/sessions"
    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/logs"
    mkdir -p "${HAL9000_HOME:-/root/.hal9000}/config"

    # Coordinator state directories
    mkdir -p "${COORDINATOR_STATE_DIR:-/data/coordinator-state}"
    # SECURITY: Use 0770 instead of 0777 (restrict socket access to owner and group, not world)
    chmod 0770 "${COORDINATOR_STATE_DIR:-/data/coordinator-state}"
    # Set group ownership to hal9000 if available
    if getent group hal9000 >/dev/null 2>&1; then
        chgrp hal9000 "${COORDINATOR_STATE_DIR:-/data/coordinator-state}" 2>/dev/null || true
    fi

    # TMUX sockets directory
    mkdir -p "${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
    # SECURITY: Use 0770 instead of 0777 (restrict socket access to owner and group, not world)
    chmod 0770 "${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
    # Set group ownership to hal9000 if available
    if getent group hal9000 >/dev/null 2>&1; then
        chgrp hal9000 "${TMUX_SOCKET_DIR:-/data/tmux-sockets}" 2>/dev/null || true
    fi

    log_success "Directories initialized"
}

verify_docker_socket() {
    log_info "Verifying Docker socket..."

    if [[ ! -S /var/run/docker.sock ]]; then
        log_error "Docker socket not found at /var/run/docker.sock"
        log_error "Mount Docker socket: -v /var/run/docker.sock:/var/run/docker.sock"
        exit 1
    fi

    if ! docker ps >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon"
        log_error "Ensure Docker socket is mounted and accessible"
        exit 1
    fi

    log_success "Docker socket verified"
}

check_resource_limits() {
    log_info "Checking resource limits (Issue #10)..."

    # Check memory limit
    if [ -f /sys/fs/cgroup/memory.limit_in_bytes ]; then
        local mem_limit=$(cat /sys/fs/cgroup/memory.limit_in_bytes 2>/dev/null || echo "9223372036854775807")
        # 9223372036854775807 is the unlimited value in cgroups v1
        if [ "$mem_limit" -eq "9223372036854775807" ]; then
            log_warn "No memory limit set - recommend: --memory=2g --memory-swap=2g"
        else
            local mem_gb=$(( mem_limit / 1024 / 1024 / 1024 ))
            if [ "$mem_gb" -lt 2 ]; then
                log_warn "Memory limit is only ${mem_gb}GB - recommend 2GB minimum"
            else
                log_success "Memory limit configured: ${mem_gb}GB"
            fi
        fi
    elif [ -f /sys/fs/cgroup/memory.max ]; then
        # cgroups v2
        local mem_limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "max")
        if [ "$mem_limit" = "max" ]; then
            log_warn "No memory limit set - recommend: --memory=2g --memory-swap=2g"
        else
            local mem_gb=$(( mem_limit / 1024 / 1024 / 1024 ))
            if [ "$mem_gb" -lt 2 ]; then
                log_warn "Memory limit is only ${mem_gb}GB - recommend 2GB minimum"
            else
                log_success "Memory limit configured: ${mem_gb}GB"
            fi
        fi
    else
        log_info "Cannot determine cgroup version - skipping resource validation"
    fi

    # Check CPU limit via cpuset
    if [ -f /sys/fs/cgroup/cpuset.cpus ]; then
        local cpus=$(cat /sys/fs/cgroup/cpuset.cpus 2>/dev/null || echo "")
        if [ -n "$cpus" ]; then
            log_success "CPU affinity configured: $cpus"
        fi
    fi
}

init_tmux_server() {
    log_info "Initializing parent TMUX server..."

    local tmux_socket_dir="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
    local parent_socket="$tmux_socket_dir/parent.sock"

    # Ensure socket directory exists
    mkdir -p "$tmux_socket_dir"
    # SECURITY: Use 0770 instead of 0777 (restrict socket access to owner and group, not world)
    chmod 0770 "$tmux_socket_dir"
    # Set group ownership to hal9000 if available
    if getent group hal9000 >/dev/null 2>&1; then
        chgrp hal9000 "$tmux_socket_dir" 2>/dev/null || true
    fi

    # Kill any existing tmux server from previous runs
    tmux -S "$parent_socket" kill-server 2>/dev/null || true
    sleep 0.5

    # Start parent TMUX server with specific socket
    tmux -S "$parent_socket" new-session -d -s "hal9000-coordinator" -x 200 -y 50

    # Create coordinator window
    tmux -S "$parent_socket" new-window -t "hal9000-coordinator" -n "status"

    # Create dashboard window content
    tmux -S "$parent_socket" send-keys -t "hal9000-coordinator:status" \
        "watch -n 5 'echo \"=== HAL-9000 Parent Dashboard ===\"; echo; docker ps --filter name=hal9000-worker --format \"table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\"'" Enter

    # Export for use in coordinator
    export TMUX_SOCKET="$parent_socket"

    log_success "Parent TMUX server initialized (socket: $parent_socket)"
}

pull_worker_image() {
    local image="${WORKER_IMAGE:-ghcr.io/hellblazer/hal-9000:worker}"

    # Skip if SKIP_IMAGE_PULL is set (optimization for local dev)
    if [[ "${SKIP_IMAGE_PULL:-false}" == "true" ]]; then
        log_info "Skipping worker image pull (SKIP_IMAGE_PULL=true)"
        return 0
    fi

    log_info "Checking worker image: $image"

    if docker image inspect "$image" >/dev/null 2>&1; then
        log_success "Worker image available locally"
        return 0
    fi

    # Image not available - pull in background if LAZY_IMAGE_PULL is set
    if [[ "${LAZY_IMAGE_PULL:-false}" == "true" ]]; then
        log_info "Pulling worker image in background..."
        docker pull "$image" >> "${HAL9000_LOGS_DIR:-/root/.hal9000/logs}/image-pull.log" 2>&1 &
        log_info "Image pull started in background (check logs for status)"
        return 0
    fi

    # Synchronous pull
    log_info "Pulling worker image..."
    if docker pull "$image"; then
        log_success "Worker image pulled"
    else
        log_warn "Could not pull worker image (will try local build)"
    fi
}

# ============================================================================
# CHROMADB SERVER
# ============================================================================

# Global to track ChromaDB startup state
CHROMADB_PID=""
CHROMADB_PORT="${CHROMADB_PORT:-8000}"
CHROMADB_TOKEN_FILE="/run/secrets/chromadb_token"
CHROMADB_CERT_FILE="/run/secrets/chromadb.crt"
CHROMADB_KEY_FILE="/run/secrets/chromadb.key"
CHROMADB_TLS_ENABLED="${CHROMADB_TLS_ENABLED:-true}"

# generate_chromadb_token: Generate cryptographic token for ChromaDB authentication
# Token is written directly to file, NOT stored in environment variable
# This prevents exposure via /proc/*/environ or docker inspect
generate_chromadb_token() {
    log_info "Generating ChromaDB authentication token..."

    # Create secrets directory if it doesn't exist
    mkdir -p /run/secrets
    chmod 0700 /run/secrets

    # Generate 32-byte cryptographic random token
    # tr removes characters that could cause issues in HTTP headers
    # SECURITY: Write directly to file, not to shell variable
    if ! openssl rand -base64 32 | tr -d '/+=' | head -c 32 > "$CHROMADB_TOKEN_FILE"; then
        log_error "Failed to generate ChromaDB token"
        return 1
    fi

    # SECURITY: Restrict token file permissions (owner read-only)
    chmod 0400 "$CHROMADB_TOKEN_FILE"

    log_success "ChromaDB token generated: $CHROMADB_TOKEN_FILE"
}

# generate_chromadb_tls_cert: Generate self-signed TLS certificate for ChromaDB
# Certificate is used for internal Docker network encryption only
# Workers trust this certificate via SSL_CERT_FILE environment variable
generate_chromadb_tls_cert() {
    if [[ "$CHROMADB_TLS_ENABLED" != "true" ]]; then
        log_info "ChromaDB TLS disabled (CHROMADB_TLS_ENABLED=false)"
        return 0
    fi

    # Skip if certificate already exists and is valid
    if [[ -f "$CHROMADB_CERT_FILE" && -f "$CHROMADB_KEY_FILE" ]]; then
        # Check if certificate is still valid (not expired)
        if openssl x509 -checkend 86400 -noout -in "$CHROMADB_CERT_FILE" 2>/dev/null; then
            log_info "ChromaDB TLS certificate exists and is valid"
            return 0
        else
            log_warn "ChromaDB TLS certificate expired or invalid, regenerating..."
        fi
    fi

    log_info "Generating ChromaDB self-signed TLS certificate..."

    # Create secrets directory if it doesn't exist
    mkdir -p /run/secrets
    chmod 0700 /run/secrets

    # Get container hostname for certificate CN
    local hostname="${HOSTNAME:-chromadb}"
    local parent_name="${HAL9000_PARENT:-hal9000-parent}"

    # Generate self-signed certificate with multiple SANs for flexible connectivity
    # - CN: chromadb (service name)
    # - SAN: localhost, chromadb, parent container name, hal9000-parent
    # This allows workers to connect via any of these names
    if ! openssl req -x509 -newkey rsa:2048 \
        -keyout "$CHROMADB_KEY_FILE" \
        -out "$CHROMADB_CERT_FILE" \
        -days 365 -nodes \
        -subj "/CN=chromadb" \
        -addext "subjectAltName=DNS:localhost,DNS:chromadb,DNS:${parent_name},DNS:hal9000-parent,IP:127.0.0.1" \
        2>/dev/null; then
        log_error "Failed to generate ChromaDB TLS certificate"
        return 1
    fi

    # SECURITY: Restrict certificate and key file permissions
    chmod 0400 "$CHROMADB_KEY_FILE"
    chmod 0444 "$CHROMADB_CERT_FILE"  # Certificate can be readable (public)

    log_success "ChromaDB TLS certificate generated:"
    log_info "  Certificate: $CHROMADB_CERT_FILE"
    log_info "  Private Key: $CHROMADB_KEY_FILE"
    log_info "  Valid for: 365 days"
    log_info "  SANs: localhost, chromadb, ${parent_name}, hal9000-parent"
}

start_chromadb_server_async() {
    log_info "Starting ChromaDB server (async)..."

    local host="${CHROMADB_HOST:-0.0.0.0}"
    local data_dir="${CHROMADB_DATA_DIR:-/data/chromadb}"

    # Ensure data directory exists with retry
    retry_with_backoff "mkdir -p '$data_dir'" 2 || {
        log_error "Failed to create ChromaDB data directory"
        return 1
    }

    # Generate authentication token (written directly to file)
    generate_chromadb_token || {
        log_error "Failed to generate ChromaDB authentication token"
        return 1
    }

    # Generate TLS certificate for encrypted connections
    generate_chromadb_tls_cert || {
        log_error "Failed to generate ChromaDB TLS certificate"
        return 1
    }

    # SECURITY: Configure ChromaDB with token authentication
    # Token is read from file at server startup, not passed via environment
    # This prevents token leakage via docker inspect or /proc/*/environ
    export CHROMA_SERVER_AUTHN_PROVIDER="chromadb.auth.token_authn.TokenAuthenticationServerProvider"
    export CHROMA_SERVER_AUTHN_CREDENTIALS_FILE="$CHROMADB_TOKEN_FILE"

    # SECURITY: Configure ChromaDB with TLS encryption
    # This encrypts all traffic between workers and ChromaDB server
    if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
        export CHROMA_SERVER_SSL_ENABLED="true"
        export CHROMA_SERVER_SSL_CERTFILE="$CHROMADB_CERT_FILE"
        export CHROMA_SERVER_SSL_KEYFILE="$CHROMADB_KEY_FILE"
        log_info "ChromaDB TLS enabled: all traffic will be encrypted"
    fi

    # Start ChromaDB server in background (non-blocking)
    chroma run \
        --host "$host" \
        --port "$CHROMADB_PORT" \
        --path "$data_dir" \
        >> "${HAL9000_LOGS_DIR:-/root/.hal9000/logs}/chromadb.log" 2>&1 &

    CHROMADB_PID=$!
    echo "$CHROMADB_PID" > "${HAL9000_HOME}/chromadb.pid"

    local tls_status="HTTP"
    if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
        tls_status="HTTPS (TLS)"
    fi
    log_info "ChromaDB starting in background (PID: $CHROMADB_PID) with token auth + $tls_status"

    # Audit log ChromaDB start
    if command -v audit_chromadb_start >/dev/null 2>&1; then
        audit_chromadb_start "$CHROMADB_PORT" "$data_dir"
    fi

    # Security audit: log ChromaDB startup with security configuration
    if command -v log_security_event >/dev/null 2>&1; then
        local tls_status="disabled"
        [[ "$CHROMADB_TLS_ENABLED" == "true" ]] && tls_status="enabled"
        log_security_event "CHROMADB_START" "port=${CHROMADB_PORT} data_dir=${data_dir} auth=token tls=${tls_status}" "INFO"
    fi
}

wait_for_chromadb() {
    local max_wait="${1:-30}"
    local waited=0

    log_info "Waiting for ChromaDB to be ready..."

    # Determine protocol based on TLS setting
    local protocol="http"
    local curl_tls_opts=""
    if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
        protocol="https"
        # Use the self-signed certificate for verification
        curl_tls_opts="--cacert $CHROMADB_CERT_FILE"
    fi

    while [[ $waited -lt $max_wait ]]; do
        # Use circuit breaker to prevent cascade of health checks if service is failing
        # Health check with authentication header and TLS certificate
        if circuit_breaker "chromadb-health" \
            "curl -s -m 5 $curl_tls_opts -H \"Authorization: Bearer \$(cat $CHROMADB_TOKEN_FILE 2>/dev/null || echo '')\" '${protocol}://localhost:${CHROMADB_PORT}/api/v2/heartbeat' >/dev/null 2>&1" \
            5 10; then
            local tls_status=""
            if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
                tls_status=" + TLS"
            fi
            log_success "ChromaDB ready on port $CHROMADB_PORT with authentication${tls_status} (waited: ${waited}s)"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    log_error "ChromaDB failed to start within ${max_wait}s"
    return 1
}

start_chromadb_server() {
    # Legacy synchronous start (for compatibility)
    start_chromadb_server_async
    wait_for_chromadb 30
}

stop_chromadb_server() {
    local pid_file="${HAL9000_HOME}/chromadb.pid"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping ChromaDB server (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true

            # Audit log ChromaDB stop
            if command -v audit_chromadb_stop >/dev/null 2>&1; then
                audit_chromadb_stop "$pid" "$?"
            fi
        fi
        rm -f "$pid_file"
    fi
}

# ============================================================================
# COORDINATOR MODE
# ============================================================================

run_coordinator() {
    log_info "Starting coordinator mode..."

    # Write PID file
    echo $$ > "${HAL9000_HOME}/coordinator.pid"

    # Trap signals for graceful shutdown
    trap cleanup_on_exit SIGTERM SIGINT

    log_success "Coordinator running (PID: $$)"
    log_info "Monitoring workers and maintaining session state..."

    # Audit log coordinator start
    if command -v audit_coordinator_start >/dev/null 2>&1; then
        audit_coordinator_start "hal9000-parent"
    fi

    # Security audit: log coordinator start with security context
    if command -v log_security_event >/dev/null 2>&1; then
        log_security_event "COORDINATOR_START" "pid=$$ chromadb_port=${CHROMADB_PORT}" "INFO"
    fi

    # Source coordinator functions if available
    if [[ -f "/scripts/coordinator.sh" ]]; then
        source /scripts/coordinator.sh
    fi

    # Coordination loop
    local check_interval=5
    local registry_update_interval=30
    local last_registry_update=0

    while true; do
        local now
        now=$(date +%s)

        # Periodic worker registry update
        if [[ $((now - last_registry_update)) -ge $registry_update_interval ]]; then
            if command -v update_worker_registry >/dev/null 2>&1; then
                update_worker_registry
                last_registry_update=$now
            fi

            # Validate sessions (clean up stale TMUX sockets)
            if command -v validate_worker_sessions >/dev/null 2>&1; then
                validate_worker_sessions
            fi
        fi

        # Brief health check
        local worker_count
        worker_count=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" | wc -l)
        if [[ $((now % 60)) -eq 0 ]]; then
            log_info "Coordinator health check: $worker_count active workers"
        fi

        sleep "$check_interval"
    done
}

cleanup_on_exit() {
    local exit_code=$?
    log_warn "Shutting down coordinator (exit code: $exit_code)..."

    # Audit log coordinator stop
    if command -v audit_coordinator_stop >/dev/null 2>&1; then
        audit_coordinator_stop "hal9000-parent" "$exit_code"
    fi

    # Security audit: log coordinator stop
    if command -v log_security_event >/dev/null 2>&1; then
        log_security_event "COORDINATOR_STOP" "exit_code=${exit_code}" "INFO"
    fi

    # List and optionally stop workers
    local workers
    workers=$(docker ps --filter "name=hal9000-worker" --format "{{.Names}}" || true)

    if [[ -n "$workers" ]]; then
        log_warn "Active workers that will be orphaned:"
        echo "$workers" | while read -r worker; do
            log_warn "  - $worker"
        done
        # Note: We don't forcefully stop workers - they continue running
        # Use --rm flag when spawning workers for auto-cleanup
    fi

    # Stop ChromaDB server with retry
    if retry_with_backoff "stop_chromadb_server" 2; then
        log_success "ChromaDB server stopped"
    else
        log_warn "Failed to gracefully stop ChromaDB, forcing shutdown"
        if [[ -n "$CHROMADB_PID" ]] && kill -0 "$CHROMADB_PID" 2>/dev/null; then
            kill -9 "$CHROMADB_PID" 2>/dev/null || true
        fi
    fi

    # Stop pool manager if running
    if [[ -f "${HAL9000_HOME}/pool/pool-manager.pid" ]]; then
        local pool_pid
        pool_pid=$(cat "${HAL9000_HOME}/pool/pool-manager.pid")
        if kill -0 "$pool_pid" 2>/dev/null; then
            log_info "Stopping pool manager (PID: $pool_pid)..."
            kill "$pool_pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pool_pid" 2>/dev/null || true
        fi
        rm -f "${HAL9000_HOME}/pool/pool-manager.pid"
    fi

    # Clean up parent TMUX server
    if [[ -n "${TMUX_SOCKET:-}" ]]; then
        log_info "Cleaning up parent TMUX server..."
        if [[ -S "$TMUX_SOCKET" ]]; then
            tmux -S "$TMUX_SOCKET" kill-server 2>/dev/null || true
            sleep 1
        fi
    fi

    # Clean up temporary coordinator state
    if [[ -d "${COORDINATOR_STATE_DIR:-/data/coordinator-state}" ]]; then
        # Only clean up stale registries, not active worker data
        find "${COORDINATOR_STATE_DIR:-/data/coordinator-state}" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    fi

    # Remove PID file
    rm -f "${HAL9000_HOME}/coordinator.pid"

    log_info "Coordinator stopped"
    exit "$exit_code"
}

# ============================================================================
# POOL MANAGER
# ============================================================================

start_pool_manager() {
    if [[ "${ENABLE_POOL_MANAGER:-false}" != "true" ]]; then
        log_info "Pool manager disabled (set ENABLE_POOL_MANAGER=true to enable)"
        return 0
    fi

    log_info "Starting pool manager..."

    local pool_script="/scripts/pool-manager.sh"
    if [[ ! -x "$pool_script" ]]; then
        log_warn "Pool manager script not found: $pool_script"
        return 0
    fi

    "$pool_script" start \
        --min-warm "${MIN_WARM_WORKERS:-2}" \
        --max-warm "${MAX_WARM_WORKERS:-5}" \
        --idle-timeout "${IDLE_TIMEOUT:-300}" || {
        log_warn "Pool manager failed to start"
        return 0
    }

    log_success "Pool manager started"
}

# ============================================================================
# STARTUP TIMING
# ============================================================================

log_startup_time() {
    local phase="$1"
    local now
    now=$(date +%s%N 2>/dev/null || date +%s)

    # Calculate elapsed time
    local elapsed_ns=$((now - STARTUP_START))
    local elapsed_ms=$((elapsed_ns / 1000000))

    log_info "Startup timing: $phase completed in ${elapsed_ms}ms"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "HAL-9000 Parent Container starting..."

    # Setup signal handlers for graceful shutdown
    trap cleanup_on_exit SIGTERM SIGINT EXIT

    # Phase 1: Critical initialization (must be synchronous)
    init_directories
    verify_docker_socket
    check_resource_limits
    log_startup_time "Phase 1 (critical init)"

    # Phase 2: Parallel service startup
    # Start ChromaDB in background immediately (async)
    start_chromadb_server_async

    # While ChromaDB is starting, do other initialization in parallel
    init_tmux_server
    pull_worker_image
    log_startup_time "Phase 2 (parallel init)"

    # Phase 3: Wait for async services
    wait_for_chromadb 30
    log_startup_time "Phase 3 (service ready)"

    # Phase 4: Background services (non-blocking)
    start_pool_manager
    log_startup_time "Phase 4 (complete)"

    # Log total startup time
    local now
    now=$(date +%s%N 2>/dev/null || date +%s)
    local total_ms=$(( (now - STARTUP_START) / 1000000 ))
    log_success "Parent container ready in ${total_ms}ms"

    # Handle command
    case "${1:-coordinator}" in
        coordinator)
            run_coordinator
            ;;
        bash|sh)
            exec "$@"
            ;;
        *)
            # Execute passed command
            exec "$@"
            ;;
    esac
}

main "$@"
