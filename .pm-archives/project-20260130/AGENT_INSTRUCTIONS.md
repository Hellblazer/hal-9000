# Agent Instructions for Claudy Implementation

## Context Protocol

### Session Recovery
1. **On session start**: Read `.pm/CONTINUATION.md` for phase context
2. **For design details**: Search Memory Bank project `hal-9000_active` for:
   - CLAUDY_MASTER_INDEX.md (navigation)
   - CLAUDY_DESIGN_SYNTHESIS.md (unified design)
   - Specific docs (claudy-authentication-revised.md, etc.)
3. **For current work**: Query `bd list --status=in_progress` to see active tasks

### Required Context Files
- `.pm/CONTINUATION.md` - Phase state and decisions
- `.pm/METHODOLOGY.md` - Engineering discipline
- Memory Bank: hal-9000_active/* - All design documents

## When Receiving Handoff

### Input Artifacts
Expect to receive:
- **Bead ID**: Task tracking identifier
- **Memory Bank links**: Design document references
- **Current phase**: Which of 3 phases (Foundation, Enhanced, Power)
- **Success criteria**: What "done" means

### Expected Behavior
1. Read all referenced design documents first
2. Check for existing implementation patterns in bead notes
3. Run cross-platform tests (macOS, Linux, WSL2)
4. Document tradeoffs in bead notes
5. Update bead status when complete

### Escalation
If:
- Design ambiguity found → Ask for clarification (don't assume)
- Implementation conflict → Check bead notes for related work
- Testing failure → Document in bead, pause until resolved
- Scope creep → Record decision, stay focused

## Code Standards

### Bash Scripts
```bash
#!/bin/bash
set -Eeuo pipefail
# Error handling with descriptive messages
# Documentation with links to design docs
# Cross-platform compatibility verified
```

### Testing
- Unit tests before integration tests
- All platforms (macOS bash 5.1+, Linux bash 4.4+, WSL2 bash 5.0+)
- Document test environment setup

### Documentation
- Link to design documents (e.g., "See CLAUDY_DESIGN_SYNTHESIS.md for details")
- Include usage examples
- Document assumptions clearly

## Phase-Specific Context

### Phase 1: Core Foundation (Current)
**Goal**: Users can `cd ~/project && claudy` and get working Claude session

**Key Design Docs**:
- claudy-foundation.md - Core vision
- claudy-installation-setup.md - Setup approach
- claudy-authentication-revised.md - Session inheritance

**No Scope**: 
- Multi-project coordination (Phase 2)
- Skills (/wrap, /sup) (Phase 3)
- MCP servers (Phase 3)

### Phase 2: Enhanced Features
**Goal**: Configuration system, multi-project workflows

**Key Design Docs**:
- claudy-with-hal9000-synthesis.md - Feature integration
- claudy-feature-exposure-design.md - Progressive discovery

### Phase 3: Power Features
**Goal**: Skills, MCP servers, orchestration

**Key Design Docs**:
- skills-and-integration.md - /wrap, /sup, /fragile design
- orchestration-framework-complete.md - Advanced coordination

## Handoff Checklist

When receiving a task:
- [ ] Bead ID captured
- [ ] All design docs reviewed
- [ ] Success criteria understood
- [ ] No scope creep added
- [ ] Cross-platform testing planned
- [ ] Memory Bank entry location identified (if creating)
- [ ] Decision recording approach understood

When handing off:
- [ ] Bead updated with status
- [ ] All tradeoffs documented
- [ ] Tests passing
- [ ] Next bead linked
- [ ] Memory Bank updated (if needed)

---
**Questions?** Check `.pm/CONTINUATION.md` for phase context, or escalate via bead notes.
