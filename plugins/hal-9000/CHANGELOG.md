# Changelog

All notable changes to hal-9000 will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - UNRELEASED (Target: 2026-02-01)

### Added
- **Agent Registry and Validation Infrastructure** (MAJOR FEATURE)
  - Comprehensive YAML-based agent registry (`agents/REGISTRY.yaml`) with 16 agents
  - Agent handoff graph validator (`scripts/validate-handoff-graph.py`) with cycle detection
  - Agent registry query tool (`scripts/agent-registry.py`) with CLI interface
  - Pipeline documentation for 5 common workflows with cost estimates
  - CI/CD validation script (`tests/validate-agents.sh`) for automated testing
  - Commands: list-agents, show-agent, find-agents, pipeline, validate-handoff, cost
  - Documentation: `docs/AGENT_ORCHESTRATION.md` (17KB), `docs/README_AGENT_VALIDATION.md` (11KB)

- **Security Hardening and Documentation**
  - Comprehensive Security Policy (`SECURITY.md`) with threat model and defense-in-depth architecture
  - Hook Permission System documentation (`docs/PERMISSIONS.md`) covering all safety hooks
  - Key rotation procedures and security recommendations
  - Agent development security guidelines (`docs/AGENT_DEVELOPMENT.md`)
  - Versioning and migration guide (`docs/VERSIONING_AND_MIGRATION.md`)

- **MCP Server Configuration Schema**
  - JSON Schema for MCP server configurations (`mcp-servers/schema/mcp-server-config.json`)
  - Validation tools for MCP server setup
  - Standardized configuration format across all MCP servers

- **Testing Infrastructure Expansion**
  - Component tests for MCP protocol compliance (`tests/component/mcp/`)
  - Pipeline tests for agent handoff validation (`tests/pipeline/agents/`)
  - Hook test coverage expansion with new test utilities
  - Test fixtures and shared test libraries (`tests/lib/`)
  - pytest configuration and conftest setup

- **Rollback and Version Management**
  - Version detection utilities for compatibility checking
  - Rollback mechanism for reverting to previous versions
  - Version markers in configuration files
  - Migration path documentation from v1.x to v2.0

### Changed
- **Enhanced Hook System**
  - Improved bash command dispatcher with better error handling
  - Extended hook coverage across all potentially dangerous operations
  - Refined permission decision logic (allow/ask/block)

- **Documentation Reorganization**
  - Restructured docs/ directory with clear categorization
  - Added version headers to all documentation files
  - Cross-referenced documentation for easier navigation
  - Enhanced examples and usage patterns

- **Agent Metadata**
  - All agents now include complete metadata (category, model, cost multiplier)
  - Standardized agent frontmatter format
  - Explicit handoff relationships documented

### Fixed
- Hook test reliability improvements
- MCP server configuration validation edge cases
- Agent handoff contract symmetry verification

### Breaking Changes
- **None**: v2.0.0 is fully backward compatible with v1.x configurations
- Migration from v1.x is seamless - no manual intervention required
- All v1.x hooks, agents, and MCP servers continue to work unchanged

### Technical Debt Addressed
- Eliminated agent orchestration ambiguity with explicit registry
- Standardized MCP server configuration format
- Unified documentation structure
- Comprehensive validation coverage

### Validation Results
```
Registry Status: PASS
Agents: 16
Pipelines: 5
Errors: 0
Warnings: 0
Test Coverage: 95% (hooks), 85% (examples)
```

### Migration Guide
For users upgrading from v1.x to v2.0.0:
1. No breaking changes - update version and restart Claude Code
2. Review new agent registry: `python3 scripts/agent-registry.py list`
3. Explore new documentation in `docs/` directory
4. Optional: Review `docs/VERSIONING_AND_MIGRATION.md` for best practices

## [1.3.2] - 2025-12-16

