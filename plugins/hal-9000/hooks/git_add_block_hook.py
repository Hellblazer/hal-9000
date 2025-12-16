#!/usr/bin/env python3
import re
import os
import subprocess
from pathlib import Path

def check_git_add_command(command):
    """
    Check if a git add command contains dangerous patterns.
    Returns tuple: (decision, reason) where decision is bool or "ask"/"block"/"allow"
    """
    # Normalize the command - handle multiple spaces, tabs, etc.
    normalized_cmd = ' '.join(command.strip().split())

    # Always allow --dry-run (used internally to detect what would be staged)
    if '--dry-run' in normalized_cmd or '-n' in normalized_cmd.split():
        return False, None

    # Pattern to match git add with problematic flags and dangerous patterns
    # Check for wildcards or dangerous patterns anywhere in the arguments
    if '*' in normalized_cmd and normalized_cmd.startswith('git add'):
        reason = """BLOCKED: Wildcard patterns are not allowed in git add!
        
DO NOT use wildcards like 'git add *.py' or 'git add *'

Instead, use:
- 'git add <specific-files>' to stage specific files
- 'git ls-files -m "*.py" | xargs git add' if you really need pattern matching

This restriction prevents accidentally staging unwanted files."""
        return True, reason
    
    # Hard block patterns: -A, --all, -a, ., ../, etc.
    dangerous_pattern = re.compile(
        r'^git\s+add\s+(?:.*\s+)?('
        r'-[a-zA-Z]*[Aa][a-zA-Z]*(\s|$)|'  # Flags containing 'A' or 'a'
        r'--all(\s|$)|'                     # Long form --all
        r'\.(\s|$)|'                        # git add . (current directory)
        r'\.\./[\.\w/]*(\s|$)'             # git add ../ or ../.. patterns
        r')', re.IGNORECASE
    )
    
    if dangerous_pattern.search(normalized_cmd):
        reason = """BLOCKED: Dangerous git add pattern detected!
        
DO NOT use:
- 'git add -A', 'git add -a', 'git add --all' (adds ALL files)
- 'git add .' (adds entire current directory)
- 'git add ../' or similar parent directory patterns
- 'git add *' (wildcard patterns)

Instead, use:
- 'git add <specific-files>' to stage specific files
- 'git add <specific-directory>/' to stage a specific directory (with confirmation)
- 'git add -u' to stage all modified/deleted files (but not untracked)

This restriction prevents accidentally staging unwanted files."""
        return True, reason
    
    # Check for git add with a directory
    # Match: git add <dirname>/ or git add <path/to/dir>/
    directory_pattern = re.compile(r'^git\s+add\s+(?!-)[^\s]+/$')
    match = directory_pattern.search(normalized_cmd)

    if match:
        # Extract the directory path from the command
        parts = normalized_cmd.split()
        dir_path = None
        for i, part in enumerate(parts):
            if i > 0 and parts[i-1] == 'add' and part.endswith('/'):
                dir_path = part.rstrip('/')
                break

        if dir_path:
            # Use dry-run to get files that would be staged
            try:
                result = subprocess.run(
                    ['git', 'add', '--dry-run', dir_path + '/'],
                    capture_output=True, text=True, cwd=os.getcwd()
                )
                # Parse dry-run output: "add 'filename'" lines
                files = []
                for line in result.stdout.strip().split('\n'):
                    if line.startswith('add '):
                        # Extract filename from "add 'filename'"
                        fname = line[4:].strip().strip("'")
                        files.append(fname)

                if not files:
                    # No files to stage
                    return False, None

                # Check which files are modified vs new
                modified_files = []
                new_files = []
                for f in files:
                    status_result = subprocess.run(
                        ['git', 'status', '--porcelain', f],
                        capture_output=True, text=True, cwd=os.getcwd()
                    )
                    status = status_result.stdout.strip()
                    if status:
                        status_code = status[:2]
                        if '?' in status_code:
                            new_files.append(f)
                        else:
                            modified_files.append(f)

                # If only new files, allow without permission
                if not modified_files:
                    return False, None

                # Modified files present - ask for permission
                file_list = ", ".join(modified_files[:5])
                if len(modified_files) > 5:
                    file_list += f" (+{len(modified_files) - 5} more)"
                reason = f"Staging directory {dir_path}/ with modified files: {file_list}"
                return "ask", reason

            except Exception:
                # If dry-run fails, fall back to asking permission
                reason = f"Staging directory {dir_path}/ (couldn't verify file status)"
                return "ask", reason
    
    # Also check for git commit -a without -m (which would open an editor)
    # Check if command has -a flag but no -m flag
    if re.search(r'^git\s+commit\s+', normalized_cmd):
        has_a_flag = re.search(r'-[a-zA-Z]*a[a-zA-Z]*', normalized_cmd)
        has_m_flag = re.search(r'-[a-zA-Z]*m[a-zA-Z]*', normalized_cmd)
        if has_a_flag and not has_m_flag:
            reason = """Avoid 'git commit -a' without a message flag. Use 'gcam "message"' instead, which is an alias for 'git commit -a -m'."""
            return True, reason

    # Check if staging modified files (not new/untracked) - requires permission
    # This check runs after all blocking patterns pass
    if normalized_cmd.startswith('git add'):
        modified_files = get_modified_files_being_staged(normalized_cmd)
        if modified_files:
            file_list = ", ".join(modified_files[:5])
            if len(modified_files) > 5:
                file_list += f" (+{len(modified_files) - 5} more)"
            reason = f"Staging modified files: {file_list}"
            return "ask", reason

    return False, None


def get_modified_files_being_staged(command):
    """
    Extract files from git add command and return those that are modified
    (not new/untracked). Returns empty list if only staging new files.
    """
    parts = command.split()
    if len(parts) < 3 or parts[0] != 'git' or parts[1] != 'add':
        return []

    # Extract file arguments (skip 'git add' and any flags)
    files = []
    for part in parts[2:]:
        if not part.startswith('-'):
            files.append(part)

    if not files:
        return []

    modified_files = []
    for f in files:
        try:
            # Check git status for this file
            result = subprocess.run(
                ['git', 'status', '--porcelain', f],
                capture_output=True, text=True, cwd=os.getcwd()
            )
            status = result.stdout.strip()
            if status:
                # Status codes: ?? = untracked, M = modified, A = staged
                # We want to flag modified files (not untracked)
                status_code = status[:2]
                if '?' not in status_code:  # Not untracked = modified/staged
                    modified_files.append(f)
        except Exception:
            pass

    return modified_files


# If run as a standalone script
if __name__ == "__main__":
    import json
    import sys
    
    data = json.load(sys.stdin)
    
    # Check if this is a Bash tool call
    tool_name = data.get("tool_name")
    if tool_name != "Bash":
        print(json.dumps({"decision": "approve"}))
        sys.exit(0)
    
    # Get the command being executed
    command = data.get("tool_input", {}).get("command", "")
    
    should_block, reason = check_git_add_command(command)
    
    if should_block:
        print(json.dumps({
            "decision": "block",
            "reason": reason
        }))
    else:
        print(json.dumps({"decision": "approve"}))
    
    sys.exit(0)