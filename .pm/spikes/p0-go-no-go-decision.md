# Phase 0 Go/No-Go Decision Report

**Date**: 2026-01-25
**Epic**: hal-9000-f6t (DinD Claude Orchestration Architecture v1.0)
**Phase**: 0 - Validation Spikes

---

## Executive Summary

**DECISION: MODIFIED GO**

Phase 0 validation spikes have completed with mixed results. The architecture is viable but requires modification from the original plan:

- **MCP Servers**: Must run on HOST (not in containers) - stdio transport only
- **Claude Launcher**: CAN be containerized with lightweight workers
- **Network Sharing**: Works via `--network=container:parent`
- **Worker Image**: 469MB achievable (under 500MB target)

---

## Spike Results Summary

| Spike | Result | Key Finding |
|-------|--------|-------------|
| P0-1: MCP HTTP Transport | **NO-GO** | All 3 servers use stdio only, no HTTP support |
| P0-2: HTTP-to-stdio Proxy | **SKIPPED** | Not viable based on P0-1 findings |
| P0-3: Network Namespace | **GO** | `--network=container:parent` works perfectly |
| P0-4: Worker Image Size | **GO** | 469MB without git (under 500MB target) |

---

## P0-1: MCP HTTP Transport Research

### Result: NO-GO

**Critical Finding**: All three MCP servers use stdio transport exclusively:
- `@allpepper/memory-bank-mcp` - stdio only
- `@modelcontextprotocol/server-sequential-thinking` - stdio only
- `chroma-mcp` - stdio only

**Why This Matters**:
- stdio requires direct process spawning (local only)
- Cannot pipe stdin/stdout across network to containers
- No mature stdio-to-HTTP proxy exists in MCP ecosystem
- Building custom proxy would be 4-6 weeks with high risk

**Architectural Impact**:
The original plan assumed MCP servers would run in parent container with HTTP transport to workers. This is NOT possible with current MCP implementations.

**Recommendation**: Run MCP servers on HOST, containerize only Claude launcher.

---

## P0-2: HTTP-to-stdio Proxy

### Result: SKIPPED

Based on P0-1 findings, developing a stdio-to-HTTP proxy is not viable:
- MCP protocol is bidirectional (complex to bridge)
- No existing solutions to build on
- Estimated 4-6 weeks with uncertain outcome
- Alternative approach (MCP on host) is simpler

---

## P0-3: Network Namespace Sharing PoC

### Result: GO

**Validated**: `--network=container:parent` works exactly as needed.

**Test Results**:
| Test | Status |
|------|--------|
| Parent container with HTTP server | SUCCESS |
| Single worker via network share | SUCCESS |
| 3 workers simultaneously | SUCCESS |
| /proc/net/tcp namespace verification | SUCCESS |

**Key Findings**:
1. Workers can access `localhost:3001` on parent container
2. Workers share parent's network namespace (not just connected)
3. Port bindings must be on parent container
4. Parent must be running for workers to have network

**Use Case**: When MCP servers run on host with port forwarding to parent container, workers can access them via localhost.

---

## P0-4: Worker Image Prototype

### Result: GO (with conditions)

**Image Sizes Achieved**:
| Configuration | Size | vs Target |
|---------------|------|-----------|
| Without git | **469MB** | 6% UNDER 500MB |
| With git | 588MB | 18% over 500MB |

**Component Breakdown**:
- Claude CLI binary: 206MB (non-negotiable)
- System libs (libc, curl, etc.): ~100MB minimum
- Git + Perl dependencies: ~120MB (optional)

**Recommendation**: Workers without git, mount repos from host via volumes.

**Files Created**:
- `plugins/hal-9000/docker/Dockerfile.worker-minimal` (with git, 588MB)
- `plugins/hal-9000/docker/Dockerfile.worker-ultramin` (no git, 469MB)

---

## Revised Architecture

