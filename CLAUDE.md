# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**hal-9000: Containerized Claude Infrastructure and Marketplace**

This repository contains:
- Docker-in-Docker orchestration for Claude Code
- Plugin marketplace infrastructure
- Foundation MCP servers (ChromaDB, Memory Bank, Sequential Thinking)
- Custom commands, hooks, and tools for enhanced Claude workflows

## Repository Structure

```
hal-9000/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition
├── plugins/
│   └── hal-9000/                 # Main plugin
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin metadata
│       ├── aod/                  # Army of Darkness multi-branch tool
│       ├── commands/             # Slash commands (/check, /load, etc.)
│       ├── hal9000/              # Containerized Claude launcher
│       ├── hooks/                # Safety hooks
│       ├── mcp-servers/          # MCP server configs & docs
│       ├── docker/               # Docker build profiles
│       └── README.md
├── templates/                    # CLAUDE.md templates for projects
├── CHEATSHEET.md                 # Quick reference guide
├── README.md                     # Main documentation
└── CLAUDE.md                     # This file (repo development guide)
```

## What is a Plugin Marketplace?

A Claude Code plugin marketplace is a repository that:
- Contains `.claude-plugin/marketplace.json` defining available plugins
- Each plugin has `.claude-plugin/plugin.json` with metadata
- Users add the marketplace to Claude Code settings
- Plugins can provide: MCP servers, slash commands, hooks, etc.

## Working in This Repository

### Adding a New Plugin

1. Create plugin directory: `plugins/[plugin-name]/`
2. Add `.claude-plugin/plugin.json`:
   ```json
   {
     "name": "plugin-name",
     "description": "Plugin description",
     "version": "1.0.0",
     "author": {...},
     "mcpServers": {...},      // Optional
     "commands": {...},         // Optional
     "hooks": {...}            // Optional
   }
   ```
3. Add plugin content (MCP servers, commands, etc.)
4. Update `.claude-plugin/marketplace.json`:
   ```json
   {
     "plugins": [
       ...,
       {
         "name": "plugin-name",
         "source": "./plugins/plugin-name",
         "description": "Brief description",
         "version": "1.0.0"
       }
     ]
   }
   ```
5. Write README.md for the plugin
6. Test by adding marketplace to Claude Code

### Plugin Types

**MCP Server Plugin** (like hal-9000):
- Provides `mcpServers` in plugin.json
- Each server needs command, args, optional env
- Can include installation steps

**Command Plugin** (like session-tools):
- Provides `commands` in plugin.json
- Each command references a .md file
- Commands are slash commands (/command)

**Hook Plugin**:
- Provides `hooks` in plugin.json
- Can trigger on SessionStart, PreCompact, etc.

### Modifying Existing Plugin

**hal-9000 plugin**:
- MCP server configs in `.claude-plugin/plugin.json`
- MCP documentation in `mcp-servers/*/README.md`
- Commands in `commands/*.md` (referenced in plugin.json)
- Hooks in `hooks/*.py` (registered via hooks.json)
- Docker profiles in `docker/`
- To add MCP server: update plugin.json + add docs in mcp-servers/
- To add command: create .md file in commands/ + update plugin.json

### Testing Changes

1. Update version in plugin.json
2. Test locally by adding marketplace to Claude Code:
   - Settings → Marketplaces → Add Local Marketplace
   - Point to repository path
3. Install/update plugin in Claude Code
4. Verify functionality

## Plugin.json Schema

### Required Fields
```json
{
  "name": "string",
  "description": "string",
  "version": "semver",
  "author": {
    "name": "string",
    "url": "string (optional)"
  },
  "repository": "string",
  "license": "string"
}
```

### Optional Fields
```json
{
  "mcpServers": {
    "server-id": {
      "command": "string",
      "args": ["array"],
      "env": {"key": "value"}
    }
  },
  "commands": {
    "command-name": {
      "file": "path/to/file.md",
      "description": "string"
    }
  },
  "hooks": {
    "SessionStart": [...],
    "PreCompact": [...]
  },
  "install": {
    "steps": [...],
    "postInstall": "string"
  }
}
```

## Environment Variables

Use `${VAR_NAME}` syntax in plugin.json:
- `${HOME}` - User home directory
- `${CLAUDE_PLUGIN_ROOT}` - Plugin installation root
- `${CHROMADB_TENANT}` - Custom env var (user must set)

## Documentation Standards

- Every plugin must have README.md
- Explain what it does, why use it, how to configure
- Include usage examples
- Document prerequisites and troubleshooting

## Templates Directory

