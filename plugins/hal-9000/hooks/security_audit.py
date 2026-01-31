#!/usr/bin/env python3
"""
Security Audit Logging for HAL-9000 Hooks

Provides Python functions to log security events from hooks in a format
compatible with the bash audit-log.sh security logging.

Log format (pipe-delimited for easy parsing):
    2026-01-31T12:00:00Z | WARN | HOOK_DENY | worker=abc123 tool=Read file=.env reason="sensitive file"

Security events logged:
    - HOOK_DENY: Hook denied a tool operation
    - HOOK_TIMEOUT: Hook execution timed out (fail-closed)
    - HOOK_ERROR: Hook encountered an error (fail-closed)
    - SECRET_ACCESS_ATTEMPT: Attempt to access sensitive file
    - SUSPICIOUS_ACTIVITY: Potential malicious activity detected

All security events are logged to:
    ${HAL9000_HOME}/logs/security.log (default: /root/.hal9000/logs/security.log)
"""

import hashlib
import os
import re
import sys
import fcntl
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# ============================================================================
# LOG SANITIZATION (HIGH-1: Prevent log injection)
# ============================================================================

def sanitize_log_value(value: str) -> str:
    """
    Escape newlines, pipes, quotes, and control characters for log safety.

    Prevents log injection attacks by neutralizing characters that could:
    - Create fake log entries (newlines)
    - Break log parsing (pipes, the field delimiter)
    - Inject terminal escape sequences (control characters, ANSI codes)

    Args:
        value: The value to sanitize

    Returns:
        Sanitized string safe for logging
    """
    if not isinstance(value, str):
        value = str(value)
    # Remove ANSI escape sequences (color codes, cursor movement, etc.)
    # Pattern matches: ESC[ followed by any number of digits/semicolons, then a letter
    value = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', value)
    # Escape backslash first to prevent double-escaping
    value = value.replace('\\', '\\\\')
    # Escape newlines and carriage returns
    value = value.replace('\n', '\\n')
    value = value.replace('\r', '\\r')
    # Escape tabs
    value = value.replace('\t', '\\t')
    # Escape pipe (log field delimiter)
    value = value.replace('|', '\\|')
    # Escape quotes
    value = value.replace('"', '\\"')
    # Remove other control characters (0x00-0x1F except already handled, and 0x7F)
    value = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', value)
    return value


# ============================================================================
# CONFIGURATION
# ============================================================================

# Default log directory (can be overridden via environment)
DEFAULT_LOG_DIR = os.environ.get('HAL9000_HOME', '/root/.hal9000') + '/logs'

# Security log file
SECURITY_LOG_FILE = 'security.log'

# Max log file size before rotation (STYLE-3: configurable via environment)
# Default: 10MB (matches AUDIT_LOG_MAX_SIZE in audit-log.sh)
MAX_LOG_SIZE = int(os.environ.get('AUDIT_LOG_MAX_SIZE', 10 * 1024 * 1024))

# Number of rotated files to keep (STYLE-3: configurable via environment)
# Default: 5 (matches AUDIT_LOG_MAX_FILES in audit-log.sh)
MAX_LOG_FILES = int(os.environ.get('AUDIT_LOG_MAX_FILES', 5))


# ============================================================================
# CORE LOGGING FUNCTIONS
# ============================================================================

def get_security_log_path() -> Path:
    """Get the path to the security log file."""
    log_dir = os.environ.get('HAL9000_LOGS_DIR', DEFAULT_LOG_DIR)
    return Path(log_dir) / SECURITY_LOG_FILE


