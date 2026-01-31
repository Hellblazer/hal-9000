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

import os
import sys
import fcntl
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# ============================================================================
# CONFIGURATION
# ============================================================================

# Default log directory (can be overridden via environment)
DEFAULT_LOG_DIR = os.environ.get('HAL9000_HOME', '/root/.hal9000') + '/logs'

# Security log file
SECURITY_LOG_FILE = 'security.log'

# Max log file size before rotation (10MB)
MAX_LOG_SIZE = 10 * 1024 * 1024

# Number of rotated files to keep
MAX_LOG_FILES = 5


# ============================================================================
# CORE LOGGING FUNCTIONS
# ============================================================================

def get_security_log_path() -> Path:
    """Get the path to the security log file."""
    log_dir = os.environ.get('HAL9000_LOGS_DIR', DEFAULT_LOG_DIR)
    return Path(log_dir) / SECURITY_LOG_FILE


def get_worker_id() -> str:
    """Get the current worker ID from environment or hostname."""
    return os.environ.get('WORKER_ID',
           os.environ.get('HOSTNAME', 'unknown'))


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
        details: Event details as key=value pairs
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

        # Build log entry
        timestamp = get_timestamp()
        worker_id = get_worker_id()
        log_entry = f"{timestamp} | {severity} | {event} | worker={worker_id} {details}\n"

        # Atomic append with file locking
        with open(log_path, 'a', encoding='utf-8') as f:
            # Use advisory locking to prevent interleaved writes
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                f.write(log_entry)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

        # Set permissions (owner read/write, group read)
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
    details_parts = [f'tool={tool}']

    if file_path:
        # Escape quotes in file path
        safe_path = file_path.replace('"', '\\"')
        details_parts.append(f'file="{safe_path}"')

    if reason:
        # Escape quotes in reason
        safe_reason = reason.replace('"', '\\"')
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
    return log_security_event(
        'HOOK_TIMEOUT',
        f'tool={tool} timeout_seconds={timeout_seconds} action=denied',
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
    safe_error = error.replace('"', '\\"')
    return log_security_event(
        'HOOK_ERROR',
        f'tool={tool} error="{safe_error}" action=denied',
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
    safe_path = file_path.replace('"', '\\"')
    return log_security_event(
        'SECRET_ACCESS_ATTEMPT',
        f'tool={tool} file="{safe_path}"',
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
    safe_details = details.replace('"', '\\"')
    return log_security_event(
        'SUSPICIOUS_ACTIVITY',
        f'type={activity_type} details="{safe_details}"',
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
    safe_original = original_path.replace('"', '\\"')
    safe_resolved = resolved_path.replace('"', '\\"')
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
    # Truncate long commands to prevent log injection
    safe_command = command[:200].replace('"', '\\"')
    safe_reason = reason.replace('"', '\\"')
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
