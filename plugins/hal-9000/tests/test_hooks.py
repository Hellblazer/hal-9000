#!/usr/bin/env python3
"""
Pytest unit tests for Claude Code safety hooks.

Run with: pytest tests/test_hooks.py -v
"""
import sys
import os

# Add hooks directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'hooks'))

from git_add_block_hook import check_git_add_command
from git_checkout_safety_hook import check_git_checkout_command
from git_commit_block_hook import check_git_commit_command
from rm_block_hook import check_rm_command
from env_file_protection_hook import check_env_file_access
from file_length_limit_hook import is_source_code_file, count_lines_in_content


class TestGitAddBlockHook:
    """Tests for git add blocking hook."""

    def test_allow_specific_file(self):
        """Specific file paths should be allowed."""
        decision, reason = check_git_add_command("git add src/main.py")
        # May return "ask" if file is modified, "allow" otherwise
        assert decision in ("allow", "ask")

    def test_block_wildcard(self):
        """Wildcard patterns should be blocked."""
        decision, reason = check_git_add_command("git add *.py")
        assert decision == "block"
        assert "wildcard" in reason.lower()

    def test_block_git_add_all(self):
        """git add --all should be blocked."""
        decision, reason = check_git_add_command("git add --all")
        assert decision == "block"

    def test_block_git_add_A(self):
        """git add -A should be blocked."""
        decision, reason = check_git_add_command("git add -A")
        assert decision == "block"

    def test_block_git_add_dot(self):
        """git add . should be blocked."""
        decision, reason = check_git_add_command("git add .")
        assert decision == "block"

    def test_allow_dry_run(self):
        """Dry-run commands should be allowed."""
        decision, reason = check_git_add_command("git add --dry-run .")
        assert decision == "allow"

    def test_block_parent_directory(self):
        """Parent directory patterns should be blocked."""
        decision, reason = check_git_add_command("git add ../")
        assert decision == "block"

    def test_allow_specific_directory(self):
        """Specific directory with trailing slash is allowed (may ask)."""
        decision, reason = check_git_add_command("git add src/")
        assert decision in ("allow", "ask")


class TestGitCheckoutSafetyHook:
    """Tests for git checkout safety hook."""

    def test_allow_create_branch(self):
        """Creating a new branch should be allowed."""
        decision, reason = check_git_checkout_command("git checkout -b new-feature")
        assert decision == "allow"

    def test_allow_help(self):
        """Help command should be allowed."""
        decision, reason = check_git_checkout_command("git checkout --help")
        assert decision == "allow"

    def test_block_force_checkout(self):
        """Force checkout should be blocked."""
        decision, reason = check_git_checkout_command("git checkout -f main")
        assert decision == "block"
        assert "force" in reason.lower() or "dangerous" in reason.lower()

    def test_block_checkout_dot(self):
        """git checkout . should be blocked."""
        decision, reason = check_git_checkout_command("git checkout .")
        assert decision == "block"

    def test_non_checkout_command(self):
        """Non-checkout commands should be allowed."""
        decision, reason = check_git_checkout_command("git status")
        assert decision == "allow"


class TestGitCommitBlockHook:
    """Tests for git commit hook."""

    def test_ask_permission_for_commit(self):
        """Commits should ask for permission."""
        decision, reason = check_git_commit_command("git commit -m 'test'")
        assert decision == "ask"

    def test_allow_non_commit(self):
        """Non-commit commands should be allowed."""
        decision, reason = check_git_commit_command("git status")
        assert decision == "allow"


class TestRmBlockHook:
    """Tests for rm command blocking hook."""

    def test_block_rm_command(self):
        """rm commands should be blocked."""
        decision, reason = check_rm_command("rm file.txt")
        assert decision == "block"
        assert "trash" in reason.lower()

    def test_block_rm_recursive(self):
        """rm -rf should be blocked."""
        decision, reason = check_rm_command("rm -rf directory/")
        assert decision == "block"

    def test_allow_non_rm(self):
        """Non-rm commands should be allowed."""
        decision, reason = check_rm_command("mv file.txt backup/")
        assert decision == "allow"

    def test_block_rm_in_chain(self):
        """rm in command chain should be blocked."""
        decision, reason = check_rm_command("ls && rm file.txt")
        assert decision == "block"


