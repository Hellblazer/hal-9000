#!/usr/bin/env python3
"""
File Access Hook - Blocks access to sensitive files via Read, Write, Edit, Grep, NotebookEdit tools.

SECURITY: Uses os.path.realpath() to resolve symlinks, preventing bypass attacks.
Checks BOTH the original requested path AND the resolved path.

Supported tools:
- Read, Write, Edit: extracts file_path parameter
- Grep: extracts path parameter (can be file or directory)
- NotebookEdit: extracts notebook_path parameter

Blocked files:
- .env, .env.* (environment files with secrets)
- credentials.json, *credentials*.json (API credentials)
- *.pem, *.key (cryptographic keys)
- id_rsa, id_ed25519, id_dsa, id_ecdsa (SSH private keys)
- .aws/credentials (AWS credentials)
- .kube/config (Kubernetes config)
- .netrc (network credentials)
- .npmrc (npm credentials - can contain auth tokens)
- .pypirc (PyPI credentials)
- .docker/config.json (Docker registry credentials)
- known_hosts (SSH known hosts - information disclosure)

Fail-closed: On ANY error (timeout, exception), access is DENIED.
"""
import json
import os
import platform
import re
import signal
import sys
import threading
from pathlib import Path

# Import security audit logging (graceful degradation if unavailable)
try:
    from security_audit import (
        audit_hook_deny,
        audit_hook_timeout,
        audit_hook_error,
        audit_secret_access_attempt,
        audit_symlink_bypass_attempt,
    )
    SECURITY_AUDIT_AVAILABLE = True
except ImportError:
    SECURITY_AUDIT_AVAILABLE = False


# ============================================================================
# CONFIGURATION
# ============================================================================

# Timeout for hook execution (seconds)
HOOK_TIMEOUT = 10

# Exact filename matches (case-insensitive)
SENSITIVE_FILENAMES = {
    '.env',
    '.envrc',
    'credentials.json',
    'secrets.json',
    'id_rsa',
    'id_dsa',
    'id_ecdsa',
    'id_ed25519',
    '.netrc',
    '.npmrc',
    '.pypirc',
    'known_hosts',
    'config.json',  # Often contains secrets in .docker/
    '.pgpass',      # PostgreSQL credentials
    '.my.cnf',      # MySQL credentials
    '.pgservice.conf',  # PostgreSQL service definitions with credentials
}

# Filename patterns (regex, case-insensitive)
SENSITIVE_FILENAME_PATTERNS = [
    r'^\.env\.[a-zA-Z0-9_.-]+$',    # .env.local, .env.production, etc.
    r'^.*credentials.*\.json$',      # any-credentials-file.json
    r'^.*secrets.*\.json$',          # any-secrets-file.json
    r'^.*\.pem$',                    # *.pem (certificates/keys)
    r'^.*\.key$',                    # *.key (private keys)
    r'^.*\.p12$',                    # *.p12 (PKCS#12 keystores)
    r'^.*\.pfx$',                    # *.pfx (PKCS#12 keystores)
    r'^.*\.jks$',                    # *.jks (Java keystores)
    r'^.*_rsa$',                     # custom_rsa (SSH keys)
    r'^.*_dsa$',                     # custom_dsa (SSH keys)
    r'^.*_ecdsa$',                   # custom_ecdsa (SSH keys)
    r'^.*_ed25519$',                 # custom_ed25519 (SSH keys)
]

# Path patterns (must match anywhere in the resolved path)
SENSITIVE_PATH_PATTERNS = [
    r'\.aws/credentials$',
    r'\.aws/config$',
    r'\.kube/config$',
    r'\.docker/config\.json$',
    r'\.ssh/id_rsa$',
    r'\.ssh/id_dsa$',
    r'\.ssh/id_ecdsa$',
    r'\.ssh/id_ed25519$',
    r'\.ssh/known_hosts$',
    r'\.gnupg/.*$',                  # GPG keys
    r'\.password-store/.*$',         # pass password manager
]


# ============================================================================
# TIMEOUT HANDLING
# ============================================================================

class TimeoutError(Exception):
    """Raised when hook execution times out."""
    pass


def timeout_handler(signum, frame):
    """Signal handler for timeout."""
    raise TimeoutError("Hook execution timed out")


# ============================================================================
# CORE SECURITY LOGIC
# ============================================================================

