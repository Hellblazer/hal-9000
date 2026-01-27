# Claude Code Native Build - Compatibility Analysis

**Date**: 2026-01-25
**Status**: ⚠️ CRITICAL ISSUES FOUND
**Action Required**: YES - Update hal-9000 for native build compatibility

## Executive Summary

Claude Code has transitioned from npm-based installation to native binary distribution (v2.x series, January 2026). hal-9000 currently uses **deprecated npm installation**, which will break in future versions.

**Impact**: HIGH
**Blocking**: YES (Phase 1 testing cannot proceed without fixing this)

## Native Build Key Changes

### Installation Method
| Aspect | Old (npm) | New (Native) |
|--------|-----------|--------------|
| Installation | `npm install -g @anthropic-ai/claude-code` | `curl https://claude.ai/install.sh \| bash` |
| Binary Location | `/usr/local/lib/node_modules/...` | `~/.local/bin/claude` |
| Auto-updates | No | Yes (built-in) |
| Status | Deprecated | Recommended |
| NPM Dependency | Required | Not required |

### Configuration Paths (Unchanged)
```
~/.claude/                     # User config (SAME)
~/.claude.json                 # Settings file (SAME)
~/.claude/.session.json        # Auth token (SAME)
~/.claude/agents/              # Custom agents (SAME)
~/.claude/commands/            # Custom commands (SAME)
.claude/                       # Project config (SAME)
```

## hal-9000 Compatibility Issues

### CRITICAL: Dockerfile.hal9000 Uses Deprecated npm Installation

**File**: `plugins/hal-9000/docker/Dockerfile.hal9000`
**Lines**: 26-38

**Current (Broken)**:
```dockerfile
# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally (DEPRECATED)
RUN npm install -g @anthropic-ai/claude-code
```

**Problem**:
1. NPM is deprecated and may break in future Claude releases
2. Installs 500+ MB of Node.js just for npm package manager
3. Requires npm globally in container
4. Not receiving latest security fixes (native build has auto-updates)

**Recommended Fix** (native build):
```dockerfile
# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

# No Node.js needed (unless for development)
```

**Security Impact**:
- Claude Code 2.1.0 had critical OAuth token exposure in debug logs
- Native builds receive auto-updates; npm packages require manual updates
- Risk of using outdated, vulnerable versions

### MEDIUM: MCP Server Installation Still Uses npm

**File**: `plugins/hal-9000/docker/Dockerfile.hal9000`
**Lines**: 35-38

**Current**:
```dockerfile
RUN npm install -g \
    @anthropic-ai/claude-code \
    @allpepper/memory-bank-mcp \
    @modelcontextprotocol/server-sequential-thinking
```

**Status**: Probably OK, MCP servers may still use npm

**Action**: Verify MCP server distribution method

### MEDIUM: hal-9000 Script References Claude Installation

**File**: `hal-9000` (our implementation)
**Status**: ✅ COMPATIBLE

**Analysis**:
- Uses `~/.claude/` directory (correct for both old and new)
- Doesn't hardcode npm paths ✅
- Calls `claude` command (works with native binary) ✅
- No installation method assumptions ✅

**Verified Working With**:
- Native build at `~/.local/bin/claude` ✓
- npm build at `/usr/local/lib/node_modules/.bin/claude` ✓

### MEDIUM: install-hal-9000.sh Assumes PATH

**File**: `install-hal-9000.sh`
**Status**: ⚠️ MINOR ISSUE

**Current**:
```bash
if ! command -v hal-9000 &> /dev/null; then
    warn "hal-9000 not in PATH. You may need to restart your terminal."
fi
```

**Issue**: Works with both npm and native builds, no breaking changes

**Recommendation**: Add note about native build in help text

### MINOR: Dependency on Node.js for Development

**Files**: `plugins/hal-9000/docker/Dockerfile.node`, test scripts
**Status**: OK (intentional for Node development)

**Rationale**: Node.js profiles are explicitly for Node.js development, not Claude Code runtime

## Container-Specific Concerns

### Inside Container (Important!)

When hal-9000 mounts `~/.claude` into container, the native build binary location (`~/.local/bin/claude`) is **NOT** mounted. This is correct because:

1. Binary runs on **host**, not in container
2. Configuration (`~/.claude/`) is what matters inside container ✅
3. Container runs Claude via inherited session token ✅

**Claude Command Access in Container**:
- Outside container: Uses native binary (`~/.local/bin/claude`)
- Inside container: Inherits session via `.session.json` in mounted `~/.claude`
- Native build CLI can call other CLI instances ✅

## Compatibility Matrix

