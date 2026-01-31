# HAL-9000 Project Context Protocol

**Version**: 1.0
**Project**: hal-9000 (Claude Code Plugin Marketplace - DinD Architecture)
**Epic Status**: ✅ COMPLETE (54/54 beads)
**Protocol Last Updated**: 2026-01-26

This document defines how agents should interact with the hal-9000 project, where information is stored, and what context to load at session start.

## Session Startup (RECEIVE)

When beginning work on this project, follow this protocol in order:

### Step 1: Load Project Metadata
```bash
# Check current epic status
bd show hal-9000-f6t

# List all beads (should show all ✓ COMPLETE)
bd list | grep hal-9000

# Verify project structure
ls -la .pm/
```

**Expected State**: Epic hal-9000-f6t shows COMPLETE. All 54 sub-beads are closed.

### Step 2: Read Current Context
Start with these files in order:
1. **PROJECT-CONTINUATION.md** ← START HERE (this session info)
2. **PROJECT-COMPLETION.md** ← What was accomplished
3. **CONTEXT_PROTOCOL.md** ← This file (how to work here)

### Step 3: Understand Architecture
Review these for technical context:
1. `.pm/plans/dind-orchestration-plan.md` - Full architecture design
2. `.pm/spikes/p0-go-no-go-decision.md` - Why design is this way
3. `plugins/hal-9000/docs/dind/ARCHITECTURE.md` - Implementation details

### Step 4: Reference Documentation
For working on the project:
1. `plugins/hal-9000/docs/dind/` - User/dev documentation
2. `.pm/METHODOLOGY.md` - Engineering discipline for this project
3. `.pm/AGENT_INSTRUCTIONS.md` - Agent coordination patterns

### Step 5: Check ChromaDB/Memory Bank
```bash
# Check any stored knowledge about this project
# (Usually empty after epic completion, but check for recent findings)
```

**Not Required After Epic Completion**: Memory Bank for hal-9000_active should be empty. ChromaDB may have decision records.

## Working on the Project (PRODUCE)

### Creating New Work
When starting new features or bug fixes:

1. **Create Bead**
   ```bash
   bd create "Feature/Bug: Clear description" -t feature|bug|task
   bd dep add <id> hal-9000-f6t  # Link to epic for traceability
   ```

2. **Update Documentation**
   - User guides: `plugins/hal-9000/docs/dind/`
   - Docker reference: `plugins/hal-9000/docker/README-dind.md`
   - Implementation: scripts and Dockerfiles

3. **Update Project Management**
   - Add to beads for tracking
   - Update `.pm/PROJECT-COMPLETION.md` if scope changes
   - Document new decisions in `.pm/spikes/` or `.pm/plans/`