def is_sensitive_file(file_path: str) -> tuple[bool, str | None]:
    """
    Check if a file path points to a sensitive file.

    SECURITY: Checks BOTH the original path AND the symlink-resolved path.
    This prevents symlink bypass attacks.

    Args:
        file_path: The file path to check

    Returns:
        (is_sensitive, reason) tuple
    """
    if not file_path:
        return False, None

    # Get both the normalized path and the symlink-resolved path
    # CRITICAL: We must check BOTH paths to prevent symlink bypass
    try:
        original_path = os.path.normpath(file_path)
        resolved_path = os.path.realpath(file_path)  # Resolves ALL symlinks
    except (OSError, ValueError) as e:
        # If we can't resolve the path, DENY (fail-closed)
        return True, f"Cannot resolve path '{file_path}' (fail-closed): {e}"

    paths_to_check = [
        (original_path, "original path"),
        (resolved_path, "resolved path (symlink target)"),
    ]

    # Only add resolved path if it's different from original
    # If paths differ, log potential symlink bypass attempt
    if original_path != resolved_path:
        if SECURITY_AUDIT_AVAILABLE:
            audit_symlink_bypass_attempt(original_path, resolved_path)
    else:
        paths_to_check = [(original_path, "path")]

    for path, path_type in paths_to_check:
        path_lower = path.lower()
        filename = os.path.basename(path).lower()

        # Check exact filename matches
        if filename in SENSITIVE_FILENAMES:
            return True, f"Blocked: '{filename}' is a sensitive file ({path_type}: {path})"

        # Check filename patterns
        for pattern in SENSITIVE_FILENAME_PATTERNS:
            if re.match(pattern, filename, re.IGNORECASE):
                return True, f"Blocked: '{filename}' matches sensitive file pattern ({path_type}: {path})"

        # Check path patterns
        for pattern in SENSITIVE_PATH_PATTERNS:
            if re.search(pattern, path_lower):
                return True, f"Blocked: path matches sensitive pattern ({path_type}: {path})"

    return False, None


def extract_path_from_tool(tool_name: str, tool_input: dict) -> str | None:
    """
    Extract the file/directory path from tool input based on tool type.

    Args:
        tool_name: Name of the tool being invoked
        tool_input: The tool's input parameters

    Returns:
        The path to check, or None if no path found
    """
    if tool_name in ("Read", "Write", "Edit"):
        return tool_input.get("file_path", "")
    elif tool_name == "Grep":
        # SECURITY: Check both path and glob parameters
        # Grep can bypass path restrictions using glob patterns like "**/.env"
        path = tool_input.get("path", "")
        glob_pattern = tool_input.get("glob", "")

        # If glob contains sensitive patterns, return it for rejection
        if glob_pattern:
            glob_lower = glob_pattern.lower()
            # Check for sensitive file patterns in glob
            sensitive_glob_patterns = [
                '.env', 'secret', 'credential', 'password', 'key',
                '.ssh', '.aws', '.gnupg', '.kube', '.docker',
                '.pgpass', '.my.cnf', '.netrc', '.npmrc', '.pypirc',
                'id_rsa', 'id_ed25519', 'id_ecdsa', 'authorized_keys',
                '.git-credentials', '.boto', 'credentials.json',
            ]
            for pattern in sensitive_glob_patterns:
                if pattern in glob_lower:
                    # Return the glob pattern - it will be flagged as sensitive
                    return glob_pattern

        # Return path (or current directory if searching with just glob)
        return path if path else "."
    elif tool_name == "NotebookEdit":
        return tool_input.get("notebook_path", "")
    return None


def check_directory_for_sensitive_files(dir_path: str) -> tuple[bool, str | None]:
    """
    Check if a directory path would expose sensitive files.

    For Grep, the path can be a file or directory. We check:
    1. If it matches sensitive file patterns (regardless of existence)
    2. If the directory itself is a known sensitive directory

    Args:
        dir_path: Directory or file path to check

    Returns:
        (is_sensitive, reason) tuple
    """
    if not dir_path:
        return False, None

    try:
        resolved_path = os.path.realpath(dir_path)
    except (OSError, ValueError) as e:
        return True, f"Cannot resolve path '{dir_path}' (fail-closed): {e}"

    # ALWAYS check file patterns first - regardless of whether path exists
    # This catches cases like "grep in .env" even if file doesn't exist yet
    is_sensitive, reason = is_sensitive_file(dir_path)
    if is_sensitive:
        return is_sensitive, reason

    # For directories, also check if the directory itself is sensitive
    # (e.g., searching in .aws/, .ssh/, .gnupg/)
    path_lower = resolved_path.lower()
    sensitive_dirs = [
        r'\.aws/?$',
        r'\.ssh/?$',
        r'\.gnupg/?$',
        r'\.kube/?$',
        r'\.docker/?$',
        r'\.password-store/?$',
    ]

    for pattern in sensitive_dirs:
        if re.search(pattern, path_lower):
            return True, f"Blocked: searching in sensitive directory '{resolved_path}'"

    return False, None