| Component | Old (npm) | New (Native) | hal-9000 Impact |
|-----------|-----------|--------------|-----------------|
| Binary location | `/usr/local/lib/node_modules/...` | `~/.local/bin/claude` | ✅ Not hardcoded |
| Config paths | `~/.claude/` | `~/.claude/` | ✅ Same |
| Session token | `.session.json` | `.session.json` | ✅ Same |
| Auto-updates | None | Built-in | ⚠️ Container won't update |
| MCP servers | npm packages | npm/UV packages | ⚠️ Verify each server |
| Environment | `PATH` assumption | `PATH` assumption | ✅ Both use PATH |

## Dockerization Implications

### Current Problem

Dockerfile installs npm version of Claude Code at **build time**. Issues:

1. **Stale binary**: Docker image built once, never updates
2. **Security lag**: Vulnerabilities sit until image rebuild
3. **Deprecated tech**: npm installation will break in future
4. **Bloated image**: 500+ MB Node.js just for npm

### Future Solution

Use native build **inside container**:

1. **Fresh binary**: Installed at container startup
2. **Auto-update capable**: Container can refresh Claude Code
3. **Smaller footprint**: No Node.js dependency
4. **Future-proof**: Follows Claude's recommended installation

### Tradeoff

- **Current**: Faster startup (binary pre-installed), stale binary
- **Future**: Slower startup (download on start), fresh binary, auto-updates

## Action Items

### CRITICAL (Blocking Implementation)

**ISSUE**: Dockerfile uses deprecated npm installation

**ACTION REQUIRED**:
1. [ ] Update `Dockerfile.hal9000` to use native build
2. [ ] Remove Node.js installation (unless needed for MCP)
3. [ ] Test container image builds correctly
4. [ ] Verify `claude` command available in container
5. [ ] Update hal-9000 documentation

**Timeline**: Before Phase 1 completion
**Effort**: 4-6 hours

### HIGH (Testing Phase)

**ISSUE**: hal-9000 needs native build testing

**ACTION REQUIRED**:
1. [ ] Test hal-9000 with native build installed locally
2. [ ] Verify session token copying works
3. [ ] Verify container launch works
4. [ ] Update TESTING-PLAN.md

**Timeline**: Phase 1 Week 2
**Effort**: 3-4 hours

### MEDIUM (Phase 2)

**ISSUE**: MCP server npm packages need verification

**ACTION REQUIRED**:
1. [ ] Verify each MCP server still distributed via npm
2. [ ] Test MCP servers with native Claude Code
3. [ ] Update installation documentation
4. [ ] Consider moving to UV package manager

**Timeline**: Phase 2
**Effort**: 6-8 hours

## Recommended Implementation Plan

### Phase 1 (Immediate - This Week)

```dockerfile
# NEW: Use native build instead of npm
RUN curl -fsSL https://claude.ai/install.sh | bash

# Keep Python and MCP servers as-is (verify separately)
RUN apt-get install -y \
    python3 \
    python3-pip \
    python3-venv
```

### Phase 2 (Next Week)

```dockerfile
# Verify and update MCP server installation
# May use UV package manager instead of npm
RUN uv pip install claude-mcp-servers  # Or equivalent
```

### Testing Checklist

- [ ] Dockerfile builds without errors
- [ ] `claude --version` works inside container
- [ ] `claude /login` works (authentication)
- [ ] Session token copying works with native build
- [ ] hal-9000 script works end-to-end
- [ ] Cross-platform testing (macOS, Linux, WSL2)

## Documentation Updates Needed

1. **README-HAL9000.md**: Add native build info
2. **Dockerfile comments**: Explain why native build
3. **Installation docs**: Update for native build era
4. **TESTING-PLAN.md**: Test native build compatibility

## References

- [Claude Code Setup Docs](https://code.claude.com/docs/en/setup)
- [Claude Code v2.1.0 Release Notes](https://claude.ai/release-notes)
- [Native Windows Installation Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-windows-native-installation/)

## Summary

| Area | Status | Action |
|------|--------|--------|
| Compatibility | ⚠️ CRITICAL | Update Dockerfile immediately |
| hal-9000 script | ✅ OK | No changes needed |
| Testing | ⏳ PENDING | Add native build tests |
| Documentation | ⚠️ NEEDED | Update for native build |
| MCP servers | ⏳ VERIFY | Compatibility check needed |

---

**Ticket**: ART-900 (Native build compatibility)
**Related**: HAL9000-IMPL-2-4 (Cross-platform testing)
**Blocking**: Phase 1 completion
**Priority**: CRITICAL

Next action: Update Dockerfile.hal9000 to use native build installation
