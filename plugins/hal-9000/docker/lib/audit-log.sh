#!/usr/bin/env bash
# audit-log.sh - Centralized Audit Logging for HAL-9000
#
# Provides audit logging with timestamps, user tracking, and log rotation
# for security incident detection and investigation.
#
# Usage:
#   source /scripts/lib/audit-log.sh
#   audit_log "worker_spawn" "worker-abc123" "action=spawn status=starting"
#   audit_log "worker_stop" "worker-abc123" "action=stop reason=user_request"
#   audit_log "coordinator_start" "hal9000-parent" "action=start"

set -euo pipefail

# Audit log configuration constants
: "${AUDIT_LOG_MAX_SIZE:=$((10 * 1024 * 1024))}"  # 10MB
: "${AUDIT_LOG_MAX_FILES:=5}"

# ============================================================================
# LOG SANITIZATION (HIGH-1: Prevent log injection)
# ============================================================================

# Sanitize a value for safe logging
# Escapes newlines, pipes, quotes, and control characters
# Removes ANSI escape sequences to prevent log injection attacks
# Usage: sanitized=$(sanitize_log_value "$value")
sanitize_log_value() {
    local value="$1"
    # Escape backslash first to prevent double-escaping
    value="${value//\\/\\\\}"
    # Escape newlines and carriage returns
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    # Escape tabs
    value="${value//$'\t'/\\t}"
    # Escape pipe (log field delimiter)
    value="${value//|/\\|}"
    # Escape quotes
    value="${value//\"/\\\"}"
    # Remove ANSI escape sequences (color codes, cursor movement, etc.)
    # Pattern matches: ESC[ followed by any number of digits/semicolons, then a letter
    value=$(printf '%s' "$value" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')
    # Remove control characters (0x00-0x1F except already handled, and 0x7F)
    # Using tr to remove control characters
    value=$(printf '%s' "$value" | tr -d '\000-\010\013\014\016-\037\177')
    printf '%s' "$value"
}

# MEDIUM-11: Get container ID from cgroup (unspoofable)
# Returns 12-char container ID for audit logging correlation
# Falls back to "host" if not running in a container
get_container_id() {
    # Try cgroups v2 first (unified hierarchy)
    if [[ -f /proc/self/cgroup ]]; then
        local cgroup_line
        cgroup_line=$(cat /proc/self/cgroup 2>/dev/null | head -1)

        # Extract container ID from docker path
        if [[ "$cgroup_line" =~ /docker/([a-f0-9]{12,64}) ]]; then
            echo "${BASH_REMATCH[1]:0:12}"  # First 12 chars
            return 0
        fi

        # Try containerd pattern
        if [[ "$cgroup_line" =~ /containerd/([a-f0-9]{12,64}) ]]; then
            echo "${BASH_REMATCH[1]:0:12}"  # First 12 chars
            return 0
        fi
    fi

    # Fallback: try hostname (usually container ID in Docker)
    if [[ -f "/.dockerenv" ]]; then
        hostname 2>/dev/null | head -c 12
        return 0
    fi

    echo "host"
}

# Get audit log directory (respects HAL9000_HOME override)
get_audit_log_dir() {
    echo "${HAL9000_HOME:-/root/.hal9000}/logs"
}

# Get audit log file path
get_audit_log_file() {
    echo "$(get_audit_log_dir)/audit.log"
}

# Initialize audit logging
init_audit_log() {
    local audit_log_dir
    audit_log_dir=$(get_audit_log_dir)

    local audit_log_file
    audit_log_file=$(get_audit_log_file)

    # Ensure log directory exists
    mkdir -p "$audit_log_dir" 2>/dev/null || true

    # MEDIUM-3: Create audit log with restrictive permissions atomically using umask
    if [[ ! -f "$audit_log_file" ]]; then
        (umask 027 && touch "$audit_log_file") 2>/dev/null || true
    fi
}

# Get current user for audit trail
# Priority: ANTHROPIC_API_KEY_FILE (if set), USER env var, fallback to 'system'
# HIGH-4: Uses hash of API key instead of truncation for security
# SECURITY: Reads from file path to support file-based secrets
# Uses 16 chars of SHA256 hash for better entropy while maintaining log readability
get_audit_user() {
    # If ANTHROPIC_API_KEY_FILE is set, read key from file and hash it
    # This allows correlation without exposing any part of the actual key
    if [[ -f "${ANTHROPIC_API_KEY_FILE:-}" ]]; then
        local key_hash
        key_hash=$(cat "${ANTHROPIC_API_KEY_FILE}" 2>/dev/null | sha256sum 2>/dev/null | cut -c1-16 || \
                   cat "${ANTHROPIC_API_KEY_FILE}" 2>/dev/null | shasum -a 256 2>/dev/null | cut -c1-16 || \
                   echo "hash_error")
        echo "api_hash:${key_hash}"
        return
    fi

    # Fallback: check if key is in environment (legacy, deprecated)
    # This case should not happen with new security model, but kept for backward compatibility
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        local key_hash
        key_hash=$(printf '%s' "$ANTHROPIC_API_KEY" | sha256sum 2>/dev/null | cut -c1-16 || \
                   printf '%s' "$ANTHROPIC_API_KEY" | shasum -a 256 2>/dev/null | cut -c1-16 || \
                   echo "hash_error")
        echo "api_hash:${key_hash}"
        return
    fi

    # Use USER environment variable if available (sanitized)
    if [[ -n "${USER:-}" ]]; then
        local safe_user
        safe_user=$(sanitize_log_value "${USER}")
        echo "user:${safe_user}"
        return
    fi

    # Fallback to system
    echo "system"
}

# Rotate audit log if it exceeds max size
rotate_audit_log() {
    local audit_log_file
    audit_log_file=$(get_audit_log_file)

    [[ ! -f "$audit_log_file" ]] && return 0

    local log_size
    log_size=$(stat -f%z "$audit_log_file" 2>/dev/null || stat -c%s "$audit_log_file" 2>/dev/null || echo "0")

    # Check if rotation is needed
    if [[ "$log_size" -lt "$AUDIT_LOG_MAX_SIZE" ]]; then
        return 0
    fi

    # Rotate existing logs
    for i in $(seq $((AUDIT_LOG_MAX_FILES - 1)) -1 1); do
        local current="${audit_log_file}.${i}"
        local next="${audit_log_file}.$((i + 1))"

        if [[ -f "$current" ]]; then
            if [[ $i -eq $((AUDIT_LOG_MAX_FILES - 1)) ]]; then
                # Delete oldest log
                rm -f "$current" 2>/dev/null || true
            else
                # Rotate to next number
                mv "$current" "$next" 2>/dev/null || true
            fi
        fi
    done

    # Rotate current log to .1
    # MEDIUM-3: Create new log file with restrictive permissions atomically using umask
    mv "$audit_log_file" "${audit_log_file}.1" 2>/dev/null || true
    (umask 027 && touch "$audit_log_file") 2>/dev/null || true
}

# validate_event_type: Validate event_type format (STYLE-4)
# Event types should be uppercase letters and underscores only (e.g., WORKER_SPAWN, HOOK_DENY)
validate_event_type() {
    local event="$1"
    if [[ ! "$event" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "Invalid event_type format: $event (expected alphanumeric with underscores)"
        return 1
    fi
    return 0
}

# Write audit log entry
# Usage: audit_log <event_type> <resource> <details>
# Example: audit_log "worker_spawn" "worker-abc123" "image=worker:latest port=8080"
# HIGH-5: Uses flock for atomic writes to prevent interleaved entries
audit_log() {
    local event_type="$1"
    local resource="${2:-unknown}"
    local details="${3:-}"

    # STYLE-4: Validate event_type format
    if ! validate_event_type "$event_type"; then
        # Sanitize invalid event type but continue logging
        event_type="INVALID_EVENT"
    fi

    # Initialize if not already done
    init_audit_log

    # Get audit log file path
    local audit_log_file
    audit_log_file=$(get_audit_log_file)
    local lock_file="${audit_log_file}.lock"

    # Get timestamp (ISO 8601 with timezone)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get user for audit trail
    local user
    user=$(get_audit_user)

    # MEDIUM-11: Get container ID (unspoofable, from cgroup)
    local container_id
    container_id=$(get_container_id)

    # Sanitize user-controlled values to prevent log injection
    local safe_event_type safe_resource safe_details
    safe_event_type=$(sanitize_log_value "$event_type")
    safe_resource=$(sanitize_log_value "$resource")
    safe_details=$(sanitize_log_value "$details")

    # Build audit log entry (includes container_id for cross-container correlation)
    local log_entry
    log_entry="${timestamp} container=${container_id} event=${safe_event_type} user=${user} resource=${safe_resource}"

    # Add details if provided
    if [[ -n "$safe_details" ]]; then
        log_entry="${log_entry} ${safe_details}"
    fi

    # Write to audit log with file locking for atomic append (HIGH-5)
    # Use flock with 5-second timeout to prevent interleaved writes from concurrent processes
    # Timeout tradeoff:
    #   - Too short: high-frequency logging may fail acquisition
    #   - Too long: slow log rotation blocks writers excessively
    #   - 5 seconds balances responsiveness and reliability for typical workloads
    (
        flock -w 5 200 || {
            echo "WARNING: Could not acquire audit log lock after 5s" >&2
            exit 1
        }

        # Check if rotation is needed while holding lock (prevents race condition)
        rotate_audit_log

        echo "$log_entry" >> "$audit_log_file"
    ) 200>"$lock_file" 2>/dev/null || {
        # Check if strict locking is required (for compliance/audit integrity)
        if [[ "${AUDIT_LOG_REQUIRE_LOCK:-false}" == "true" ]]; then
            echo "ERROR: Audit log lock acquisition failed and AUDIT_LOG_REQUIRE_LOCK=true" >&2
            echo "ERROR: Refusing to write potentially corrupted audit entry" >&2
            return 1
        fi

        # Graceful degradation: write without lock if flock failed
        echo "WARNING: Audit log lock acquisition failed, writing without lock" >&2
        echo "$log_entry" >> "$audit_log_file" 2>/dev/null || true
    }
}

# Convenience functions for common audit events

audit_worker_spawn() {
    local worker_name="$1"
    local image="${2:-unknown}"
    local project_dir="${3:-unknown}"

    # Sanitize inputs (audit_log also sanitizes, but pre-sanitize for consistency)
    local safe_name safe_image safe_project
    safe_name=$(sanitize_log_value "$worker_name")
    safe_image=$(sanitize_log_value "$image")
    safe_project=$(sanitize_log_value "$project_dir")

    audit_log "worker_spawn" "$safe_name" "action=spawn image=${safe_image} project=${safe_project}"
}

audit_worker_stop() {
    local worker_name="$1"
    local reason="${2:-user_request}"
    local exit_code="${3:-0}"

    # Sanitize inputs
    local safe_name safe_reason
    safe_name=$(sanitize_log_value "$worker_name")
    safe_reason=$(sanitize_log_value "$reason")

    audit_log "worker_stop" "$safe_name" "action=stop reason=${safe_reason} exit_code=${exit_code}"
}

audit_coordinator_start() {
    local container_name="${1:-hal9000-parent}"

    local safe_name
    safe_name=$(sanitize_log_value "$container_name")

    audit_log "coordinator_start" "$safe_name" "action=start"
}

audit_coordinator_stop() {
    local container_name="${1:-hal9000-parent}"
    local exit_code="${2:-0}"

    local safe_name
    safe_name=$(sanitize_log_value "$container_name")

    audit_log "coordinator_stop" "$safe_name" "action=stop exit_code=${exit_code}"
}

audit_chromadb_start() {
    local port="${1:-8000}"
    local data_dir="${2:-/data/chromadb}"

    local safe_dir
    safe_dir=$(sanitize_log_value "$data_dir")

    audit_log "chromadb_start" "chromadb-server" "action=start port=${port} data_dir=${safe_dir}"
}

audit_chromadb_stop() {
    local pid="${1:-unknown}"
    local exit_code="${2:-0}"

    audit_log "chromadb_stop" "chromadb-server" "action=stop pid=${pid} exit_code=${exit_code}"
}

audit_session_cleanup() {
    local worker_name="$1"
    local metadata_removed="${2:-false}"

    local safe_name
    safe_name=$(sanitize_log_value "$worker_name")

    audit_log "session_cleanup" "$safe_name" "action=cleanup metadata_removed=${metadata_removed}"
}

# ============================================================================
# SECURITY AUDIT LOGGING
# ============================================================================

# Get security audit log file path (separate from general audit log)
get_security_log_file() {
    echo "$(get_audit_log_dir)/security.log"
}

# Initialize security logging
init_security_log() {
    local security_log_dir
    security_log_dir=$(get_audit_log_dir)

    local security_log_file
    security_log_file=$(get_security_log_file)

    # Ensure log directory exists
    mkdir -p "$security_log_dir" 2>/dev/null || true

    # MEDIUM-3: Create security log with restrictive permissions atomically using umask
    if [[ ! -f "$security_log_file" ]]; then
        (umask 027 && touch "$security_log_file") 2>/dev/null || true
    fi
}

# Rotate security log if it exceeds max size
rotate_security_log() {
    local security_log_file
    security_log_file=$(get_security_log_file)

    [[ ! -f "$security_log_file" ]] && return 0

    local log_size
    log_size=$(stat -f%z "$security_log_file" 2>/dev/null || stat -c%s "$security_log_file" 2>/dev/null || echo "0")

    # Check if rotation is needed
    if [[ "$log_size" -lt "$AUDIT_LOG_MAX_SIZE" ]]; then
        return 0
    fi

    # Rotate existing logs
    for i in $(seq $((AUDIT_LOG_MAX_FILES - 1)) -1 1); do
        local current="${security_log_file}.${i}"
        local next="${security_log_file}.$((i + 1))"

        if [[ -f "$current" ]]; then
            if [[ $i -eq $((AUDIT_LOG_MAX_FILES - 1)) ]]; then
                rm -f "$current" 2>/dev/null || true
            else
                mv "$current" "$next" 2>/dev/null || true
            fi
        fi
    done

    # MEDIUM-3: Create new security log with restrictive permissions atomically using umask
    mv "$security_log_file" "${security_log_file}.1" 2>/dev/null || true
    (umask 027 && touch "$security_log_file") 2>/dev/null || true
}

# Log security event with structured format
# Usage: log_security_event <event> <details> [severity]
# Severity: INFO, WARN, ERROR, CRITICAL
# Format: 2026-01-31T12:00:00Z | WARN | HOOK_DENY | tool=Read file=.env worker=abc123 reason="sensitive file"
# HIGH-5: Uses flock for atomic writes with 5-second timeout
log_security_event() {
    local event="$1"
    local details="$2"
    local severity="${3:-INFO}"

    # Initialize if not already done
    init_security_log

    # Get security log file path
    local security_log_file
    security_log_file=$(get_security_log_file)
    local lock_file="${security_log_file}.lock"

    # Get timestamp (ISO 8601 with timezone)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get worker ID if available and sanitize it
    local worker_id
    worker_id=$(sanitize_log_value "${WORKER_ID:-${HOSTNAME:-unknown}}")

    # MEDIUM-11: Get container ID (unspoofable, from cgroup)
    local container_id
    container_id=$(get_container_id)

    # Sanitize event and severity (should be safe values but defense in depth)
    local safe_event safe_severity
    safe_event=$(sanitize_log_value "$event")
    safe_severity=$(sanitize_log_value "$severity")
    # Details should be pre-sanitized by callers, but we sanitize worker_id here

    # Build security log entry (pipe-delimited for easy parsing, includes container_id)
    local log_entry
    log_entry="${timestamp} | ${safe_severity} | ${safe_event} | container=${container_id} worker=${worker_id} ${details}"

    # Write to security log with file locking for atomic append (HIGH-5)
    # Use flock with 5-second timeout to prevent interleaved writes from concurrent processes
    (
        flock -w 5 200 || {
            echo "WARNING: Could not acquire security log lock after 5s" >&2
            exit 1
        }

        # Check if rotation is needed while holding lock (prevents race condition)
        rotate_security_log

        echo "$log_entry" >> "$security_log_file"
    ) 200>"$lock_file" 2>/dev/null || {
        # Check if strict locking is required (for compliance/audit integrity)
        if [[ "${AUDIT_LOG_REQUIRE_LOCK:-false}" == "true" ]]; then
            echo "ERROR: Security log lock acquisition failed and AUDIT_LOG_REQUIRE_LOCK=true" >&2
            echo "ERROR: Refusing to write potentially corrupted security entry" >&2
            return 1
        fi

        # Graceful degradation: write without lock if flock failed
        echo "WARNING: Security log lock acquisition failed, writing without lock" >&2
        echo "$log_entry" >> "$security_log_file" 2>/dev/null || true
    }

    # Also write to general audit log for completeness
    audit_log "security_${event,,}" "$worker_id" "severity=${severity} ${details}"
}

# Convenience functions for common security events

# Hook denial logging
# Usage: audit_hook_deny <tool> <file_path> <reason> [severity]
audit_hook_deny() {
    local tool="$1"
    local file_path="$2"
    local reason="$3"
    local severity="${4:-WARN}"

    # Sanitize all user-controlled inputs
    local safe_tool safe_path safe_reason
    safe_tool=$(sanitize_log_value "$tool")
    safe_path=$(sanitize_log_value "$file_path")
    safe_reason=$(sanitize_log_value "$reason")

    log_security_event "HOOK_DENY" "tool=${safe_tool} file=\"${safe_path}\" reason=\"${safe_reason}\"" "$severity"
}

# ChromaDB authentication success
# Usage: audit_chromadb_auth_success <worker_id> [ip_address]
audit_chromadb_auth_success() {
    local worker_id="$1"
    local ip_address="${2:-unknown}"

    # Sanitize inputs
    local safe_worker safe_ip
    safe_worker=$(sanitize_log_value "$worker_id")
    safe_ip=$(sanitize_log_value "$ip_address")

    log_security_event "CHROMADB_AUTH_SUCCESS" "authenticated_worker=${safe_worker} ip=${safe_ip}" "INFO"
}

# ChromaDB authentication failure
# Usage: audit_chromadb_auth_failure [ip_address] [reason]
audit_chromadb_auth_failure() {
    local ip_address="${1:-unknown}"
    local reason="${2:-invalid_token}"

    # Sanitize inputs
    local safe_ip safe_reason
    safe_ip=$(sanitize_log_value "$ip_address")
    safe_reason=$(sanitize_log_value "$reason")

    log_security_event "CHROMADB_AUTH_FAILURE" "ip=${safe_ip} reason=\"${safe_reason}\"" "WARN"
}

# Bulk query detection (potential data exfiltration)
# Usage: audit_bulk_query <worker_id> <result_count> <collection>
audit_bulk_query() {
    local worker_id="$1"
    local result_count="$2"
    local collection="${3:-default}"

    # Sanitize inputs (result_count should be numeric, but sanitize anyway)
    local safe_collection
    safe_collection=$(sanitize_log_value "$collection")

    # Log as WARN if over threshold
    local severity="WARN"
    if [[ "$result_count" -ge 1000 ]]; then
        severity="ERROR"
    fi

    log_security_event "BULK_QUERY" "results=${result_count} collection=${safe_collection}" "$severity"
}

# Secret file access attempt
# Usage: audit_secret_access <tool> <file_path> <worker_id>
audit_secret_access() {
    local tool="$1"
    local file_path="$2"
    local worker_id="${3:-${WORKER_ID:-unknown}}"

    # Sanitize inputs
    local safe_tool safe_path
    safe_tool=$(sanitize_log_value "$tool")
    safe_path=$(sanitize_log_value "$file_path")

    log_security_event "SECRET_ACCESS_ATTEMPT" "tool=${safe_tool} file=\"${safe_path}\"" "WARN"
}

# Syscall blocked (for seccomp logging)
# Usage: audit_syscall_blocked <syscall_name> <pid> [process_name]
audit_syscall_blocked() {
    local syscall_name="$1"
    local pid="$2"
    local process_name="${3:-unknown}"

    # Sanitize inputs
    local safe_syscall safe_process
    safe_syscall=$(sanitize_log_value "$syscall_name")
    safe_process=$(sanitize_log_value "$process_name")

    log_security_event "SYSCALL_BLOCKED" "syscall=${safe_syscall} pid=${pid} process=\"${safe_process}\"" "WARN"
}

# Worker spawn (security context)
# Usage: audit_worker_spawn_security <worker_name> <image> <security_opts>
audit_worker_spawn_security() {
    local worker_name="$1"
    local image="$2"
    local security_opts="$3"

    # Sanitize inputs
    local safe_name safe_image safe_opts
    safe_name=$(sanitize_log_value "$worker_name")
    safe_image=$(sanitize_log_value "$image")
    safe_opts=$(sanitize_log_value "$security_opts")

    log_security_event "WORKER_SPAWN" "name=${safe_name} image=${safe_image} security_opts=\"${safe_opts}\"" "INFO"
}

# Suspicious activity detection
# Usage: audit_suspicious_activity <activity_type> <details>
audit_suspicious_activity() {
    local activity_type="$1"
    local details="$2"

    # Sanitize inputs
    local safe_type safe_details
    safe_type=$(sanitize_log_value "$activity_type")
    safe_details=$(sanitize_log_value "$details")

    log_security_event "SUSPICIOUS_ACTIVITY" "type=${safe_type} ${safe_details}" "ERROR"
}

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

# Query security log (for investigation)
# Usage: query_security_log <event_type> [hours_ago] [severity]
query_security_log() {
    local event_type="${1:-}"
    local hours_ago="${2:-24}"
    local severity="${3:-}"

    local security_log_file
    security_log_file=$(get_security_log_file)

    [[ ! -f "$security_log_file" ]] && {
        echo "No security log found"
        return 1
    }

    local since
    since=$(date -u -v-${hours_ago}H +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
            date -u -d "${hours_ago} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
            echo "")

    # Build grep pattern
    local pattern=""
    if [[ -n "$event_type" ]]; then
        pattern="$event_type"
    fi
    if [[ -n "$severity" ]]; then
        if [[ -n "$pattern" ]]; then
            pattern="$pattern.*$severity\|$severity.*$event_type"
        else
            pattern="| $severity |"
        fi
    fi

    if [[ -n "$pattern" ]]; then
        if [[ -n "$since" ]]; then
            awk -v since="$since" '$1 >= since' "$security_log_file" | grep -E "$pattern"
        else
            grep -E "$pattern" "$security_log_file"
        fi
    else
        if [[ -n "$since" ]]; then
            awk -v since="$since" '$1 >= since' "$security_log_file"
        else
            cat "$security_log_file"
        fi
    fi
}

# Security event summary (for dashboards)
# Usage: security_event_summary [hours_ago]
security_event_summary() {
    local hours_ago="${1:-24}"

    local security_log_file
    security_log_file=$(get_security_log_file)

    [[ ! -f "$security_log_file" ]] && {
        echo "No security log found"
        return 1
    }

    echo "=== Security Event Summary (last ${hours_ago} hours) ==="
    echo

    # Count by event type
    echo "Event Types:"
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}' "$security_log_file" | \
        sort | uniq -c | sort -rn | head -20

    echo
    echo "By Severity:"
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$security_log_file" | \
        sort | uniq -c | sort -rn

    echo
    echo "Recent Warnings/Errors:"
    grep -E "\| (WARN|ERROR|CRITICAL) \|" "$security_log_file" | tail -10
}

# Query audit log (optional helper for investigation)
# Usage: query_audit_log <event_type> [time_range]
query_audit_log() {
    local event_type="${1:-}"
    local hours_ago="${2:-24}"

    local audit_log_file
    audit_log_file=$(get_audit_log_file)

    [[ ! -f "$audit_log_file" ]] && {
        echo "No audit log found"
        return 1
    }

    local since
    since=$(date -u -v-${hours_ago}H +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
            date -u -d "${hours_ago} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
            echo "")

    if [[ -n "$event_type" ]]; then
        if [[ -n "$since" ]]; then
            # Filter by event type and time range
            awk -v since="$since" -v event="$event_type" \
                '$1 >= since && $0 ~ event' "$audit_log_file"
        else
            # Filter by event type only
            grep "event=${event_type}" "$audit_log_file"
        fi
    else
        if [[ -n "$since" ]]; then
            # Filter by time range only
            awk -v since="$since" '$1 >= since' "$audit_log_file"
        else
            # Show all entries
            cat "$audit_log_file"
        fi
    fi
}