Contains CLAUDE.md templates for different project types:
- `java-project.md` - Java/Maven/Gradle
- `typescript-project.md` - TypeScript/Node.js
- `python-project.md` - Python/pip/poetry

These are NOT plugins - they're reference templates for users' projects.

## Legacy Installer

`install.sh` and `uninstall.sh` provide alternative installation without marketplace feature. These manually:
- Install MCP server dependencies
- Copy command files
- Update Claude config

Marketplace installation is preferred.

## Testing Checklist

Before committing plugin changes:

1. ✅ Version bumped in plugin.json
2. ✅ marketplace.json updated if new plugin
3. ✅ JSON syntax valid (`jq . < file.json`)
4. ✅ README.md updated
5. ✅ Tested in Claude Code:
   - Add marketplace locally
   - Install/update plugin
   - Verify functionality
6. ✅ Environment variables documented

## Release Process

**When releasing a new version of hal-9000:**

### 1. Version Bumping (CRITICAL - DO NOT SKIP!)

Before creating git tag, synchronize all version references:

**README.md badge**:
```bash
# Update the version badge at line 3
[![Version](https://img.shields.io/badge/version-X.Y.Z-blue.svg)]
```

**hal-9000 script** (line 8):
```bash
readonly SCRIPT_VERSION="X.Y.Z"
```

**Check all are consistent**:
```bash
grep -n "version\|VERSION" README.md hal-9000 | grep -E "0\.[0-9]\.|[0-9]\.[0-9]\.[0-9]"
# All should show the SAME version
```

### 2. Decide Version Number

Follow semantic versioning:
- **Patch (X.Y.Z)**: Bug fixes, minor improvements
- **Minor (X.Y+1.0)**: New features (session persistence, new MCP servers)
- **Major (X+1.0.0)**: Breaking changes (API changes, incompatible updates)

**Recent changes** (decide category):
- Session persistence across containers → **MINOR**
- Authentication token persistence → **MINOR**
- MCP configuration persistence → **MINOR**
- Subscription login support → **MINOR**
- Bug fixes in login/session handling → **MINOR**

→ Result: `v1.4.0` → `v2.0.0` (major version bump - Docker-in-Docker orchestration)

### 3. Build & Test

```bash
# Build all Docker images
make build

# Verify images exist
docker images | grep ghcr.io/hellblazer/hal-9000

# Test locally (optional but recommended)
make test-claudy
```

### 4. Push Docker Images

```bash
# Push all profile images to registry
docker push ghcr.io/hellblazer/hal-9000:base
docker push ghcr.io/hellblazer/hal-9000:python
docker push ghcr.io/hellblazer/hal-9000:node
docker push ghcr.io/hellblazer/hal-9000:java
```

### 5. Create Release Commit

```bash
git add README.md hal-9000
git commit -m "Release v2.0.0: Docker-in-Docker orchestration and persistent session state

Major features:
- Docker-in-Docker parent-worker orchestration
- Session state persists across container instances
- Authentication tokens persist without re-login
- MCP server configurations survive session boundaries
- Foundation MCP servers (ChromaDB, Memory Bank, Sequential Thinking)
- Complete Docker image suite (parent, worker, base, python, node, java)

Images: ghcr.io/hellblazer/hal-9000:parent|worker|base|python|node|java"
```

### 6. Create Git Tag

```bash
git tag -a v2.0.0 -m "Release v2.0.0 - Docker-in-Docker Orchestration

- Parent container orchestration with worker pool management
- Persistent session state (authentication, MCP config, plugins)
- Foundation MCP servers at host level (ChromaDB, Memory Bank, Sequential Thinking)
- Complete Docker image suite (parent, worker, base, python, node, java)
- Security hardening (code injection prevention, path traversal prevention)
- All 16 custom agents removed - use marketplace plugins instead"

# Push tag to remote
git push origin v2.0.0
```

### 7. Update GitHub Release

```bash
# Update release with comprehensive notes
gh release edit vX.Y.Z \
  --notes-file RELEASE_NOTES_vX.Y.Z.md \
  --latest

# Attach installer script as asset
gh release upload vX.Y.Z install-hal-9000.sh --clobber

# Verify release
gh release view vX.Y.Z --json assets
```

### 8. COMPREHENSIVE VERIFICATION (CRITICAL!)

**Run the automated verification script**:
```bash
scripts/release/verify-release.sh X.Y.Z
```

