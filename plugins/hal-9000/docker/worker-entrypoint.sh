#!/usr/bin/env bash
# worker-entrypoint.sh - HAL-9000 Worker Container Entrypoint
#
# Responsibilities:
# 1. Initialize CLAUDE_HOME (shared volume for marketplace)
# 2. Configure foundation MCP servers (chromadb, memory-bank, sequential-thinking)
# 3. Set up workspace
# 4. Launch Claude or passed command
#
# Environment Variables:
#   CLAUDE_HOME       - Claude config directory (default: /home/claude/.claude)
#   WORKSPACE         - Working directory (default: /workspace)
#   MEMORY_BANK_ROOT  - Memory bank data (default: /data/memory-bank)
#   CHROMADB_HOST     - ChromaDB server host (default: localhost)
#   CHROMADB_PORT     - ChromaDB server port (default: 8000)
#   WORKER_NAME       - Name of this worker (for logging)
#
# Secret Files (SECURITY: preferred over environment variables):
#   /run/secrets/anthropic_key     - Anthropic API key (mounted read-only)
#   /run/secrets/chromadb_api_key  - ChromaDB API key (mounted read-only)
#   /run/secrets/chromadb_token    - ChromaDB auth token (mounted read-only)
#
# SECURITY NOTE: API keys should be passed via secret files, NOT environment variables.
# Environment variables are visible via 'docker inspect' and /proc/1/environ.
# Secret files mounted read-only are much more secure.

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# HIGH-1: Sanitize values for safe console logging
# Removes ANSI escape sequences and control characters to prevent log injection
# Usage: sanitized=$(sanitize_for_console "$value")
sanitize_for_console() {
    local value="$1"
    # Remove ANSI escape sequences (color codes, cursor movement, etc.)
    value=$(printf '%s' "$value" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')
    # Remove control characters (0x00-0x1F and 0x7F)
    value=$(printf '%s' "$value" | tr -d '\000-\037\177')
    printf '%s' "$value"
}

WORKER_NAME="${WORKER_NAME:-worker-$$}"
# HIGH-1: Sanitize WORKER_NAME to prevent log injection attacks
# WORKER_NAME is used in log prefixes and could contain malicious ANSI sequences
WORKER_NAME=$(sanitize_for_console "$WORKER_NAME")

# WORKER_ID is used for identification/logging (passed from spawn-worker.sh)
# Defaults to WORKER_NAME if not set
WORKER_ID="${WORKER_ID:-${WORKER_NAME}}"
# HIGH-1: Sanitize WORKER_ID as well (used in audit logging)
WORKER_ID=$(sanitize_for_console "$WORKER_ID")

log_info() { printf "${CYAN}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[${WORKER_NAME}]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[${WORKER_NAME}]${NC} %s\n" "$1" >&2; }

# HIGH-4: Hash a secret for safe logging (shows first 16 chars of SHA256)
# Usage: log_info "API key fingerprint: $(hash_for_log "$SECRET")"
# This prevents exposing actual secret values while still allowing correlation
hash_for_log() {
    local secret="$1"
    if [[ -z "$secret" ]]; then
        echo "empty"
        return
    fi
    # Use printf to avoid newline issues, sha256sum for hashing
    # cut -c1-16 provides 64 bits of entropy - sufficient for log correlation
    printf '%s' "$secret" | sha256sum 2>/dev/null | cut -c1-16 || \
    printf '%s' "$secret" | shasum -a 256 2>/dev/null | cut -c1-16 || \
    echo "hash_error"
}

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
# CONFIGURATION
# ============================================================================

CLAUDE_HOME="${CLAUDE_HOME:-/home/claude/.claude}"
WORKSPACE="${WORKSPACE:-/workspace}"
MEMORY_BANK_ROOT="${MEMORY_BANK_ROOT:-/data/memory-bank}"

# MEDIUM-9: Retry DNS resolution for hostname resolution
# Resolves hostname with retry logic for transient DNS failures
# Configurable via DNS_RETRY_COUNT (default: 5) and DNS_RETRY_DELAY (default: 2)
resolve_hostname_with_retry() {
    local hostname="$1"
    local max_retries="${DNS_RETRY_COUNT:-5}"
    local retry_delay="${DNS_RETRY_DELAY:-2}"
    local attempt=1

    log_info "Resolving hostname: $hostname (max retries: $max_retries, delay: ${retry_delay}s)"

    while [[ $attempt -le $max_retries ]]; do
        # Try to resolve the hostname using getent (most reliable on Linux)
        if getent hosts "$hostname" >/dev/null 2>&1; then
            log_info "Resolved $hostname (attempt $attempt)"
            return 0
        fi

        # Fallback to nslookup if available
        if command -v nslookup >/dev/null 2>&1 && nslookup "$hostname" >/dev/null 2>&1; then
            log_info "Resolved $hostname via nslookup (attempt $attempt)"
            return 0
        fi

        # Fallback to host command if available
        if command -v host >/dev/null 2>&1 && host "$hostname" >/dev/null 2>&1; then
            log_info "Resolved $hostname via host (attempt $attempt)"
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            log_warn "DNS resolution failed for $hostname (attempt $attempt/$max_retries), retrying in ${retry_delay}s..."
            sleep "$retry_delay"
        fi
        ((attempt++))
    done

    log_error "Failed to resolve $hostname after $max_retries attempts"
    return 1
}

# MEDIUM-6: Read and validate token file contents
# Ensures token files are not empty or whitespace-only
# Usage: token=$(read_token_file "/path/to/token" "token_name") || handle_error
read_token_file() {
    local file="$1"
    local name="${2:-token}"

    if [[ ! -f "$file" ]]; then
        log_error "Token file not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "Token file not readable: $file"
        return 1
    fi

    local token
    token=$(cat "$file" 2>/dev/null) || {
        log_error "Failed to read token file: $file"
        return 1
    }

    # Check for empty or whitespace-only content
    if [[ -z "${token// /}" ]]; then
        log_error "Token file '$name' is empty or contains only whitespace: $file"
        return 1
    fi

    # Validate token doesn't contain newlines (common file corruption)
    if [[ "$token" == *$'\n'* ]]; then
        log_warn "Token file '$name' contains newlines - using first line only"
        token="${token%%$'\n'*}"
    fi

    printf '%s' "$token"
    return 0
}

# MEDIUM-2: Validate config values read from files
# Prevents injection attacks through maliciously crafted config files
# Usage: validate_config_value "tenant_name" "$value" "^[a-zA-Z0-9_-]+$"
validate_config_value() {
    local name="$1"
    local value="$2"
    local pattern="${3:-^[a-zA-Z0-9_.-]+$}"  # Default: alphanumeric + common safe chars
    local max_length="${4:-256}"              # Default max length

    if [[ -z "$value" ]]; then
        log_error "Config value '$name' is empty"
        return 1
    fi

    if [[ ${#value} -gt $max_length ]]; then
        log_error "Config value '$name' exceeds maximum length ($max_length chars)"
        return 1
    fi

    if ! [[ "$value" =~ $pattern ]]; then
        log_error "Config value '$name' contains invalid characters (pattern: $pattern)"
        return 1
    fi

    return 0
}

# ChromaDB configuration with DNS-based service discovery
# Prefer PARENT_HOSTNAME (container name) for Docker DNS resolution - more resilient than IP
# Falls back to PARENT_IP for backward compatibility
# Finally falls back to explicit CHROMADB_HOST or localhost
CHROMADB_HOST="${CHROMADB_HOST:-}"
if [[ -z "$CHROMADB_HOST" ]]; then
    if [[ -n "${PARENT_HOSTNAME:-}" ]]; then
        # Use parent container name - Docker DNS resolves to current IP
        # More resilient: survives parent container restart with new IP
        # Validate DNS resolution with retry logic
        if resolve_hostname_with_retry "${PARENT_HOSTNAME}" 3; then
            CHROMADB_HOST="${PARENT_HOSTNAME}"
        elif [[ -n "${PARENT_IP:-}" ]]; then
            log_warn "DNS resolution failed, falling back to PARENT_IP: ${PARENT_IP}"
            CHROMADB_HOST="${PARENT_IP}"
        else
            log_warn "DNS resolution failed and no PARENT_IP fallback, using localhost"
            CHROMADB_HOST="localhost"
        fi
    elif [[ -n "${PARENT_IP:-}" ]]; then
        # Fallback to IP for backward compatibility (less resilient)
        CHROMADB_HOST="${PARENT_IP}"
    else
        # Default to localhost (for standalone worker or local development)
        CHROMADB_HOST="localhost"
    fi
fi
CHROMADB_PORT="${CHROMADB_PORT:-8000}"

# ChromaDB is SHARED across all workers (intentional architectural decision)
# This enables cross-worker knowledge sharing and collaborative search
# Only set CHROMA_TENANT if explicitly configured (e.g., for cloud deployments)
CHROMA_TENANT="${CHROMA_TENANT:-}"
CHROMA_DATABASE="${CHROMA_DATABASE:-default}"

# MEDIUM-2: Validate ChromaDB configuration values to prevent injection
if [[ -n "$CHROMA_TENANT" ]]; then
    if ! validate_config_value "CHROMA_TENANT" "$CHROMA_TENANT" "^[a-zA-Z0-9_-]+$" 64; then
        log_error "Invalid CHROMA_TENANT value - must be alphanumeric with underscores/dashes, max 64 chars"
        exit 1
    fi
fi

if ! validate_config_value "CHROMA_DATABASE" "$CHROMA_DATABASE" "^[a-zA-Z0-9_-]+$" 64; then
    log_error "Invalid CHROMA_DATABASE value - must be alphanumeric with underscores/dashes, max 64 chars"
    exit 1
fi

# ChromaDB authentication token file (mounted read-only from parent)
CHROMADB_TOKEN_FILE="/run/secrets/chromadb_token"

# ChromaDB TLS configuration
# Certificate is generated by parent and mounted read-only for encrypted connections
CHROMADB_CERT_FILE="/run/secrets/chromadb.crt"
CHROMADB_TLS_ENABLED="${CHROMADB_TLS_ENABLED:-false}"

# MEDIUM-1: Certificate pinning validation
# Validates certificate fingerprint if CHROMADB_CERT_FINGERPRINT is set
validate_certificate() {
    local cert_file="$1"
    local expected_fingerprint="${CHROMADB_CERT_FINGERPRINT:-}"

    if [[ -n "$expected_fingerprint" ]]; then
        if ! command -v openssl >/dev/null 2>&1; then
            log_error "openssl required for certificate pinning validation"
            return 1
        fi
        local actual
        actual=$(openssl x509 -noout -fingerprint -sha256 -in "$cert_file" 2>/dev/null | cut -d= -f2)
        if [[ "$actual" != "$expected_fingerprint" ]]; then
            log_error "Certificate fingerprint mismatch!"
            log_error "Expected: $expected_fingerprint"
            log_error "Actual: $actual"
            return 1
        fi
        log_success "Certificate fingerprint validated"
    fi
    return 0
}

# MEDIUM-8: Graceful TLS fallback with warning
# If TLS is enabled but certificate not found, fall back to HTTP with warning
CHROMADB_PROTOCOL="http"
if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
    if [[ -f "$CHROMADB_CERT_FILE" ]]; then
        # Validate certificate fingerprint if pinning is configured
        if validate_certificate "$CHROMADB_CERT_FILE"; then
            CHROMADB_PROTOCOL="https"
            # Configure SSL certificate for Python requests library (used by chroma-mcp)
            export SSL_CERT_FILE="$CHROMADB_CERT_FILE"
            export REQUESTS_CA_BUNDLE="$CHROMADB_CERT_FILE"
        else
            log_warn "Certificate validation failed, falling back to HTTP"
            CHROMADB_TLS_ENABLED="false"
        fi
    else
        log_warn "TLS enabled but certificate not found at $CHROMADB_CERT_FILE, falling back to HTTP"
        CHROMADB_TLS_ENABLED="false"
    fi
fi

# ============================================================================
# INITIALIZATION
# ============================================================================

init_claude_home() {
    log_info "Initializing Claude home: $CLAUDE_HOME"

    # Ensure Claude home structure exists
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$MEMORY_BANK_ROOT"

    # UPGRADE MIGRATION (Issue #8): UID changed from 1000 to 1001
    # For existing volumes created by old image (UID 1000), fix ownership
    if [[ -d "$CLAUDE_HOME" ]] && [[ $(find "$CLAUDE_HOME" -uid 1000 -print -quit 2>/dev/null) ]]; then
        log_info "Migrating volume ownership from UID 1000 to UID 1001 (claude:claude)..."
        find "$CLAUDE_HOME" -uid 1000 -exec chown claude:claude {} + 2>/dev/null || true
        log_success "Volume ownership migrated - credentials and plugins now accessible"
    fi

    # SECURITY: Export secret file PATH, not content
    # This prevents secrets from appearing in process environment (visible via docker inspect, /proc/1/environ)
    # The secret will be read only at exec time by run_claude_with_secret()
    if [[ -f /run/secrets/anthropic_key ]]; then
        export ANTHROPIC_API_KEY_FILE="/run/secrets/anthropic_key"
        log_success "ANTHROPIC_API_KEY_FILE configured (secret NOT in environment)"
    fi

    # SECURITY: Fail if API key is passed via environment variable
    # Environment variables are visible via 'docker inspect' and /proc/1/environ
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_error "SECURITY VIOLATION: ANTHROPIC_API_KEY environment variable detected"
        log_error "API keys in environment variables are visible via 'docker inspect' and /proc/1/environ"
        log_error ""
        log_error "To fix, use file-based secrets instead:"
        log_error "  1. Store your key: echo 'your-key' > ~/.hal9000/secrets/anthropic_key"
        log_error "  2. Set permissions: chmod 400 ~/.hal9000/secrets/anthropic_key"
        log_error "  3. Remove env var: unset ANTHROPIC_API_KEY"
        log_error "  4. Update your shell profile to not set this variable"
        exit 1
    fi

    # SECURITY: Export ChromaDB secret file PATH if available
    if [[ -f /run/secrets/chromadb_api_key ]]; then
        export CHROMADB_API_KEY_FILE="/run/secrets/chromadb_api_key"
        log_success "CHROMADB_API_KEY_FILE configured (secret NOT in environment)"
    fi

    # SECURITY: Fail if ChromaDB API key is passed via environment variable
    if [[ -n "${CHROMADB_API_KEY:-}" ]]; then
        log_error "SECURITY VIOLATION: CHROMADB_API_KEY environment variable detected"
        log_error "API keys in environment variables are visible via 'docker inspect'"
        log_error ""
        log_error "To fix, use file-based secrets instead:"
        log_error "  1. Store your key: echo 'your-key' > ~/.hal9000/secrets/chromadb_api_key"
        log_error "  2. Set permissions: chmod 400 ~/.hal9000/secrets/chromadb_api_key"
        log_error "  3. Remove env var: unset CHROMADB_API_KEY"
        exit 1
    fi

    # Check for authentication
    if [[ -f "$CLAUDE_HOME/.credentials.json" ]]; then
        log_success "Authentication credentials found"
    elif [[ -f "${ANTHROPIC_API_KEY_FILE:-}" ]]; then
        log_success "Using API key from secret file for authentication"
    else
        log_warn "No authentication found - Claude may prompt for login"
    fi
}

setup_foundation_mcp() {
    log_info "Configuring foundation MCP servers..."

    local settings_file="$CLAUDE_HOME/settings.json"

    # If settings.json exists, merge our foundation servers
    # Otherwise create fresh config
    if [[ -f "$settings_file" ]]; then
        log_info "Existing settings.json found - preserving marketplace installs"
        # Check if our foundation servers are already configured
        if grep -q '"memory-bank"' "$settings_file" 2>/dev/null; then
            log_info "Foundation MCP servers already configured"
            return 0
        fi
        # TODO: merge foundation servers into existing config
        # For now, we'll leave existing config alone
        log_warn "Adding foundation servers to existing config not yet implemented"
        return 0
    fi

    # NOTE: ChromaDB is SHARED across all workers (intentional architectural decision)
    # This enables cross-worker knowledge sharing and collaborative search
    log_info "ChromaDB: shared mode (cross-worker knowledge sharing)"

    # Check for ChromaDB authentication token
    local chromadb_auth_env=""
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        # SECURITY: Configure chroma-mcp client to use token authentication
        # The token file path is passed via environment variable
        # chroma-mcp reads the token from file at startup (not stored in settings.json)
        chromadb_auth_env=',
        "CHROMA_CLIENT_AUTH_PROVIDER": "chromadb.auth.token_authn.TokenAuthClientProvider",
        "CHROMA_CLIENT_AUTH_CREDENTIALS_FILE": "'$CHROMADB_TOKEN_FILE'"'
        log_info "ChromaDB authentication configured via token file"
    else
        log_warn "ChromaDB token not found - client will connect without authentication"
    fi

    # Check for ChromaDB TLS certificate
    local chromadb_tls_env=""
    if [[ "$CHROMADB_TLS_ENABLED" == "true" && -f "$CHROMADB_CERT_FILE" ]]; then
        # SECURITY: Configure chroma-mcp client to use TLS with self-signed certificate
        # Certificate is mounted from parent container
        chromadb_tls_env=',
        "SSL_CERT_FILE": "'$CHROMADB_CERT_FILE'",
        "REQUESTS_CA_BUNDLE": "'$CHROMADB_CERT_FILE'"'
        log_info "ChromaDB TLS enabled with certificate: $CHROMADB_CERT_FILE"
    fi

    # Create settings.json with foundation MCP servers
    cat > "$settings_file" <<EOF
{
  "theme": "dark",
  "preferredNotificationChannel": "terminal",
  "verbose": false,
  "mcpServers": {
    "memory-bank": {
      "command": "mcp-server-memory-bank",
      "args": [],
      "env": {
        "MEMORY_BANK_ROOT": "${MEMORY_BANK_ROOT}"
      }
    },
    "sequential-thinking": {
      "command": "mcp-server-sequential-thinking",
      "args": []
    },
    "chromadb": {
      "command": "chroma-mcp",
      "args": [
        "--client-type", "http",
        "--host", "${CHROMADB_HOST}",
        "--port", "${CHROMADB_PORT}",
        "--ssl", "${CHROMADB_TLS_ENABLED}"
      ],
      "env": {
        "CHROMA_ANONYMIZED_TELEMETRY": "false"${chromadb_auth_env}${chromadb_tls_env}
      }
    }
  }
}
EOF

    log_success "Foundation MCP servers configured:"
    log_info "  - memory-bank: ${MEMORY_BANK_ROOT}"

    # Log ChromaDB configuration with network mode info
    local auth_status="without auth"
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        auth_status="with token auth"
    fi

    local tls_status=""
    if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
        tls_status=" + TLS"
    fi

    if [[ -n "${PARENT_HOSTNAME:-}" ]]; then
        log_info "  - chromadb: ${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT} (${auth_status}${tls_status}, shared, DNS via PARENT_HOSTNAME: ${PARENT_HOSTNAME})"
    elif [[ -n "${PARENT_IP:-}" ]]; then
        log_info "  - chromadb: ${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT} (${auth_status}${tls_status}, shared, fallback IP via PARENT_IP)"
    else
        log_info "  - chromadb: ${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT} (${auth_status}${tls_status}, shared)"
    fi

    log_info "  - sequential-thinking: enabled"
}

setup_workspace() {
    log_info "Setting up workspace: $WORKSPACE"

    if [[ ! -d "$WORKSPACE" ]]; then
        mkdir -p "$WORKSPACE"
    fi

    cd "$WORKSPACE"

    # Configure git safe directory if repo detected
    if [[ -d ".git" ]]; then
        log_info "Git repository detected"
        git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true
    fi
}

verify_claude() {
    log_info "Verifying Claude CLI..."

    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI not found in PATH"
        log_error "PATH: $PATH"
        exit 1
    fi

    local version
    version=$(claude --version 2>/dev/null || echo "unknown")
    log_success "Claude CLI version: $version"
}

verify_chromadb_connectivity() {
    log_info "Verifying ChromaDB connectivity..."
    log_info "ChromaDB mode: shared (cross-worker knowledge sharing)"

    # Check for authentication token
    local auth_available=false
    if [[ -f "$CHROMADB_TOKEN_FILE" ]]; then
        auth_available=true
        log_info "ChromaDB auth token available: $CHROMADB_TOKEN_FILE"
    else
        log_warn "ChromaDB auth token not found - authentication will fail"
    fi

    # Check for TLS certificate
    local tls_available=false
    local curl_tls_opts=""
    if [[ "$CHROMADB_TLS_ENABLED" == "true" && -f "$CHROMADB_CERT_FILE" ]]; then
        tls_available=true
        # Use the self-signed certificate for verification
        curl_tls_opts="--cacert $CHROMADB_CERT_FILE"
        log_info "ChromaDB TLS certificate available: $CHROMADB_CERT_FILE"
    fi

    # Use circuit breaker pattern to prevent cascading failures
    # ChromaDB health check with retry, authentication, and TLS
    local curl_cmd="curl -s -m 5 $curl_tls_opts"
    if [[ "$auth_available" == "true" ]]; then
        # SECURITY: Read token at execution time, not stored in variable
        curl_cmd="curl -s -m 5 $curl_tls_opts -H \"Authorization: Bearer \$(cat $CHROMADB_TOKEN_FILE)\""
    fi

    if retry_with_backoff \
        "$curl_cmd '${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT}/api/v2/heartbeat' >/dev/null 2>&1" \
        3; then
        local status_parts=()
        if [[ "$auth_available" == "true" ]]; then
            status_parts+=("token auth")
        else
            status_parts+=("no auth")
        fi
        if [[ "$tls_available" == "true" ]]; then
            status_parts+=("TLS")
        fi
        local status_str
        status_str=$(IFS='+'; echo "${status_parts[*]}")
        log_success "ChromaDB connectivity verified (${status_str}): ${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT} (shared)"
        return 0
    fi

    # ChromaDB not responding - log warning but don't fail
    # (ChromaDB may start later, chroma-mcp has its own reconnection logic)
    log_warn "ChromaDB not responding after retries"
    log_warn "ChromaDB configuration: protocol=${CHROMADB_PROTOCOL}, host=${CHROMADB_HOST}, port=${CHROMADB_PORT}"
    if [[ "$auth_available" != "true" ]]; then
        log_warn "Authentication token missing - this may be causing connection failures"
    fi
    if [[ "$CHROMADB_TLS_ENABLED" == "true" && "$tls_available" != "true" ]]; then
        log_warn "TLS enabled but certificate missing - this may be causing connection failures"
    fi
    log_info "Note: chroma-mcp client will retry automatically when Claude uses ChromaDB"
    return 1  # Warning, not fatal
}

verify_mcp_servers() {
    log_info "Verifying foundation MCP servers..."

    local all_ok=true

    if command -v mcp-server-memory-bank &>/dev/null; then
        log_success "  memory-bank: ready"
    else
        log_warn "  memory-bank: not found"
        all_ok=false
    fi

    if command -v mcp-server-sequential-thinking &>/dev/null; then
        log_success "  sequential-thinking: ready"
    else
        log_warn "  sequential-thinking: not found"
        all_ok=false
    fi

    if command -v chroma-mcp &>/dev/null; then
        log_success "  chromadb: ready"
    else
        log_warn "  chromadb: not found"
        all_ok=false
    fi

    if [[ "$all_ok" == "true" ]]; then
        log_success "All foundation MCP servers available"
    fi
}

print_worker_info() {
    echo
    echo "============================================"
    echo "  HAL-9000 Worker: $WORKER_NAME"
    echo "============================================"
    echo "  Claude Home:   $CLAUDE_HOME"
    echo "  Workspace:     $WORKSPACE"
    echo "  Memory Bank:   $MEMORY_BANK_ROOT"
    echo "  ChromaDB:      ${CHROMADB_PROTOCOL}://${CHROMADB_HOST}:${CHROMADB_PORT} (shared)"
    echo "============================================"
    echo "  Foundation: memory-bank, chromadb, sequential-thinking"
    echo "  Add more via: claude plugin install <plugin>"
    echo "============================================"
    echo
    echo "Security:"
    echo "  ChromaDB: Shared mode (cross-worker knowledge sharing)"
    echo "  All workers share the same collections"
    if [[ "$CHROMADB_TLS_ENABLED" == "true" ]]; then
        echo "  ChromaDB: TLS encryption enabled (HTTPS)"
    fi
    echo
    echo "Session State:"
    echo "  Session runs in TMUX (independent process manager)"
    echo "  State persists across detach/attach cycles"
    echo "  Use tmux-attach.sh to reconnect to session"
    echo
}

# ============================================================================
# SESSION STATE MANAGEMENT
# ============================================================================

# Session state with TMUX-based architecture:
# - TMUX provides terminal multiplexing and process management
# - Claude state persists via file-based storage in CLAUDE_HOME (/home/claude/.claude)
# - State files: session.json, credentials, plugin configs (managed by Claude CLI)
# - TMUX socket persistence: Stored in shared volume, survives container restart
# - For cross-container persistence across attachments: File-based storage in shared volume
# - For cross-session reasoning persistence: Use Memory Bank MCP server

ensure_session_persistence() {
    local session_dir="$CLAUDE_HOME"

    # MEDIUM-3: Create directory with restrictive permissions atomically using umask
    if [[ ! -d "$session_dir" ]]; then
        (umask 077 && mkdir -p "$session_dir")
    fi

    # Session state will be managed by Claude CLI within TMUX
    # No action needed here - TMUX handles session persistence
    log_info "Session persistence configured (TMUX-based)"
}

# ============================================================================
# SECURE CLAUDE EXECUTION
# ============================================================================

# validate_secret_file_path: Validate that a secret file path is safe
# SECURITY: Prevents command injection via malicious path characters
validate_secret_file_path() {
    local path="$1"
    local name="${2:-secret file}"

    # Validate path contains only safe characters (alphanumeric, underscore, dash, dot, slash)
    if [[ ! "$path" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "SECURITY: Invalid characters in $name path: $path"
        log_error "Path must contain only: a-z, A-Z, 0-9, _, -, ., /"
        return 1
    fi

    # Prevent path traversal attempts
    if [[ "$path" == *".."* ]]; then
        log_error "SECURITY: Path traversal attempt detected in $name: $path"
        return 1
    fi

    return 0
}

# run_claude_with_secret: Execute Claude with API key read from file at exec time
# SECURITY: The key is only present in the Claude process environment, not in parent shells
# This prevents the key from being visible in docker inspect, /proc/1/environ, or shell history
run_claude_with_secret() {
    local args=("$@")

    if [[ -n "${ANTHROPIC_API_KEY_FILE:-}" ]]; then
        # Validate path is safe (prevents command injection)
        if ! validate_secret_file_path "${ANTHROPIC_API_KEY_FILE}" "ANTHROPIC_API_KEY_FILE"; then
            log_error "Cannot execute Claude with invalid secret file path"
            exit 1
        fi

        # Validate file exists and is readable
        if [[ ! -f "${ANTHROPIC_API_KEY_FILE}" ]]; then
            log_error "API key file not found: ${ANTHROPIC_API_KEY_FILE}"
            exit 1
        fi

        if [[ ! -r "${ANTHROPIC_API_KEY_FILE}" ]]; then
            log_error "API key file not readable: ${ANTHROPIC_API_KEY_FILE}"
            exit 1
        fi

        # Validate file is not empty
        if [[ ! -s "${ANTHROPIC_API_KEY_FILE}" ]]; then
            log_error "API key file is empty: ${ANTHROPIC_API_KEY_FILE}"
            exit 1
        fi

        # Read secret at exec time - key only exists in Claude process
        log_info "Reading API key from secret file for Claude execution"
        ANTHROPIC_API_KEY=$(cat "${ANTHROPIC_API_KEY_FILE}") exec claude "${args[@]}"
    else
        # No secret file - let Claude prompt for login or use credentials
        exec claude "${args[@]}"
    fi
}

# ============================================================================
# TMUX SESSION MANAGEMENT
# ============================================================================

TMUX_SOCKET_DIR="${TMUX_SOCKET_DIR:-/data/tmux-sockets}"
TMUX_ENABLED="${TMUX_ENABLED:-true}"
# Stale socket age threshold in days (LOW-9)
TMUX_STALE_SOCKET_DAYS="${TMUX_STALE_SOCKET_DAYS:-7}"

# cleanup_stale_tmux_sockets: Remove old TMUX sockets that may be orphaned (LOW-9)
# This prevents socket accumulation from crashed workers or incomplete shutdowns
cleanup_stale_tmux_sockets() {
    log_info "Cleaning up stale TMUX sockets older than ${TMUX_STALE_SOCKET_DAYS} days..."

    local count=0
    # Find and remove stale socket files (*.sock) older than threshold
    while IFS= read -r -d '' socket; do
        log_info "Removing stale socket: $socket"
        rm -f "$socket" 2>/dev/null || true
        ((count++)) || true
    done < <(find "$TMUX_SOCKET_DIR" -maxdepth 1 -name "*.sock" -type s -mtime +"$TMUX_STALE_SOCKET_DAYS" -print0 2>/dev/null)

    # Also clean up stale tmux-* directories in /tmp (left by tmux)
    find /tmp -maxdepth 1 -name "tmux-*" -type d -mtime +"$TMUX_STALE_SOCKET_DAYS" -exec rm -rf {} \; 2>/dev/null || true

    if [[ $count -gt 0 ]]; then
        log_success "Cleaned up $count stale TMUX socket(s)"
    fi
}

init_tmux_sockets_dir() {
    if [[ "$TMUX_ENABLED" != "true" ]]; then
        log_info "TMUX disabled (TMUX_ENABLED=false)"
        return 0
    fi

    log_info "Initializing TMUX socket directory: $TMUX_SOCKET_DIR"

    # MEDIUM-3: Create directory with restrictive permissions atomically using umask
    # umask 007 gives 0770 permissions (777 - 007 = 770)
    (umask 007 && mkdir -p "$TMUX_SOCKET_DIR")

    # Clean up stale sockets from previous runs (LOW-9)
    cleanup_stale_tmux_sockets

    log_success "TMUX socket directory ready"
}

start_tmux_session() {
    if [[ "$TMUX_ENABLED" != "true" ]]; then
        log_info "TMUX disabled - starting Claude directly"
        return 1
    fi

    local tmux_socket="$TMUX_SOCKET_DIR/worker-${WORKER_NAME}.sock"
    local session_name="worker-${WORKER_NAME}"

    log_info "Starting TMUX session: $session_name"
    log_info "Socket path: $tmux_socket"

    # Kill any stale TMUX server with this socket
    tmux -S "$tmux_socket" kill-server 2>/dev/null || true
    sleep 0.5

    # SECURITY: Build Claude command that reads secret at exec time only
    # This ensures the API key is only in the Claude process environment, not in parent shells
    # The key is never visible in the entrypoint process or stored in shell history
    local claude_cmd="exec claude"
    if [[ -n "${ANTHROPIC_API_KEY_FILE:-}" ]] && [[ -f "${ANTHROPIC_API_KEY_FILE}" ]]; then
        # SECURITY: Validate path to prevent command injection
        # Path is interpolated into shell command, so must be strictly validated
        if ! validate_secret_file_path "${ANTHROPIC_API_KEY_FILE}" "ANTHROPIC_API_KEY_FILE"; then
            log_error "Cannot start TMUX session with invalid secret file path"
            return 1
        fi

        # Use printf %q to safely escape the path for shell interpolation
        local escaped_path
        escaped_path=$(printf '%q' "${ANTHROPIC_API_KEY_FILE}")

        # Read secret at exec time - key only exists in Claude process
        claude_cmd='export ANTHROPIC_API_KEY=$(cat '"${escaped_path}"'); exec claude'
        log_info "Claude will read API key from secret file at startup"
    fi

    # Create TMUX session with Claude in first window
    tmux -S "$tmux_socket" new-session -d -s "$session_name" -x 120 -y 30 \
        "$claude_cmd" 2>/dev/null || {
        log_error "Failed to create TMUX session"
        return 1
    }

    log_success "TMUX session created: $session_name"

    # Create additional shell window for debugging
    tmux -S "$tmux_socket" new-window -t "$session_name" -n "shell" -c "$WORKSPACE" \
        "exec bash" 2>/dev/null || {
        log_warn "Failed to create shell window"
    }

    log_success "Added shell debug window"

    # Export socket path for later use
    export TMUX_SOCKET="$tmux_socket"

    return 0
}

# ============================================================================
# SIGNAL HANDLING & CLEANUP
# ============================================================================

# Cleanup lifecycle:
# 1. Worker process cleanup (THIS function):
#    - Kill TMUX server (graceful session termination)
#    - Container filesystem cleanup happens automatically
# 2. Session metadata cleanup (coordinator.sh):
#    - Triggered on normal shutdown via `coordinator.sh stop <worker>`
#    - Calls cleanup_session_metadata() to remove ${HAL9000_HOME}/sessions/*.json
# 3. Stale metadata cleanup (manual or periodic):
#    - Use `coordinator.sh cleanup-stale [days]` to remove old metadata files
#    - Useful for cleanup after container crashes or timeouts
# Note: Session metadata files are stored on host/shared volume, not in container
# Worker process cannot directly clean up host-side metadata files

cleanup_on_exit() {
    local exit_code=$?
    log_info "Worker shutting down (exit code: $exit_code)..."

    # Graceful TMUX cleanup
    if [[ "$TMUX_ENABLED" == "true" && -n "${TMUX_SOCKET:-}" ]]; then
        log_info "Cleaning up TMUX server..."

        if [[ -S "$TMUX_SOCKET" ]]; then
            # Try graceful shutdown first
            if tmux -S "$TMUX_SOCKET" kill-server 2>/dev/null; then
                log_success "TMUX server stopped gracefully"
            else
                log_warn "Failed to stop TMUX gracefully, forcing shutdown"
            fi
            sleep 1
        fi
    fi

    # Clean up any temporary files created during startup
    if [[ -d "$CLAUDE_HOME/.tmp" ]]; then
        find "$CLAUDE_HOME/.tmp" -type f -mtime +1 -delete 2>/dev/null || true
    fi

    # Cleanup stale background processes
    # Jobs list shows backgrounded processes in this shell
    local jobs_count
    jobs_count=$(jobs -p | wc -l)
    if [[ $jobs_count -gt 0 ]]; then
        log_info "Killing $jobs_count background processes..."
        jobs -p | xargs -r kill -9 2>/dev/null || true
    fi

    log_info "Worker cleanup complete"
    exit "$exit_code"
}

trap cleanup_on_exit SIGTERM SIGINT EXIT

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "HAL-9000 Worker starting..."

    # Run initialization
    init_claude_home
    setup_foundation_mcp
    setup_workspace
    verify_claude
    verify_mcp_servers
    verify_chromadb_connectivity  # Non-fatal: logs warning if ChromaDB unavailable
    init_tmux_sockets_dir
    ensure_session_persistence

    print_worker_info

    # Handle command
    case "${1:-claude}" in
        claude)
            log_info "Starting Claude..."
            if start_tmux_session; then
                log_success "TMUX session ready - keeping worker alive"
                # Keep worker process alive (TMUX session is managing Claude)
                exec tail -f /dev/null
            else
                log_warn "TMUX failed - falling back to direct execution"
                # SECURITY: Use helper that reads secret at exec time only
                run_claude_with_secret
            fi
            ;;
        claude-*)
            # For non-standard Claude modes, run directly
            # SECURITY: Use helper that reads secret at exec time only
            run_claude_with_secret "${1#claude-}" "${@:2}"
            ;;
        bash|sh)
            exec "$@"
            ;;
        sleep)
            exec sleep "${2:-infinity}"
            ;;
        *)
            exec "$@"
            ;;
    esac
}

main "$@"