def get_container_id() -> str:
    """
    MEDIUM-11: Get the actual container ID for audit logs.

    Attempts to get the container ID from:
    1. HOSTNAME environment variable (set by Docker)
    2. /proc/self/cgroup (contains container ID on Docker)
    3. Falls back to 'unknown' if detection fails
    """
    # Try HOSTNAME first (Docker sets this to container ID by default)
    container_id = os.environ.get('HOSTNAME', '')
    if container_id:
        # Return first 12 chars (standard short container ID)
        return container_id[:12]

    # Try to extract from cgroup
    try:
        with open('/proc/self/cgroup', 'r') as f:
            for line in f:
                # Look for docker or containerd patterns
                if 'docker' in line or 'containerd' in line:
                    # Extract container ID from path like /docker/<id>
                    parts = line.strip().split('/')
                    for i, part in enumerate(parts):
                        if part in ('docker', 'containerd') and i + 1 < len(parts):
                            cid = parts[i + 1]
                            if len(cid) >= 12:
                                return cid[:12]
                        # Also check for direct container ID (64 hex chars)
                        if len(part) == 64 and all(c in '0123456789abcdef' for c in part):
                            return part[:12]
    except (FileNotFoundError, PermissionError, OSError):
        pass

    return 'unknown'


def get_worker_id() -> str:
    """Get the current worker ID from environment or container ID."""
    # First check for explicit WORKER_ID
    worker_id = os.environ.get('WORKER_ID', '')
    if worker_id:
        return worker_id

    # MEDIUM-11: Include container ID in worker identification
    container_id = get_container_id()
    hostname = os.environ.get('HOSTNAME', 'unknown')

    # Return combined identifier for better traceability
    if container_id != 'unknown' and container_id != hostname[:12]:
        return f"{hostname}:{container_id}"
    return hostname if hostname else container_id


