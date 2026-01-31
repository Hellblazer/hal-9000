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

    # Touch audit log if it doesn't exist
    if [[ ! -f "$audit_log_file" ]]; then
        touch "$audit_log_file" 2>/dev/null || true
        chmod 0640 "$audit_log_file" 2>/dev/null || true
    fi
}

# Get current user for audit trail
# Priority: ANTHROPIC_API_KEY owner (if set), USER env var, fallback to 'system'
get_audit_user() {
    # If ANTHROPIC_API_KEY is set, extract owner (format: sk-ant-api03-...)
    # We'll use first 12 chars of key as identifier (not logging full key for security)
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "api:${ANTHROPIC_API_KEY:0:12}..."
        return
    fi

    # Use USER environment variable if available
    if [[ -n "${USER:-}" ]]; then
        echo "user:${USER}"
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
    mv "$audit_log_file" "${audit_log_file}.1" 2>/dev/null || true
    touch "$audit_log_file" 2>/dev/null || true
    chmod 0640 "$audit_log_file" 2>/dev/null || true
}

# Write audit log entry
# Usage: audit_log <event_type> <resource> <details>
# Example: audit_log "worker_spawn" "worker-abc123" "image=worker:latest port=8080"
audit_log() {
    local event_type="$1"
    local resource="${2:-unknown}"
    local details="${3:-}"

    # Initialize if not already done
    init_audit_log

    # Check if rotation is needed before writing
    rotate_audit_log

    # Get audit log file path
    local audit_log_file
    audit_log_file=$(get_audit_log_file)

    # Get timestamp (ISO 8601 with timezone)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get user for audit trail
    local user
    user=$(get_audit_user)

    # Build audit log entry
    local log_entry
    log_entry="${timestamp} event=${event_type} user=${user} resource=${resource}"

    # Add details if provided
    if [[ -n "$details" ]]; then
        log_entry="${log_entry} ${details}"
    fi

    # Write to audit log (atomic append)
    echo "$log_entry" >> "$audit_log_file" 2>/dev/null || true
}

# Convenience functions for common audit events

audit_worker_spawn() {
    local worker_name="$1"
    local image="${2:-unknown}"
    local project_dir="${3:-unknown}"

    audit_log "worker_spawn" "$worker_name" "action=spawn image=${image} project=${project_dir}"
}

audit_worker_stop() {
    local worker_name="$1"
    local reason="${2:-user_request}"
    local exit_code="${3:-0}"

    audit_log "worker_stop" "$worker_name" "action=stop reason=${reason} exit_code=${exit_code}"
}

audit_coordinator_start() {
    local container_name="${1:-hal9000-parent}"

    audit_log "coordinator_start" "$container_name" "action=start"
}

audit_coordinator_stop() {
    local container_name="${1:-hal9000-parent}"
    local exit_code="${2:-0}"

    audit_log "coordinator_stop" "$container_name" "action=stop exit_code=${exit_code}"
}

audit_chromadb_start() {
    local port="${1:-8000}"
    local data_dir="${2:-/data/chromadb}"

    audit_log "chromadb_start" "chromadb-server" "action=start port=${port} data_dir=${data_dir}"
}

audit_chromadb_stop() {
    local pid="${1:-unknown}"
    local exit_code="${2:-0}"

    audit_log "chromadb_stop" "chromadb-server" "action=stop pid=${pid} exit_code=${exit_code}"
}

audit_session_cleanup() {
    local worker_name="$1"
    local metadata_removed="${2:-false}"

    audit_log "session_cleanup" "$worker_name" "action=cleanup metadata_removed=${metadata_removed}"
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

    # Touch security log if it doesn't exist
    if [[ ! -f "$security_log_file" ]]; then
        touch "$security_log_file" 2>/dev/null || true
        chmod 0640 "$security_log_file" 2>/dev/null || true
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

    mv "$security_log_file" "${security_log_file}.1" 2>/dev/null || true
    touch "$security_log_file" 2>/dev/null || true
    chmod 0640 "$security_log_file" 2>/dev/null || true
}