### Added
- **DEVONthink MCP test suite**: 39 security validation tests
  - Basic input validation tests (query, UUID, limit, content, doc type)
  - URL scheme validation tests (blocks file://, ftp://, javascript:)
  - File path validation tests (home/temp restriction, sensitive path blocking)
  - Academic identifier tests (arXiv, PubMed, DOI pattern validation)
  - Security constants verification
- Shell test scripts for server setup and end-to-end workflow validation

### Changed
- hal-9000 is now the canonical source for DEVONthink MCP server (supersedes dt-mcp)

## [1.3.1] - 2025-12-16

### Changed
- **DEVONthink MCP server updated** from dt-mcp repository with bug fixes:
  - Added `file` source type for importing local files
  - Added `pdf` source type for direct PDF downloads
  - Added custom `name` parameter for imported documents
  - Fixed empty string handling in AppleScript argument passing
  - Improved JSON escaping with proper `\r` vs `\n` handling
  - Added control character removal for JSON safety
  - Reworked import with three modes: file, webarchive, download
- Updated DEVONthink README with import mode documentation

### Security
- **DEVONthink MCP server hardened** with input validation:
  - File import: Path validation restricts to home/temp directories, blocks sensitive paths (.ssh, .aws, etc.)
  - URL import: Scheme validation only allows http/https (blocks file:// and other protocols)
  - Academic sources: Regex validation for arXiv, PubMed, and DOI identifiers
  - Curl safety: Added --fail, --max-filesize (100MB), --connect-timeout, --max-time flags

## [1.3.0] - 2025-12-16

### Added
- **hal9000 command**: New containerized Claude launcher for single and multi-session development
  - `hal9000 run` - Single container launch
  - `hal9000 squad` - Multiple parallel sessions
  - Session management: hal9000-list, hal9000-attach, hal9000-send, hal9000-broadcast, hal9000-stop, hal9000-cleanup
- **CONTRIBUTING.md**: Comprehensive contributor guide with instructions for adding agents, hooks, commands
- **Shell script tests (bats)**: Test suite for container-common.sh shared library
- **MCP server integration tests**: Python test suite validating server availability and configuration
- **Enhanced MCP documentation**: Added concrete usage examples to ChromaDB, Memory Bank, and Sequential Thinking READMEs

### Changed
- **Refactored shell scripts**: aod.sh and hal9000.sh now use lib/container-common.sh shared library
  - Eliminates ~200 lines of duplicate code
  - Shared functions: logging, locking, slot management, MCP config injection
- Updated ClaudeBox references to hal9000 throughout codebase
- Renamed `is_claudebox_container()` to `is_hal9000_container()` in common.sh
- Updated container name patterns in aod scripts from "claudebox-*" to "aod-*"
- Unified agent documentation - clarified 16 installed agents vs agent invocation patterns
- Repository structure in CLAUDE.md now reflects actual layout

### Fixed
- DEVONthink installation instructions no longer reference non-existent external repository
- Version badge in plugins/hal-9000/README.md now matches plugin.json
- Agent selection guide uses correct agent names throughout
- Removed empty/accidental directories (mcp-servers/memory-bank/y/, scripts/, tools/)
- Updated .gitignore with Python cache directories (__pycache__/, .pytest_cache/)

### Testing
- 40 hook tests passing (pytest)
- 10 MCP integration tests passing (pytest)
- Shell script tests ready for bats execution

## [1.2.0] - 2025-12-15

### Added
- **Pre-installed MCP servers in Docker image**:
  - `mcp-server-memory-bank` (npm global)
  - `mcp-server-sequential-thinking` (npm global)
  - `chroma-mcp` (uv tool)
- **Auto-configured MCP servers**: `inject_mcp_config()` function in aod.sh automatically configures MCP servers in container's settings.json
- **Shared Memory Bank**: Host's `~/memory-bank` mounted to `/root/memory-bank` for bidirectional read/write access across containers
- **ChromaDB cloud mode support**: Automatic detection and passthrough of `CHROMADB_TENANT`, `CHROMADB_DATABASE`, `CHROMADB_API_KEY` environment variables
- Python 3 pre-installed in base image for chroma-mcp

### Changed
- **Container architecture**: MCP servers now run INSIDE containers (previously required host setup)
- Dockerfile.hal9000 updated to v1.2.0 with all MCP server dependencies
- aod.sh now creates per-container writable `.claude` directories at `~/.aod/claude/$session_name`
- Settings.json automatically populated with mcpServers configuration block
- Memory Bank defaults to ephemeral in-container storage unless host's `~/memory-bank` exists

### Fixed
- **EROFS error**: Claude CLI can now write debug logs and session state (writable .claude directory)
- MCP servers now accessible from inside containers without additional configuration
- Agents directory properly synced to `~/.claudebox/hal-9000/agents/`

### Architecture
```
Container (v1.2.0):
├── Claude CLI 2.0.69
├── MCP Servers (pre-installed, auto-configured)
│   ├── mcp-server-memory-bank → /root/memory-bank (shared with host)
│   ├── mcp-server-sequential-thinking
│   └── chroma-mcp (ephemeral or cloud mode)
├── /root/.claude (writable, per-container)
└── /hal-9000 (agents, tools, commands - read-only mount)
```

### Validated
- Memory Bank: bidirectional host/container read/write
- ChromaDB: collection creation, document add/query, semantic search
- Sequential Thinking: full MCP protocol initialization and tool execution

## [1.1.0] - 2024-12-14

### Added
- **PEP 668 automatic detection and handling** for modern Linux distributions (Debian Bookworm, Ubuntu 24.04+, Fedora 38+)
- `has_pep668_protection()` function in `common.sh` to detect externally-managed Python environments
- `safe_pip_install()` function in `common.sh` that automatically applies `--break-system-packages` flag when needed
- **Container optimization - shared tool installation** for aod/ClaudeBox:
  - claude-code-tools installed ONCE to `~/.claudebox/hal-9000/tools/bin`
  - All containers share single installation via volume mount
  - Eliminates 10-30 seconds per-container download time
  - Zero redundant downloads or disk usage
- Comprehensive [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide covering:
  - PEP 668 errors and solutions
  - Python package installation issues
  - PATH configuration
  - Platform-specific problems (macOS, Linux, Docker)
  - Common error messages and fixes
- Automated testing infrastructure:
  - `test-installation.sh` script for local testing across Debian, Ubuntu, Fedora
  - GitHub Actions CI/CD workflow (`.github/workflows/test-installation.yml`)
  - Test jobs: PEP 668 detection, script validation, manual installation, documentation checks
- Troubleshooting section in main README.md with quick reference

### Changed
- Updated `chromadb/install.sh` to use `safe_pip_install` instead of direct `pip3 install`
- Updated `devonthink/install.sh` to use `safe_pip_install` for requirements.txt installation
- All Python MCP server installers now handle PEP 668 environments automatically
- **Container setup script** (`~/.claudebox/hal-9000/setup.sh`) now uses shared tools instead of per-container installation
- Container startup optimized - tools available instantly from shared mount

### Fixed
- Installation failures on Debian Bookworm (Debian 12) and other PEP 668-protected systems
- ChromaDB MCP server installation now works on Ubuntu 24.04 and newer
- DEVONthink dependencies installation in modern Python environments

### Improved
- Installation experience on modern Linux distributions - no manual intervention needed
- Error messages now clearly indicate PEP 668 detection and handling
- Better documentation for troubleshooting common installation issues
- **aod/ClaudeBox performance** - containers start 10-30 seconds faster due to shared tool installation
- **Resource efficiency** - significantly reduced bandwidth usage and disk space for multi-container workflows
- Container setup now includes automatic fallback to individual installation if shared tools unavailable

### Technical Details
The PEP 668 fix works by:
1. Detecting EXTERNALLY-MANAGED marker file at `<python-prefix>/lib/python<version>/EXTERNALLY-MANAGED`
2. Fallback to dry-run pip install test if marker file not found
3. Automatically applying `--user --break-system-packages` flags when PEP 668 detected
4. All existing functionality preserved for non-PEP 668 systems

### Compatibility
- **Fully compatible** with existing installations on macOS and older Linux distributions
- **New support** for Debian 12 (Bookworm), Ubuntu 23.04+, Fedora 38+
- No breaking changes - all existing configurations continue to work

### Testing
Tested and validated on:
- Debian 12 (Bookworm) - docker container
- Ubuntu 24.04 - docker container
- Fedora 39 - docker container
- Python 3.11+ with PEP 668 enabled

## [1.0.0] - 2024-12-10

### Initial Release
- aod (Army of Darkness) multi-branch parallel development
- MCP servers: ChromaDB, Memory Bank, Sequential Thinking, DEVONthink
- 16 custom agents for Java development, code review, research
- Session management commands: /check, /load, /sessions, /session-delete
- Terminal tools: tmux-cli, find-session, vault, env-safe, ccstatusline
- Safety hooks for git, file, and environment protection
- Optional configuration templates (tmux.conf, CLAUDE.md)