def get_timestamp() -> str:
    """Get current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def rotate_log_if_needed(log_path: Path) -> None:
    """
    Rotate the log file if it exceeds the maximum size.

    Rotation scheme: security.log -> security.log.1 -> security.log.2 -> ...
    Oldest logs are deleted when MAX_LOG_FILES is exceeded.
    """
    if not log_path.exists():
        return

    try:
        if log_path.stat().st_size < MAX_LOG_SIZE:
            return
    except OSError:
        return

    # Rotate existing logs
    for i in range(MAX_LOG_FILES - 1, 0, -1):
        current = Path(f"{log_path}.{i}")
        next_file = Path(f"{log_path}.{i + 1}")

        if current.exists():
            if i == MAX_LOG_FILES - 1:
                # Delete oldest log
                try:
                    current.unlink()
                except OSError:
                    pass
            else:
                # Rotate to next number
                try:
                    current.rename(next_file)
                except OSError:
                    pass

    # Rotate current log to .1
    try:
        log_path.rename(Path(f"{log_path}.1"))
    except OSError:
        pass


def log_security_event(
    event: str,
    details: str,
    severity: str = 'INFO'
) -> bool:
    """
    Log a security event to the security log file.

    Args:
        event: Event type (e.g., 'HOOK_DENY', 'SECRET_ACCESS_ATTEMPT')
        details: Event details as key=value pairs (should be pre-sanitized)
        severity: Event severity (INFO, WARN, ERROR, CRITICAL)

    Returns:
        True if logging succeeded, False otherwise

    Format:
        2026-01-31T12:00:00Z | WARN | HOOK_DENY | worker=abc123 tool=Read file=.env reason="sensitive"
    """
    try:
        log_path = get_security_log_path()

        # Ensure log directory exists
        log_path.parent.mkdir(parents=True, exist_ok=True)

        # Check if rotation is needed
        rotate_log_if_needed(log_path)

        # Sanitize all components for defense in depth
        # Event type should be uppercase alphanumeric with underscores
        safe_event = sanitize_log_value(event)
        # Severity should be a known value, but sanitize anyway
        safe_severity = sanitize_log_value(severity)
        # Worker ID could come from environment/hostname
        safe_worker_id = sanitize_log_value(get_worker_id())
        # Details should already be sanitized by caller, but add defense in depth
        # Note: We don't double-sanitize details since callers already sanitize
        # This just ensures the log entry structure is protected

        # Build log entry
        timestamp = get_timestamp()
        log_entry = f"{timestamp} | {safe_severity} | {safe_event} | worker={safe_worker_id} {details}\n"

        # MEDIUM-3: Atomic file creation with secure permissions to prevent race conditions
        # Use os.open with O_CREAT and explicit mode to avoid TOCTOU race
        if not log_path.exists():
            try:
                # Create file with restrictive permissions atomically
                fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o640)
                os.close(fd)
            except FileExistsError:
                # File was created by another process - that's fine
                pass
            except OSError:
                # Permission or other error - continue with normal open
                pass

        # Atomic append with file locking
        with open(log_path, 'a', encoding='utf-8') as f:
            # Use advisory locking to prevent interleaved writes
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                f.write(log_entry)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

        # Ensure permissions are correct (in case file existed with wrong perms)
        try:
            os.chmod(log_path, 0o640)
        except OSError:
            pass

        return True

    except Exception as e:
        # Fail silently - logging should never break the hook
        # Optionally write to stderr for debugging
        if os.environ.get('HAL9000_DEBUG'):
            print(f"Security audit log failed: {e}", file=sys.stderr)
        return False


# ============================================================================
# CONVENIENCE FUNCTIONS FOR SPECIFIC SECURITY EVENTS
# ============================================================================

def audit_hook_deny(
    tool: str,
    file_path: Optional[str] = None,
    reason: str = '',
    severity: str = 'WARN'
) -> bool:
    """
    Log a hook denial event.

    Args:
        tool: Tool that was blocked (Read, Write, Edit, Bash)
        file_path: File path that was blocked (if applicable)
        reason: Reason for denial
        severity: Event severity (default: WARN)

    Returns:
        True if logging succeeded
    """
    # Sanitize tool name (should be safe but sanitize anyway)
    safe_tool = sanitize_log_value(tool)
    details_parts = [f'tool={safe_tool}']

    if file_path:
        # Sanitize file path to prevent log injection
        safe_path = sanitize_log_value(file_path)
        details_parts.append(f'file="{safe_path}"')

    if reason:
        # Sanitize reason to prevent log injection
        safe_reason = sanitize_log_value(reason)
        details_parts.append(f'reason="{safe_reason}"')

    return log_security_event('HOOK_DENY', ' '.join(details_parts), severity)


def audit_hook_timeout(tool: str, timeout_seconds: int) -> bool:
    """
    Log a hook timeout event (fail-closed).

    Args:
        tool: Tool that triggered the timeout
        timeout_seconds: Timeout threshold in seconds

    Returns:
        True if logging succeeded
    """
    safe_tool = sanitize_log_value(tool)
    return log_security_event(
        'HOOK_TIMEOUT',
        f'tool={safe_tool} timeout_seconds={timeout_seconds} action=denied',
        'WARN'
    )


def audit_hook_error(tool: str, error: str) -> bool:
    """
    Log a hook error event (fail-closed).

    Args:
        tool: Tool that caused the error
        error: Error message

    Returns:
        True if logging succeeded
    """
    safe_tool = sanitize_log_value(tool)
    safe_error = sanitize_log_value(error)
    return log_security_event(
        'HOOK_ERROR',
        f'tool={safe_tool} error="{safe_error}" action=denied',
        'ERROR'
    )


def audit_secret_access_attempt(tool: str, file_path: str) -> bool:
    """
    Log an attempt to access a sensitive file.

    Args:
        tool: Tool used for access attempt
        file_path: Path to the sensitive file

    Returns:
        True if logging succeeded
    """
    safe_tool = sanitize_log_value(tool)
    safe_path = sanitize_log_value(file_path)
    return log_security_event(
        'SECRET_ACCESS_ATTEMPT',
        f'tool={safe_tool} file="{safe_path}"',
        'WARN'
    )


def audit_suspicious_activity(activity_type: str, details: str) -> bool:
    """
    Log suspicious activity detection.

    Args:
        activity_type: Type of suspicious activity
        details: Additional details

    Returns:
        True if logging succeeded
    """
    safe_type = sanitize_log_value(activity_type)
    safe_details = sanitize_log_value(details)
    return log_security_event(
        'SUSPICIOUS_ACTIVITY',
        f'type={safe_type} details="{safe_details}"',
        'ERROR'
    )


def audit_symlink_bypass_attempt(original_path: str, resolved_path: str) -> bool:
    """
    Log a symlink bypass attempt.

    Args:
        original_path: Original requested path
        resolved_path: Resolved path after symlink resolution

    Returns:
        True if logging succeeded
    """
    safe_original = sanitize_log_value(original_path)
    safe_resolved = sanitize_log_value(resolved_path)
    return log_security_event(
        'SYMLINK_BYPASS_ATTEMPT',
        f'original="{safe_original}" resolved="{safe_resolved}"',
        'WARN'
    )


def audit_command_blocked(command: str, reason: str) -> bool:
    """
    Log a blocked bash command.

    Args:
        command: The blocked command (truncated for safety)
        reason: Reason for blocking

    Returns:
        True if logging succeeded
    """
    # Truncate long commands first, then sanitize
    truncated_command = command[:200]
    safe_command = sanitize_log_value(truncated_command)
    safe_reason = sanitize_log_value(reason)
    return log_security_event(
        'COMMAND_BLOCKED',
        f'command="{safe_command}" reason="{safe_reason}"',
        'WARN'
    )


# ============================================================================
# MONITORING HELPERS
# ============================================================================

def get_recent_security_events(
    count: int = 20,
    severity_filter: Optional[str] = None,
    event_filter: Optional[str] = None
) -> list[str]:
    """
    Get recent security events from the log.

    Args:
        count: Number of events to return
        severity_filter: Filter by severity (INFO, WARN, ERROR, CRITICAL)
        event_filter: Filter by event type (HOOK_DENY, etc.)

    Returns:
        List of log entries (most recent first)
    """
    log_path = get_security_log_path()

    if not log_path.exists():
        return []

    try:
        with open(log_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        # Apply filters
        filtered = []
        for line in lines:
            if severity_filter and f'| {severity_filter} |' not in line:
                continue
            if event_filter and f'| {event_filter} |' not in line:
                continue
            filtered.append(line.strip())

        # Return most recent
        return filtered[-count:][::-1]

    except Exception:
        return []


def count_security_events(hours: int = 24, event_type: Optional[str] = None) -> dict:
    """
    Count security events in the specified time window.

    Args:
        hours: Number of hours to look back
        event_type: Optional filter by event type

    Returns:
        Dict with event counts by severity
    """
    log_path = get_security_log_path()

    counts = {'INFO': 0, 'WARN': 0, 'ERROR': 0, 'CRITICAL': 0, 'total': 0}

    if not log_path.exists():
        return counts

    try:
        # Calculate cutoff time
        from datetime import timedelta
        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
        cutoff_str = cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')

        with open(log_path, 'r', encoding='utf-8') as f:
            for line in f:
                parts = line.split('|')
                if len(parts) < 3:
                    continue

                timestamp = parts[0].strip()
                severity = parts[1].strip()
                event = parts[2].strip()

                # Check timestamp
                if timestamp < cutoff_str:
                    continue

                # Check event type filter
                if event_type and event != event_type:
                    continue

                # Count
                if severity in counts:
                    counts[severity] += 1
                counts['total'] += 1

        return counts

    except Exception:
        return counts


if __name__ == '__main__':
    # Test the logging functions
    print("Testing security audit logging...")

    # Test basic logging
    success = log_security_event('TEST_EVENT', 'test=true', 'INFO')
    print(f"Basic log: {'OK' if success else 'FAILED'}")

    # Test hook denial
    success = audit_hook_deny('Read', '/etc/passwd', 'sensitive system file')
    print(f"Hook deny log: {'OK' if success else 'FAILED'}")

    # Test secret access
    success = audit_secret_access_attempt('Read', '.env')
    print(f"Secret access log: {'OK' if success else 'FAILED'}")

    # Show recent events
    print("\nRecent security events:")
    for event in get_recent_security_events(5):
        print(f"  {event}")

    # Show counts
    print(f"\nEvent counts (last 24h): {count_security_events()}")
