# Changelog

All notable changes to hal-9000 will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-12-14

### Added
- **PEP 668 automatic detection and handling** for modern Linux distributions (Debian Bookworm, Ubuntu 24.04+, Fedora 38+)
- `has_pep668_protection()` function in `common.sh` to detect externally-managed Python environments
- `safe_pip_install()` function in `common.sh` that automatically applies `--break-system-packages` flag when needed
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

### Fixed
- Installation failures on Debian Bookworm (Debian 12) and other PEP 668-protected systems
- ChromaDB MCP server installation now works on Ubuntu 24.04 and newer
- DEVONthink dependencies installation in modern Python environments

### Improved
- Installation experience on modern Linux distributions - no manual intervention needed
- Error messages now clearly indicate PEP 668 detection and handling
- Better documentation for troubleshooting common installation issues

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

## [1.0.0] - 2024-12-XX

### Initial Release
- aod (Army of Darkness) multi-branch parallel development
- MCP servers: ChromaDB, Memory Bank, Sequential Thinking, DEVONthink
- 12 custom agents for Java development, code review, research
- Session management commands: /check, /load, /sessions, /session-delete
- Terminal tools: tmux-cli, find-session, vault, env-safe, ccstatusline
- Safety hooks for git, file, and environment protection
- Optional configuration templates (tmux.conf, CLAUDE.md)
