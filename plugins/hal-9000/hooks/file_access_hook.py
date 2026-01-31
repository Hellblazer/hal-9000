#!/usr/bin/env python3
"""
File Access Hook - Blocks access to sensitive files via Read, Write, Edit tools.

SECURITY: Uses os.path.realpath() to resolve symlinks, preventing bypass attacks.
Checks BOTH the original requested path AND the resolved path.

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
import re
import signal
import sys
from pathlib import Path


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
    if original_path == resolved_path:
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


def check_file_access(data: dict) -> tuple[str, str | None]:
    """
    Check if a file tool operation should be allowed.

    Args:
        data: The hook input data containing tool_name and tool_input

    Returns:
        (decision, reason) tuple where decision is "allow", "block", or "deny"
    """
    tool_name = data.get("tool_name", "")

    # Only check Read, Write, Edit tools
    if tool_name not in ("Read", "Write", "Edit"):
        return "allow", None

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        return "allow", None

    # Check if the file is sensitive
    is_sensitive, reason = is_sensitive_file(file_path)

    if is_sensitive:
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

def main():
    """Main entry point with timeout and fail-closed error handling."""

    # Set up timeout handler (Unix only)
    # On Windows, signal.SIGALRM doesn't exist, so we skip timeout handling
    has_alarm = hasattr(signal, 'SIGALRM')
    if has_alarm:
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(HOOK_TIMEOUT)

    try:
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
        # Cancel the alarm
        if has_alarm:
            signal.alarm(0)


if __name__ == "__main__":
    main()
