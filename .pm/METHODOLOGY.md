# Claudy Implementation Methodology

## Engineering Discipline

### Task Execution Flow
1. **Create bead** before starting work (track in bd)
2. **Read design documents** from Memory Bank project `hal-9000_active`
3. **Implement focused on deliverable** (avoid scope creep)
4. **Test immediately** (unit tests, not just manual)
5. **Update task status** (in_progress → completed)
6. **Document tradeoffs** in bead notes

### Code Quality Standards
- Bash scripts: shellcheck clean, error handling (set -Eeuo pipefail)
- Documentation: link to design docs (e.g., "See claudy-authentication-revised.md for details")
- Testing: cross-platform (macOS, Linux, WSL2)
- No credentials in code (use ~/.claudyrc or environment variables)

### Decision Recording
Every architectural decision gets:
- Bead reference (links to implementing task)
- Memory Bank entry (for future sessions)
- Design document cross-reference

### Context Recovery
- Check `.pm/CONTINUATION.md` for phase context
- Read Memory Bank for design decisions
- Query `bd list --status=in_progress` for active work
- Review completed beads for implementation patterns

## Phases

### Phase 1: Core Foundation (Weeks 1-2)
- [ ] Week 1: claudy script + profile detection
- [ ] Week 2: Authentication + session management

### Phase 2: Enhanced Features (Weeks 3-4)
- [ ] Week 3: Configuration system (.claudyrc)
- [ ] Week 4: Multi-project coordination

### Phase 3: Power Features (Weeks 5-6)
- [ ] Week 5: MCP server integration
- [ ] Week 6: Skills (/wrap, /sup, /fragile)

## Success Gates
- All tests passing
- Cross-platform verification (Mac, Linux, WSL2)
- Zero permission dialogs
- Session isolation verified
- Design documents referenced

## Handoff Protocol
When delegating to agents:
1. Create bead with task
2. Reference design documents
3. Include Memory Bank context
4. Specify expected deliverable
5. Link to parent epic

---
See .pm/CONTINUATION.md for current phase details.