This script validates **9 critical areas**:
1. **Version Synchronization** - README, CLI, plugin, marketplace all match
2. **JSON Configuration** - marketplace.json and plugin.json are valid
3. **Docker Images** - All 6 profiles exist and are functional (parent, worker, base, python, node, java)
4. **Installation Script** - Installer exists, is executable, has valid syntax
5. **Release Notes** - Complete documentation with all required sections
6. **Git Repository** - Working tree clean, tag exists
7. **Marketplace** - All required fields present
8. **Documentation** - README.md, RELEASE_NOTES, and key guides exist
9. **Installer URL** - GitHub raw URL is accessible

**Expected Output**: `100% - Ready for production`

**If verification fails**: Fix reported issues and re-run until 100%.

### 9. End-to-End Testing

After verification passes, run **real-world usage tests**:

```bash
# Test 1: Fresh install from URL
curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash
hal-9000 --version  # Should show X.Y.Z

# Test 2: Container startup with base profile
hal-9000 /tmp/test-project
# Should: launch container, run Claude
# Verify: Claude loads, Docker CLI works, MCP servers available

# Test 3: Session persistence
hal-9000 /tmp/project1
# Login if needed
exit
hal-9000 /tmp/project2
# Should: no re-login required (session persists)

# Test 4: All profile images work
docker run --rm ghcr.io/hellblazer/hal-9000:parent claude --version
docker run --rm ghcr.io/hellblazer/hal-9000:worker claude --version
docker run --rm ghcr.io/hellblazer/hal-9000:base claude --version
docker run --rm ghcr.io/hellblazer/hal-9000:python python3 --version
docker run --rm ghcr.io/hellblazer/hal-9000:node node --version
docker run --rm ghcr.io/hellblazer/hal-9000:java java --version

# Test 5: Marketplace plugin installation (optional)
hal-9000 plugin marketplace add Hellblazer/hal-9000
hal-9000 plugin install hal-9000
```

### 10. Final Release Commit

After ALL verification and testing passes:

```bash
# Commit any final documentation updates
git add -A
git commit -m "docs: Final release notes and verification for vX.Y.Z"
git push origin main
```

### Release Checklist (Production-Ready)

**Version Synchronization**:
- [ ] Decided on version number (X.Y.Z)
- [ ] Updated README.md version badge
- [ ] Updated hal-9000 script SCRIPT_VERSION
- [ ] Updated marketplace.json version
- [ ] Updated plugin.json version
- [ ] Verified ALL versions match

**Build & Push**:
- [ ] Built Docker images (`make build`)
- [ ] All 6 profiles built successfully (parent, worker, base, python, node, java)
- [ ] Pushed all images to ghcr.io
- [ ] Images available in registry

**Release Artifacts**:
- [ ] Created RELEASE_NOTES_vX.Y.Z.md
- [ ] Created release commit with changelog
- [ ] Created annotated git tag with notes
- [ ] Pushed tag to remote
- [ ] Updated GitHub release with notes
- [ ] Attached installer script as asset

**Verification** (CRITICAL):
- [ ] Ran `scripts/release/verify-release.sh` → **100%**
- [ ] Version verification passed
- [ ] JSON configuration valid
- [ ] Docker images functional
- [ ] Installer script works
- [ ] Release notes complete
- [ ] Git artifacts correct

**End-to-End Testing**:
- [ ] Fresh install from URL works
- [ ] Container startup successful
- [ ] Session persistence works
- [ ] All 4 profile images functional
- [ ] Marketplace plugin installs (optional)

**Final Checks**:
- [ ] GitHub release page reviewed
- [ ] Release notes readable on GitHub
- [ ] Installer asset downloadable
- [ ] Docker images pullable from registry

## Post-Release

After successful release:

1. **Announce**: Update documentation, notify users
2. **Monitor**: Watch for issues in first 24-48 hours
3. **Archive**: Save release verification output for records

## Release Verification Script

The script `scripts/release/verify-release.sh` is your **single source of truth** for release readiness.

**Usage**:
```bash
./scripts/release/verify-release.sh 1.4.0
```

**Returns**:
- Exit 0 if 100% verified (ready for production)
- Exit 1 if any checks fail (NOT ready)

**Integration**:
- Run before creating GitHub release
- Run after any version changes
- Run as final gate before announcement

## Common Issues

**Marketplace not appearing**:
- Check `.claude-plugin/marketplace.json` exists
- Verify JSON syntax
- Restart Claude Code

**Plugin install fails**:
- Check install steps work standalone
- Verify command paths are correct
- Check prerequisites are installed

**MCP servers not loading**:
- Check command path exists
- Verify environment variables set
- Look at Claude Code logs

## License

Apache 2.0 - All contributions must comply.
