# Dockerfile Update Plan - Native Build Compatibility

**Status**: READY TO IMPLEMENT
**Blocking**: Phase 1 testing
**Effort**: 2-3 hours

## Current Issue

`plugins/hal-9000/docker/Dockerfile.hal9000` line 32 uses deprecated npm:

```dockerfile
RUN npm install -g @anthropic-ai/claude-code  # DEPRECATED ❌
```

## Proposed Solution

Replace npm installation with native build:

```dockerfile
# Install Claude Code native binary (recommended method)
RUN curl -fsSL https://claude.ai/install.sh | bash  # ✅ RECOMMENDED
```

## Full Dockerfile Diff

### Before (Current - Broken)
```dockerfile
# Install Node.js 20 LTS (required for Claude CLI and MCP servers)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Pre-install MCP server npm packages globally (no npx download needed at runtime)
RUN npm install -g \
    @anthropic-ai/claude-code \
    @allpepper/memory-bank-mcp \
    @modelcontextprotocol/server-sequential-thinking
```

### After (Fixed - Native Build)
```dockerfile
# Install Claude Code native binary (recommended method as of January 2026)
# See: https://code.claude.com/docs/en/setup
RUN curl -fsSL https://claude.ai/install.sh | bash

# Note: Node.js 20 LTS is installed separately for development/MCP only
# (see Dockerfile.node for Node development profile)

# Pre-install MCP server npm packages globally (no npx download needed at runtime)
# Note: These may move to UV package manager in future Claude releases
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs npm \
    && npm install -g \
    @allpepper/memory-bank-mcp \
    @modelcontextprotocol/server-sequential-thinking \
    && rm -rf /var/lib/apt/lists/*
```

### Key Changes

1. **Remove**: `npm install -g @anthropic-ai/claude-code` (deprecated)
2. **Add**: `curl -fsSL https://claude.ai/install.sh | bash` (native build)
3. **Keep**: MCP server npm packages (still required, verified separately)
4. **Split**: Node.js installation only needed for MCP servers, not Claude binary

## Verification Steps

After implementing, verify:

```bash
# 1. Build image
docker build -f docker/Dockerfile.hal9000 -t hal-9000-test:latest .

# 2. Run container
docker run -it hal-9000-test:latest bash

# 3. Inside container, verify:
claude --version          # Should show version
claude /login --help      # Should show login help
which claude              # Should show ~/.local/bin/claude
which mcp-server-memory-bank
which mcp-server-sequential-thinking

# 4. Verify MCP servers still work:
echo "MCP servers ready"
```

## Alternative: Minimal Dockerfile (Future)

For minimal footprint, could use:

```dockerfile
# Ultra-minimal: Just Claude native binary
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace
CMD ["bash"]
```

This would reduce:
- Image size: 500+ MB (Node.js) → ~50 MB (CLI only)
- Build time: 5+ minutes → ~2 minutes
- Startup time: Same (binary is lightweight)

**Decision**: Keep current profile structure (base, python, node, java) - don't eliminate Node.js profile, just update base

## Testing Matrix

After update, test:

| Profile | Test Command | Expected Result |
|---------|--------------|-----------------|
| base | `docker run hal-9000:latest claude --version` | Shows version |
| python | `docker run hal-9000:python claude --version` | Shows version |
| node | `docker run hal-9000:node npm --version && claude --version` | Shows both |
| java | `docker run hal-9000:java java -version && claude --version` | Shows both |

## Rollback Plan

If native build breaks container:

```bash
# Revert to npm (temporary, not recommended)
git checkout HEAD -- plugins/hal-9000/docker/Dockerfile.hal9000
docker build -f docker/Dockerfile.hal9000 -t hal-9000:latest .
```

## Security Implications

**Before** (npm - insecure):
- Vulnerable to stale packages
- No auto-update mechanism
- Packages sit in image indefinitely

**After** (native - secure):
- Container downloads latest binary
- Auto-update ready if container runs long
- Gets security fixes via native update mechanism

## Implementation Steps

1. [ ] Read full compatibility analysis (CLAUDE-NATIVE-BUILD-COMPATIBILITY.md)
2. [ ] Update Dockerfile.hal9000 with native build
3. [ ] Build and test container image
4. [ ] Run verification checklist
5. [ ] Document in CHANGELOG.md
6. [ ] Update build-profiles.sh comments if needed
7. [ ] Update README documentation
8. [ ] Commit with explanation

## Related Tasks

- **CLAUDY-IMPL-2-4**: Cross-platform testing must use native build
- **ART-900**: Native build compatibility ticket
- **Phase 1**: Cannot complete without this fix

---

**See**: CLAUDE-NATIVE-BUILD-COMPATIBILITY.md for full context
**Status**: READY TO IMPLEMENT
**Blocking**: Phase 1 Week 1 completion
**Next**: Implement and test