def check_file_access(data: dict) -> tuple[str, str | None]:
    """
    Check if a file tool operation should be allowed.

    Args:
        data: The hook input data containing tool_name and tool_input

    Returns:
        (decision, reason) tuple where decision is "allow", "block", or "deny"
    """
    tool_name = data.get("tool_name", "")

    # Only check file-related tools
    if tool_name not in ("Read", "Write", "Edit", "Grep", "NotebookEdit"):
        return "allow", None

    tool_input = data.get("tool_input", {})
    file_path = extract_path_from_tool(tool_name, tool_input)

    if not file_path:
        return "allow", None

    # For Grep, the path can be a directory - check both file and directory
    if tool_name == "Grep":
        is_sensitive, reason = check_directory_for_sensitive_files(file_path)
    else:
        is_sensitive, reason = is_sensitive_file(file_path)

    if is_sensitive:
        # Log security event: sensitive file access denied
        if SECURITY_AUDIT_AVAILABLE:
            audit_hook_deny(tool_name, file_path, reason or "sensitive file")
            audit_secret_access_attempt(tool_name, file_path)

        full_reason = (
            f"{reason}\n\n"
            "This hook prevents access to sensitive files that may contain:\n"
            "  - API keys and secrets (.env, credentials.json)\n"
            "  - Cryptographic keys (*.pem, *.key, id_rsa)\n"
            "  - Cloud credentials (.aws/credentials, .kube/config)\n"
            "  - Authentication tokens (.npmrc, .pypirc, .netrc)\n\n"
            "NOTE: Symlink bypass is blocked - both original and resolved paths are checked.\n\n"
            "If you need to work with these files:\n"
            "  1. Use environment variables instead of reading files directly\n"
            "  2. Ask the user to provide specific non-sensitive values\n"
            "  3. Use the `env-safe` command to safely inspect .env files"
        )
        return "block", full_reason

    return "allow", None


# ============================================================================
# MAIN EXECUTION
# ============================================================================

def run_with_threading_timeout(func, timeout_seconds: int):
    """
    Run a function with threading-based timeout (for Windows compatibility).

    Args:
        func: Function to run (must return (result, error) tuple)
        timeout_seconds: Timeout in seconds

    Returns:
        (result, error, timed_out) tuple
    """
    result = [None, None, False]  # [return_value, exception, timed_out]

    def target():
        try:
            result[0] = func()
        except Exception as e:
            result[1] = e

    thread = threading.Thread(target=target)
    thread.daemon = True
    thread.start()
    thread.join(timeout=timeout_seconds)

    if thread.is_alive():
        result[2] = True  # Timed out

    return result[0], result[1], result[2]


def main():
    """Main entry point with timeout and fail-closed error handling."""

    # Determine timeout mechanism based on platform
    # Unix: use SIGALRM (more reliable for I/O operations)
    # Windows: use threading-based timeout
    is_windows = platform.system() == 'Windows'
    has_alarm = hasattr(signal, 'SIGALRM') and not is_windows

    if has_alarm:
        # Unix: Set up signal-based timeout
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(HOOK_TIMEOUT)

    try:
        if is_windows:
            # Windows: Use threading-based timeout
            def do_check():
                data = json.load(sys.stdin)
                return check_file_access(data)

            result, error, timed_out = run_with_threading_timeout(do_check, HOOK_TIMEOUT)

            if timed_out:
                raise TimeoutError("Hook execution timed out")
            if error:
                raise error
            decision, reason = result
        else:
            # Unix: Direct execution with signal timeout
            data = json.load(sys.stdin)
            decision, reason = check_file_access(data)

        if decision == "block":
            # Use hookSpecificOutput format for proper deny
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason
                }
            }, ensure_ascii=False))
        else:
            print(json.dumps({"decision": "approve"}))

        sys.exit(0)

    except TimeoutError:
        # Log security event: timeout
        if SECURITY_AUDIT_AVAILABLE:
            audit_hook_timeout('file_access', HOOK_TIMEOUT)

        # FAIL-CLOSED: Timeout means DENY
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "File access hook timed out (fail-closed).\n\n"
                    "The hook could not complete within the time limit. "
                    "For security, access is denied when the hook cannot verify safety.\n\n"
                    "This may happen with:\n"
                    "  - Very deep symlink chains\n"
                    "  - Network-mounted filesystems\n"
                    "  - System under heavy load"
                )
            }
        }, ensure_ascii=False))
        sys.exit(0)

    except json.JSONDecodeError as e:
        # Log security event: parse error
        if SECURITY_AUDIT_AVAILABLE:
            audit_hook_error('file_access', f'JSON parse error: {e}')

        # FAIL-CLOSED: Invalid input means DENY
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"File access hook received invalid JSON (fail-closed): {e}\n\n"
                    "For security, access is denied when the hook cannot parse the request."
                )
            }
        }, ensure_ascii=False))
        sys.exit(0)

    except Exception as e:
        # Log security event: unexpected error
        if SECURITY_AUDIT_AVAILABLE:
            audit_hook_error('file_access', str(e))

        # FAIL-CLOSED: Any unexpected error means DENY
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"File access hook encountered an error (fail-closed): {e}\n\n"
                    "For security, access is denied when the hook cannot verify safety.\n"
                    "Please report this error if it persists."
                )
            }
        }, ensure_ascii=False))
        sys.exit(0)

    finally:
        # Cancel the alarm (Unix only)
        if has_alarm:
            signal.alarm(0)


if __name__ == "__main__":
    main()