### Code/Documentation Changes
**Primary Locations**:
- Dockerfiles and scripts: `plugins/hal-9000/docker/`
- User documentation: `plugins/hal-9000/docs/dind/`
- Architecture diagrams: `.pm/plans/` or docs/dind/
- Testing: `.pm/E2E-TESTING-RESULTS.md` (reference, don't edit directly)

**Commit Message Format**:
```
Brief description of change

- Detailed bullet point 1
- Detailed bullet point 2

References: <bead-id>
```

### Document Updates Needed
When making architectural changes:
1. Update `.pm/PROJECT-COMPLETION.md` Future Work section
2. Create spike for investigation: `.pm/spikes/phase7-*.md`
3. Create new plan if scope changes: `.pm/plans/dind-*.md`
4. Update user guides: `plugins/hal-9000/docs/dind/`

## Storing Findings (ChromaDB)

For validated discoveries about the project:

```
Document ID: decision::dind::<topic>
Example: decision::dind::worker-image-optimization

Metadata:
  type: architecture|bug-fix|enhancement|testing
  phase: 0|1|2|3|4|5|6|7+
  verified: yyyy-mm-dd
  reference_bead: hal-9000-f6t.X.Y
```

**Example**: After investigating an issue
```
ID: debug::dind::dockerfile-layer-caching
Content: "Optimization: Multi-stage builds reduce parent image from 300MB to 264MB..."
Metadata: {type: optimization, phase: 1, verified: 2026-01-26}
```

## Handoff Protocol (To Other Agents)

If delegating work to another agent, use this format:

```
## Handoff: [Agent Name]

**Task**: [1-2 sentence summary of what needs doing]
**Bead**: [ID] (status: in_progress)

### Input Artifacts
- **ChromaDB**: [Document IDs or "none"]
- **Memory Bank**: [File paths or "none"]
- **Files**: [Key files touched, with line numbers if applicable]
- **.pm/**: [Relevant planning docs]

### Deliverable
[What agent should produce - code/docs/test results]

### Quality Criteria
- [ ] Criterion 1 with specific measurable requirement
- [ ] Criterion 2 with specific measurable requirement
- [ ] Tests passing: [specific test suite or percentage]

### Context Notes
- Docker/Linux platform required
- See METHODOLOGY.md for engineering standards
- Reference E2E-TESTING-RESULTS.md for known scenarios
- [Any blockers or special constraints]
```

## Project Structure Reference

### Knowledge Hierarchy
1. **ChromaDB** - Validated architectural decisions and findings
2. **Project Management** - `.pm/` directory with planning and tracking
3. **Documentation** - `plugins/hal-9000/docs/dind/` for users
4. **Implementation** - `plugins/hal-9000/docker/` and claudy scripts
5. **Testing** - `.pm/E2E-TESTING-RESULTS.md` for known scenarios

### Key Directories
```
.pm/
├── PROJECT-COMPLETION.md    # What was accomplished (READ FIRST)
├── PROJECT-CONTINUATION.md  # Current status (READ THIS)
├── CONTEXT_PROTOCOL.md      # This file
├── METHODOLOGY.md           # Engineering discipline
├── AGENT_INSTRUCTIONS.md    # Agent patterns for this project
├── archive/                 # Historical session files
│   ├── CONTINUATION-PHASE0.md
│   ├── SESSION-SUMMARY-*.md
│   └── README.md
├── spikes/                  # Phase 0 validation findings
│   ├── p0-go-no-go-decision.md
│   ├── p0-1-mcp-transport-research.md
│   ├── p0-3-network-namespace-poc.md
│   └── p0-4-worker-image-prototype.md
└── plans/                   # Architecture planning
    ├── dind-orchestration-plan.md
    └── dind-orchestration-plan-AUDIT.md

plugins/hal-9000/
├── docs/dind/               # USER/DEV GUIDES (START HERE FOR USAGE)
│   ├── README.md            # Quick start
│   ├── INSTALLATION.md      # Setup guide
│   ├── CONFIGURATION.md     # Options/environment variables
│   ├── ARCHITECTURE.md      # Technical design
│   ├── MIGRATION.md         # Upgrade from v0.5.x
│   ├── DEVELOPMENT.md       # Contributing and extending
│   └── TROUBLESHOOTING.md   # Debug help
└── docker/                  # IMPLEMENTATION FILES
    ├── README-dind.md       # Docker reference
    ├── Dockerfile.parent    # Parent container
    ├── Dockerfile.worker-*  # Worker container variants
    ├── *entrypoint.sh       # Startup scripts
    ├── spawn-worker.sh      # Worker launcher
    ├── coordinator.sh       # Lifecycle management
    ├── pool-manager.sh      # Optional worker pooling
    └── [other scripts]
```

### Critical Files by Purpose

**Architecture & Decisions**:
- `.pm/plans/dind-orchestration-plan.md` - Complete architecture
- `.pm/spikes/p0-go-no-go-decision.md` - Why this design
- `plugins/hal-9000/docs/dind/ARCHITECTURE.md` - Implementation

**Using DinD**:
- `plugins/hal-9000/docs/dind/README.md` - Quick start
- `plugins/hal-9000/docs/dind/INSTALLATION.md` - Setup
- `plugins/hal-9000/docs/dind/TROUBLESHOOTING.md` - Debug

**Extending/Developing**:
- `plugins/hal-9000/docs/dind/DEVELOPMENT.md` - Contributing
- `plugins/hal-9000/docker/README-dind.md` - Docker details
- `.pm/METHODOLOGY.md` - Engineering standards

## Common Scenarios

### "I need to understand the architecture"
1. Read: `.pm/plans/dind-orchestration-plan.md`
2. Review: `.pm/spikes/p0-go-no-go-decision.md`
3. Study: `plugins/hal-9000/docs/dind/ARCHITECTURE.md`
4. Check: `plugins/hal-9000/docker/Dockerfile.*`

### "I'm implementing a new feature"
1. Create bead: `bd create "Feature: X" -t feature`
2. Review: `.pm/METHODOLOGY.md`
3. Code in: `plugins/hal-9000/docker/` or `plugins/hal-9000/docs/dind/`
4. Test: Follow E2E-TESTING-RESULTS.md patterns
5. Document: Update relevant guide in `docs/dind/`

### "Something's broken"
1. Check: `plugins/hal-9000/docs/dind/TROUBLESHOOTING.md`
2. Review: `.pm/E2E-TESTING-RESULTS.md` for similar scenarios
3. Create: `bd create "Bug: X" -t bug`
4. Investigate: Reference `.pm/spikes/` for root causes
5. Test: Verify against E2E suite

### "I'm debugging a test failure"
1. Reference: `.pm/E2E-TESTING-RESULTS.md` section "Overall Results"
2. Check: `.pm/REAL-E2E-WORKFLOW-TEST.md` for workflow
3. See: `.pm/TESTING-PLAN.md` for test scenarios
4. Create: `bd create "Test: X" -t task` for investigation

### "I'm starting Phase 7+ work"
1. Read: `.pm/PROJECT-COMPLETION.md` → "Future Work Recommendations"
2. Spike: Create exploration bead for research
3. Plan: Create new phase plan in `.pm/plans/`
4. Track: Create main phase bead with sub-tasks

## Context Recovery

If session context is missing or unclear:

1. **Check beads**: `bd show hal-9000-f6t --children` - should all be ✓ COMPLETE
2. **Read files in order**:
   - PROJECT-CONTINUATION.md (current state)
   - PROJECT-COMPLETION.md (what was done)
   - CONTEXT_PROTOCOL.md (this file)
3. **Review architecture**:
   - `.pm/plans/dind-orchestration-plan.md`
   - `.pm/spikes/p0-go-no-go-decision.md`
4. **Check implementation**:
   - `plugins/hal-9000/docker/README-dind.md`
   - `plugins/hal-9000/docs/dind/README.md`

## References to Other Projects

This project is part of the larger hal-9000 plugin marketplace. Related projects:
- **Main project**: hal-9000 (this project)
- **Related projects**: Check plugin.json for dependencies
- **Users of this**: Any project using DinD architecture for Claude sessions

## Notes

- **Epic Status**: Complete (all 54 beads closed)
- **No Active Sessions**: Memory Bank should be empty
- **Recent Work**: Knowledge tidying consolidation (2026-01-26)
- **Next Work**: Phase 7+ features (not yet planned)

---

**Version**: 1.0
**Last Updated**: 2026-01-26
**Created By**: Knowledge Tidying Agent
**Applies To**: All agents working on hal-9000 project

Questions? See `.pm/PROJECT-CONTINUATION.md` for how to proceed.
