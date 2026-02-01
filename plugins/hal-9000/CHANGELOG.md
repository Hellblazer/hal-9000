# Changelog

All notable changes to hal-9000 will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-02-01

### Added
- **Seccomp Syscall Filtering** - Block dangerous syscalls (mount, ptrace, kernel modules)
  - Three profile levels: base, standard, audit
  - Protection against container escape and privilege escalation
  - See [seccomp/README.md](seccomp/README.md)

- **Security Audit Logging** - Comprehensive structured logging
  - JSON-formatted security events
  - API key hashing (no plaintext exposure)
  - Audit trail for all security-relevant operations
  - See [docker/SECURITY-MONITORING.md](docker/SECURITY-MONITORING.md)

- **Extended Hook Coverage**
  - Grep tool protection
  - NotebookEdit tool protection
  - file_access hook for filesystem monitoring
  - Symlink bypass protection in all hooks

- **Supply Chain Hardening**
  - SHA256 digest pinning for all Docker base images
  - Script signature verification
  - Dependency integrity checks
  - See [docker/BASE_IMAGE_DIGESTS.md](docker/BASE_IMAGE_DIGESTS.md)

- **Per-User Volume Isolation** - Prevent cross-user data access

### Changed
- **BREAKING: Environment variable API keys are now REJECTED**
  - Must use file-based secrets: `~/.hal9000/secrets/anthropic_api_key`
  - Or Docker secrets
  - Or subscription login: `hal-9000 /login`

### Security
- All 139 integration tests passing
- Security scanning integrated into CI pipeline
- Docker image build verification

## [2.0.0] - 2026-01-28

### Added
- **Docker-in-Docker Orchestration** (MAJOR FEATURE)
  - Parent container orchestrator with worker pool management
  - Worker container isolation with shared volumes
  - Persistent session state across container instances
  - Multi-profile Docker image suite (parent, worker, base, python, node, java)
  - Integration with Foundation MCP Servers

- **Persistent Session Management**
  - Authentication token persistence across sessions
  - MCP server configuration survival
  - Marketplace plugin installation sharing
  - One-time volume initialization with marker files

- **Foundation MCP Servers**
  - ChromaDB vector database server (port 8000)
  - Memory Bank persistent storage
  - Sequential Thinking step-by-step reasoning
  - Deployment script: `~/.hal9000/scripts/setup-foundation-mcp.sh`

- **Security Hardening**
  - Per-worker ChromaDB tenant isolation (workers cannot access each other's data)
  - Code injection prevention (safe config parsing)
  - Path traversal prevention (profile validation)
  - 19 security-focused tests
  - Comprehensive security documentation

- **Comprehensive Test Suite**
  - Security tests (19 tests, 100% pass rate)
  - Configuration constraint tests (11 tests, 100% pass rate)
  - Build and integration tests (73+ tests)
  - E2E migration tests

### Removed
- **All 16 Custom Agents** - Complete removal of agent framework
  - java-developer, code-review-expert, strategic-planner, and 13 others removed
  - Users should migrate to marketplace plugins for similar functionality
  - Agent-based workflows require transition to MCP server-based approaches
  - See Migration Guide below for details

### Changed
- Docker build system with automated profile management
- Session initialization and volume management
- Plugin installation process with DinD support

### Fixed
- Code injection vulnerability via config file
- Path traversal vulnerability in profile names
- Session state contamination between runs

### Breaking Changes
- **Agent Removal**: All 16 custom agents removed. Users relying on agents must migrate to marketplace plugins or MCP server-based workflows.
- DinD architecture is fully backward compatible for non-agent workflows

### Test Results
```
Security Tests: 19/19 PASS
Config Constraint Tests: 11/11 PASS
Build & Integration Tests: 73+ PASS
Errors: 0
Warnings: 0
Test Coverage: 95% (hooks), 85% (examples)
```

### Migration Guide
For users upgrading from v1.x to v2.0.0:
1. All 16 custom agents removed - review RELEASE_NOTES_v2.0.0.md for migration guidance
2. Docker-in-Docker and marketplace features fully backward compatible
3. Session state persists across container instances automatically
4. For marketplace alternatives to agents, see marketplace plugin documentation

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