# Log security event with structured format
# Usage: log_security_event <event> <details> [severity]
# Severity: INFO, WARN, ERROR, CRITICAL
# Format: 2026-01-31T12:00:00Z | WARN | HOOK_DENY | tool=Read file=.env worker=abc123 reason="sensitive file"
log_security_event() {
    local event="$1"
    local details="$2"
    local severity="${3:-INFO}"

    # Initialize if not already done
    init_security_log

    # Check if rotation is needed before writing
    rotate_security_log

    # Get security log file path
    local security_log_file
    security_log_file=$(get_security_log_file)

    # Get timestamp (ISO 8601 with timezone)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get worker ID if available
    local worker_id="${WORKER_ID:-${HOSTNAME:-unknown}}"

    # Build security log entry (pipe-delimited for easy parsing)
    local log_entry
    log_entry="${timestamp} | ${severity} | ${event} | worker=${worker_id} ${details}"

    # Write to security log (atomic append)
    echo "$log_entry" >> "$security_log_file" 2>/dev/null || true

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

    log_security_event "HOOK_DENY" "tool=${tool} file=\"${file_path}\" reason=\"${reason}\"" "$severity"
}

# ChromaDB authentication success
# Usage: audit_chromadb_auth_success <worker_id> [ip_address]
audit_chromadb_auth_success() {
    local worker_id="$1"
    local ip_address="${2:-unknown}"

    log_security_event "CHROMADB_AUTH_SUCCESS" "authenticated_worker=${worker_id} ip=${ip_address}" "INFO"
}

# ChromaDB authentication failure
# Usage: audit_chromadb_auth_failure [ip_address] [reason]
audit_chromadb_auth_failure() {
    local ip_address="${1:-unknown}"
    local reason="${2:-invalid_token}"

    log_security_event "CHROMADB_AUTH_FAILURE" "ip=${ip_address} reason=\"${reason}\"" "WARN"
}

# Bulk query detection (potential data exfiltration)
# Usage: audit_bulk_query <worker_id> <result_count> <collection>
audit_bulk_query() {
    local worker_id="$1"
    local result_count="$2"
    local collection="${3:-default}"

    # Log as WARN if over threshold
    local severity="WARN"
    if [[ "$result_count" -ge 1000 ]]; then
        severity="ERROR"
    fi

    log_security_event "BULK_QUERY" "results=${result_count} collection=${collection}" "$severity"
}

# Secret file access attempt
# Usage: audit_secret_access <tool> <file_path> <worker_id>
audit_secret_access() {
    local tool="$1"
    local file_path="$2"
    local worker_id="${3:-${WORKER_ID:-unknown}}"

    log_security_event "SECRET_ACCESS_ATTEMPT" "tool=${tool} file=\"${file_path}\"" "WARN"
}

# Syscall blocked (for seccomp logging)
# Usage: audit_syscall_blocked <syscall_name> <pid> [process_name]
audit_syscall_blocked() {
    local syscall_name="$1"
    local pid="$2"
    local process_name="${3:-unknown}"

    log_security_event "SYSCALL_BLOCKED" "syscall=${syscall_name} pid=${pid} process=\"${process_name}\"" "WARN"
}

# Worker spawn (security context)
# Usage: audit_worker_spawn_security <worker_name> <image> <security_opts>
audit_worker_spawn_security() {
    local worker_name="$1"
    local image="$2"
    local security_opts="$3"

    log_security_event "WORKER_SPAWN" "name=${worker_name} image=${image} security_opts=\"${security_opts}\"" "INFO"
}

# Suspicious activity detection
# Usage: audit_suspicious_activity <activity_type> <details>
audit_suspicious_activity() {
    local activity_type="$1"
    local details="$2"

    log_security_event "SUSPICIOUS_ACTIVITY" "type=${activity_type} ${details}" "ERROR"
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
