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
