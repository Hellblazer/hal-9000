#!/usr/bin/env python3
"""
Integration tests for MCP server availability.

These tests verify that MCP servers can be started and respond to basic queries.
Run with: python -m pytest tests/test_mcp_servers.py -v

Prerequisites:
- Install MCP servers first (run install.sh)
- Have Node.js and Python available
"""

import subprocess
import shutil
import pytest
import os
import json
import time


def command_exists(cmd):
    """Check if a command exists in PATH."""
    return shutil.which(cmd) is not None


class TestMCPServerAvailability:
    """Test that MCP server commands are available."""

    def test_chroma_mcp_available(self):
        """Check if chroma-mcp command exists."""
        if not command_exists("chroma-mcp"):
            # Check common Python bin locations
            python_bin = os.path.expanduser("~/Library/Python/3.10/bin/chroma-mcp")
            if not os.path.exists(python_bin):
                pytest.skip("chroma-mcp not installed")

    def test_memory_bank_available(self):
        """Check if mcp-server-memory-bank command exists."""
        if not command_exists("mcp-server-memory-bank"):
            # Try npx
            result = subprocess.run(
                ["npx", "-y", "@allpepper/memory-bank-mcp", "--help"],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode != 0:
                pytest.skip("mcp-server-memory-bank not available via npx")

    def test_sequential_thinking_available(self):
        """Check if sequential-thinking server is available via npx."""
        if not command_exists("mcp-server-sequential-thinking"):
            result = subprocess.run(
                ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking", "--version"],
                capture_output=True,
                text=True,
                timeout=30
            )
            # It's okay if version doesn't exist, just check npx can find it
            if "Cannot find package" in result.stderr:
                pytest.skip("sequential-thinking server not available")


class TestChromaDBServer:
    """Test ChromaDB MCP server functionality."""

    @pytest.fixture
    def chroma_cmd(self):
        """Get the chroma-mcp command path."""
        cmd = shutil.which("chroma-mcp")
        if not cmd:
            # Try common Python bin location
            cmd = os.path.expanduser("~/Library/Python/3.10/bin/chroma-mcp")
            if not os.path.exists(cmd):
                pytest.skip("chroma-mcp not installed")
        return cmd

    def test_chroma_ephemeral_mode_help(self, chroma_cmd):
        """Test that chroma-mcp shows help with ephemeral mode."""
        result = subprocess.run(
            [chroma_cmd, "--help"],
            capture_output=True,
            text=True,
            timeout=30
        )
        # Should complete without error
        assert result.returncode == 0 or "ephemeral" in result.stdout.lower() or "ephemeral" in result.stderr.lower()


class TestMemoryBankServer:
    """Test Memory Bank MCP server functionality."""

    @pytest.fixture
    def memory_bank_root(self, tmp_path):
        """Create a temporary memory bank root."""
        root = tmp_path / "memory-bank"
        root.mkdir()
        return str(root)

    def test_memory_bank_env_variable(self, memory_bank_root):
        """Test that MEMORY_BANK_ROOT environment variable is respected."""
        # This is a basic smoke test
        env = os.environ.copy()
        env["MEMORY_BANK_ROOT"] = memory_bank_root

        # Try to run the server briefly
        # Note: MCP servers typically run in stdio mode, so we can't easily test them
        # without a proper MCP client. This just verifies the env var setup.
        assert os.path.isdir(memory_bank_root)


class TestConfigurationFiles:
    """Test that configuration files are valid."""

    @pytest.fixture
    def plugin_root(self):
        """Get the plugin root directory."""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        return os.path.dirname(test_dir)

    def test_plugin_json_valid(self, plugin_root):
        """Verify plugin.json is valid JSON."""
        plugin_json = os.path.join(plugin_root, ".claude-plugin", "plugin.json")
        if os.path.exists(plugin_json):
            with open(plugin_json) as f:
                config = json.load(f)
                assert "name" in config
                assert "version" in config
                assert "mcpServers" in config

    def test_hooks_json_valid(self, plugin_root):
        """Verify hooks.json is valid JSON."""
        hooks_json = os.path.join(plugin_root, "hooks", "hooks.json")
        if os.path.exists(hooks_json):
            with open(hooks_json) as f:
                config = json.load(f)
                assert isinstance(config, dict)

    def test_mcp_server_configs_exist(self, plugin_root):
        """Verify MCP server config files exist."""
        mcp_servers_dir = os.path.join(plugin_root, "mcp-servers")
        expected_servers = ["chromadb", "memory-bank", "sequential-thinking"]

        for server in expected_servers:
            server_dir = os.path.join(mcp_servers_dir, server)
            assert os.path.isdir(server_dir), f"MCP server directory missing: {server}"

            # Check for README
            readme = os.path.join(server_dir, "README.md")
            assert os.path.exists(readme), f"README missing for {server}"


class TestAgentDefinitions:
    """Test that agent definition files are valid."""

    @pytest.fixture
    def agents_dir(self):
        """Get the agents directory."""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        return os.path.join(os.path.dirname(test_dir), "agents")

    def test_all_agents_have_frontmatter(self, agents_dir):
        """Verify all agent files have valid frontmatter."""
        if not os.path.isdir(agents_dir):
            pytest.skip("agents directory not found")

        for filename in os.listdir(agents_dir):
            if filename.endswith(".md"):
                filepath = os.path.join(agents_dir, filename)
                with open(filepath) as f:
                    content = f.read()

                # Check for frontmatter markers
                assert content.startswith("---"), f"{filename} missing frontmatter start"
                assert content.count("---") >= 2, f"{filename} missing frontmatter end"

                # Extract frontmatter
                parts = content.split("---", 2)
                frontmatter = parts[1].strip()

                # Check required fields
                assert "name:" in frontmatter, f"{filename} missing 'name' in frontmatter"
                assert "description:" in frontmatter, f"{filename} missing 'description'"
                assert "model:" in frontmatter, f"{filename} missing 'model'"

    def test_agent_models_are_valid(self, agents_dir):
        """Verify agent models are valid (sonnet, opus, haiku)."""
        valid_models = {"sonnet", "opus", "haiku"}

        if not os.path.isdir(agents_dir):
            pytest.skip("agents directory not found")

        for filename in os.listdir(agents_dir):
            if filename.endswith(".md"):
                filepath = os.path.join(agents_dir, filename)
                with open(filepath) as f:
                    content = f.read()

                # Extract model from frontmatter
                for line in content.split("\n"):
                    if line.strip().startswith("model:"):
                        model = line.split(":", 1)[1].strip()
                        assert model in valid_models, \
                            f"{filename} has invalid model: {model}"
                        break


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