### Original Plan (Not Viable)
```
[Host] → [Parent Container]
              ├── MCP Servers (HTTP) ← BLOCKED: No HTTP support
              ├── Worker 1
              ├── Worker 2
              └── Worker N
```

### Modified Architecture (Viable)
```
[Host]
  ├── MCP Servers (stdio)     ← Run on HOST, not container
  │     ├── memory-bank-mcp
  │     ├── sequential-thinking
  │     └── chroma-mcp
  │
  └── [Parent Container]
        ├── Coordinator
        ├── Worker 1 (--network=container:parent)
        ├── Worker 2 (--network=container:parent)
        └── Worker N (--network=container:parent)
```

### What This Means

1. **MCP servers stay on host**: Use existing configuration via npx
2. **Parent container**: Runs coordinator, spawns workers
3. **Workers**: Lightweight (469MB), share parent's network
4. **Claude Code**: Each worker runs Claude Code with network access

### Benefits of Modified Architecture

1. **Simpler**: No need to containerize MCP servers
2. **Proven**: Current hal9000 infrastructure works this way
3. **Maintainable**: MCP servers update via npx, not image rebuilds
4. **Lower Risk**: Avoids transport layer complexities

---

## Impact on Original Plan

### Phases Affected

| Phase | Impact | Action |
|-------|--------|--------|
| Phase 0 | Complete | Findings documented |
| Phase 1 | **Major** | Remove MCP containerization tasks |
| Phase 2 | Minor | Worker image path confirmed |
| Phase 3 | Minor | Adjust coordinator for host MCP |
| Phase 4 | Minor | Volume mounting for git repos |
| Phase 5 | None | Migration unchanged |
| Phase 6 | None | Optimization unchanged |

### Tasks to Remove/Modify

**Remove from Phase 1**:
- P1-3: MCP Server HTTP Configuration (not needed)
- P1-5: MCP server startup in container (not needed)

**Modify in Phase 1**:
- P1-4: Update parent Dockerfile to exclude MCP servers
- Add: Document MCP host configuration requirements

### Timeline Impact

| Original | Revised | Reason |
|----------|---------|--------|
| 12 weeks | 10-11 weeks | Removed MCP containerization complexity |

---

## Go/No-Go Decision

### MODIFIED GO

**Proceed with implementation** using the modified architecture:

1. **MCP servers on host** (existing configuration works)
2. **Parent/worker containerization** (validated by P0-3, P0-4)
3. **Lightweight workers** (469MB target achievable)
4. **Network namespace sharing** (validated)

### Conditions for Proceeding

1. [x] Update Phase 1 plan to remove MCP containerization
2. [x] Document host MCP requirements
3. [x] Confirm worker image builds successfully
4. [ ] Update beads to reflect modified scope
5. [ ] Create Phase 1 implementation tasks

### Benefits Over Abandoning

- 79% image size reduction (2.85GB → 469MB) still achievable
- Worker isolation still valuable
- Coordinator pattern still simplifies orchestration
- Foundation for future improvements

---

## Deliverables Created

| File | Purpose |
|------|---------|
| `.pm/spikes/p0-1-mcp-transport-research.md` | MCP HTTP research (NO-GO) |
| `.pm/spikes/p0-3-network-namespace-poc.md` | Network namespace validation |
| `.pm/spikes/p0-4-worker-image-prototype.md` | Worker image sizing |
| `.pm/spikes/p0-go-no-go-decision.md` | This decision document |
| `plugins/hal-9000/docker/Dockerfile.worker-minimal` | With git (588MB) |
| `plugins/hal-9000/docker/Dockerfile.worker-ultramin` | No git (469MB) |

---

## Next Actions

1. **Update beads**: Reflect modified Phase 1 scope
2. **Close Phase 0**: Mark feature bead as complete
3. **Revise dind-orchestration-plan.md**: Document modified architecture
4. **Begin Phase 1**: Focus on parent/worker containerization only

---

**Decision Made By**: Consolidated spike findings
**Date**: 2026-01-25
**Confidence Level**: HIGH