class TestEnvFileProtectionHook:
    """Tests for .env file protection hook."""

    def test_block_cat_env(self):
        """cat .env should be blocked."""
        decision, reason = check_env_file_access("cat .env")
        assert decision == "block"

    def test_block_grep_env(self):
        """grep on .env should be blocked."""
        decision, reason = check_env_file_access("grep API_KEY .env")
        assert decision == "block"

    def test_block_vim_env(self):
        """vim .env should be blocked."""
        decision, reason = check_env_file_access("vim .env")
        assert decision == "block"

    def test_block_write_to_env(self):
        """Writing to .env should be blocked."""
        decision, reason = check_env_file_access("echo 'KEY=value' >> .env")
        assert decision == "block"

    def test_allow_non_env_file(self):
        """Non-.env files should be allowed."""
        decision, reason = check_env_file_access("cat config.json")
        assert decision == "allow"

    def test_allow_similar_name(self):
        """Files with 'env' in name but not .env should be allowed."""
        decision, reason = check_env_file_access("cat environment.txt")
        assert decision == "allow"

    def test_block_source_env(self):
        """source .env should be blocked."""
        decision, reason = check_env_file_access("source .env")
        assert decision == "block"

    def test_block_dot_source_env(self):
        """. .env (dot-source) should be blocked."""
        decision, reason = check_env_file_access(". .env")
        assert decision == "block"


class TestFileLengthLimit:
    """Tests for file length limit utilities."""

    def test_is_source_code_file_python(self):
        """Python files should be detected as source code."""
        assert is_source_code_file("main.py") is True
        assert is_source_code_file("/path/to/main.py") is True

    def test_is_source_code_file_typescript(self):
        """TypeScript files should be detected as source code."""
        assert is_source_code_file("component.tsx") is True
        assert is_source_code_file("utils.ts") is True

    def test_is_source_code_file_java(self):
        """Java files should be detected as source code."""
        assert is_source_code_file("Main.java") is True

    def test_not_source_code_file(self):
        """Non-source files should not be detected."""
        assert is_source_code_file("README.md") is False
        assert is_source_code_file("config.json") is False
        assert is_source_code_file("data.csv") is False

    def test_empty_path(self):
        """Empty path should return False."""
        assert is_source_code_file("") is False
        assert is_source_code_file(None) is False

    def test_count_lines_empty(self):
        """Empty content should have 0 lines."""
        assert count_lines_in_content("") == 0
        assert count_lines_in_content(None) == 0

    def test_count_lines_simple(self):
        """Simple content should count correctly."""
        assert count_lines_in_content("line1\nline2\nline3") == 3

    def test_count_lines_trailing_newline(self):
        """Trailing newline handling."""
        assert count_lines_in_content("line1\n") == 1


class TestDecisionFormat:
    """Tests to verify all hooks return consistent decision format."""

    def test_git_add_returns_tuple(self):
        """git_add hook should return (decision, reason) tuple."""
        result = check_git_add_command("git add file.txt")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert result[0] in ("allow", "ask", "block")

    def test_git_checkout_returns_tuple(self):
        """git_checkout hook should return (decision, reason) tuple."""
        result = check_git_checkout_command("git checkout main")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert result[0] in ("allow", "ask", "block")

    def test_git_commit_returns_tuple(self):
        """git_commit hook should return (decision, reason) tuple."""
        result = check_git_commit_command("git commit -m 'test'")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert result[0] in ("allow", "ask", "block")

    def test_rm_returns_tuple(self):
        """rm hook should return (decision, reason) tuple."""
        result = check_rm_command("rm file.txt")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert result[0] in ("allow", "ask", "block")

    def test_env_returns_tuple(self):
        """env hook should return (decision, reason) tuple."""
        result = check_env_file_access("cat .env")
        assert isinstance(result, tuple)
        assert len(result) == 2
        assert result[0] in ("allow", "ask", "block")


if __name__ == "__main__":
    import pytest
    pytest.main([__file__, "-v"])
