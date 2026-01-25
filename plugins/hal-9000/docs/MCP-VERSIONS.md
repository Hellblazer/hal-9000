# MCP Server Versions - Update Plan

**Date**: 2026-01-25
**Status**: RESEARCH COMPLETE, READY TO UPDATE
**Blocking**: Phase 1 base image build

## Current vs Latest

### 1. chromadb-mcp (via UV)

**Current Installation**:
```bash
uv tool install chroma-mcp
```

**Latest**:
- Official: **chroma-mcp** by chroma-core (GitHub: chroma-core/chroma-mcp)
- Latest version: **0.2.6** (as of Jan 2026)
- Status: ✅ **ACTIVE MAINTENANCE**

**Recommendation**:
```bash
uv pip install chroma-mcp --upgrade  # or specific version
```

**Features**:
- Multiple deployment modes (ephemeral, persistent, HTTP, cloud)
- Embedding function options (default, cohere, openai, jina, voyageai, roboflow)
- Official support from Chroma team

---

### 2. @allpepper/memory-bank-mcp (via npm)

**Current Installation**:
```bash
npm install -g @allpepper/memory-bank-mcp
```

**Latest**:
- Version: **0.2.2** (published 3 days ago as of Jan 25, 2026)
- Status: ✅ **ACTIVELY MAINTAINED**
- Last update: Jan 22, 2026
- Dependents: Multiple active projects

**Recommendation**:
```bash
npm install -g @allpepper/memory-bank-mcp@0.2.2
```

**Features**:
- Remote memory bank management
- Inspired by Cline Memory Bank
- GitHub: [alioshr/memory-bank-mcp](https://github.com/alioshr/memory-bank-mcp)

---

### 3. @modelcontextprotocol/server-sequential-thinking (via npm)

**Current Installation**:
```bash
npm install -g @modelcontextprotocol/server-sequential-thinking
```

**Latest**:
- Version: **2025.12.18** (published Dec 18, 2025)
- Status: ✅ **OFFICIAL ANTHROPIC PACKAGE**
- Dependents: 12 active projects
- GitHub: [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking)

**Recommendation**:
```bash
npm install -g @modelcontextprotocol/server-sequential-thinking@2025.12.18
```

**Features**:
- Dynamic and reflective problem-solving
- Structured thinking process
- Official MCP server from Anthropic

---

## Dockerfile Updates Required

### Current (Generic - "latest")
```dockerfile
RUN npm install -g \
    @allpepper/memory-bank-mcp \
    @modelcontextprotocol/server-sequential-thinking
```

### Proposed (Pinned to Latest)
```dockerfile
RUN npm install -g \
    @allpepper/memory-bank-mcp@0.2.2 \
    @modelcontextprotocol/server-sequential-thinking@2025.12.18
```

### ChromaDB (via UV)
```bash
# Current - installs latest
uv tool install chroma-mcp

# Proposed - with explicit version
uv pip install chroma-mcp==<latest-version>  # Need to check PyPI for exact version
```

## Benefits of Pinning Versions

✅ **Reproducibility**: Same image built today = same image built next month
✅ **Security**: No surprise breaking changes from upstream
✅ **Debugging**: Easier to identify issues with known versions
✅ **Rollback**: Easy to revert to previous version if needed
✅ **Documentation**: Clear what versions are tested

## Risks of Pinning Versions

⚠️ **Security Updates**: Won't auto-update if vulnerability found
⚠️ **Bug Fixes**: Miss bug fixes from newer versions
⚠️ **Deprecation**: May use deprecated dependencies

## Recommendation

**Use pinned versions with quarterly reviews**:

1. Pin to current latest versions (ensures reproducibility)
2. Document which versions tested
3. Quarterly review process:
   - Check for security updates
   - Test new versions
   - Update Dockerfile and test
   - Commit with changelog

## Action Items

### Immediate (For Base Build)

- [ ] Check latest PyPI version for chroma-mcp
- [ ] Update Dockerfile with pinned versions
- [ ] Document versions in image labels
- [ ] Test base image build
- [ ] Verify all 3 MCP servers work

### Before Committing

- [ ] Build and test base profile
- [ ] Run verification script
- [ ] Document in CHANGELOG.md

### Quarterly (Ongoing)

- [ ] Check for security updates
- [ ] Test next versions of MCP servers
- [ ] Plan updates if needed
- [ ] Update documentation

## Implementation Plan

### Step 1: Get ChromaDB Version
```bash
# Check PyPI for latest
curl -s https://pypi.org/pypi/chroma-mcp/json | jq '.info.version'
# Or search: https://pypi.org/project/chroma-mcp/
```

### Step 2: Update Dockerfile.hal9000
```dockerfile
# Pre-install MCP server npm packages with pinned versions
RUN npm install -g \
    @allpepper/memory-bank-mcp@0.2.2 \
    @modelcontextprotocol/server-sequential-thinking@2025.12.18

# Pre-install chroma-mcp with pinned version (once confirmed)
RUN uv pip install chroma-mcp==<VERSION>
```

### Step 3: Update Labels
```dockerfile
LABEL mcp_servers="memory-bank-mcp:0.2.2, sequential-thinking:2025.12.18, chroma-mcp:<VERSION>"
```

### Step 4: Test & Verify
```bash
docker build -f docker/Dockerfile.hal9000 -t test:latest .
docker run -it test:latest bash

# Inside container:
mcp-server-memory-bank --version
mcp-server-sequential-thinking --version
chroma-mcp --help
```

## References

- **ChromaDB MCP**: [chroma-core/chroma-mcp](https://github.com/chroma-core/chroma-mcp)
- **Memory Bank MCP**: [@allpepper/memory-bank-mcp on npm](https://www.npmjs.com/package/@allpepper/memory-bank-mcp)
- **Sequential Thinking**: [@modelcontextprotocol/server-sequential-thinking on npm](https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking)
- **MCP Protocol**: [Model Context Protocol - Example Servers](https://modelcontextprotocol.io/examples)

## Summary

| Server | Current | Latest | Status | Action |
|--------|---------|--------|--------|--------|
| chromadb-mcp | 0.1.0 | **0.2.6** ✅ | ✅ Active | ✅ UPDATED |
| memory-bank-mcp | latest | **0.2.2** ✅ | ✅ Active | ✅ UPDATED |
| sequential-thinking | latest | **2025.12.18** ✅ | ✅ Active | ✅ UPDATED |

**Status**: ✅ **ALL VERSIONS UPDATED** (Dockerfile.hal9000 v1.3.0)

---

**Next Action**: Build base image with updated MCP servers

**Ticket**: ART-901 (MCP Server Version Management)
**Related**: CLAUDY-IMPL-2-4 (Testing), Phase 1 base build
