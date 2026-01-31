# Claudy Implementation - Beads Tracking

## Epic: CLAUDY-IMPL-PHASE1
**Title**: Claudy Phase 1 - Core Foundation
**Status**: pending → in_progress
**Duration**: Weeks 1-2

### Week 1: Core Script and Profile Detection

#### CLAUDY-IMPL-1-1: Implement claudy core launcher script
**Type**: feature
**Effort**: 8-10 hours
**Dependencies**: None
**Success Criteria**:
- [ ] Bash script (150-200 lines) created at `claudy`
- [ ] Handles: --profile, --help, --verify, --diagnose
- [ ] Error handling with descriptive messages
- [ ] shellcheck clean (no warnings)
- [ ] Works on macOS and Linux

**Deliverables**:
- `claudy` executable script
- Error messages documented
- Usage examples in --help

**Context**: See claudy-foundation.md, claudy-feature-exposure-design.md

---

#### CLAUDY-IMPL-1-2: Implement auto-profile detection
**Type**: feature
**Effort**: 4-6 hours
**Dependencies**: CLAUDY-IMPL-1-1 (partial)
**Success Criteria**:
- [ ] Detects: Java (pom.xml, build.gradle)
- [ ] Detects: Python (pyproject.toml, Pipfile)
- [ ] Detects: Node (package.json)
- [ ] Falls back to: base profile
- [ ] 95%+ accuracy on test projects

**Deliverables**:
- `detect_profile()` function in claudy
- Test cases with 10 sample projects
- Documentation

**Context**: See claudy-installation-setup.md (section "Auto-Profile Detection Logic")

---

#### CLAUDY-IMPL-1-3: Implement session management (per-project isolation)
**Type**: feature
**Effort**: 6-8 hours
**Dependencies**: CLAUDY-IMPL-1-1 (partial)
**Success Criteria**:
- [ ] Sessions stored in ~/.hal9000/claude/{project-name}/
- [ ] Each session has isolated .claude directory
- [ ] Session name deterministic from project path
- [ ] Cleanup (remove old sessions) functional

**Deliverables**:
- `init_container_session()` function
- Session directory structure
- Cleanup utility
- Tests for isolation

**Context**: See claudy-authentication-revised.md, claudy-installation-setup.md

---

### Week 2: Authentication and Basic Error Handling

#### CLAUDY-IMPL-2-1: Implement session authentication (copy host ~/.claude/)
**Type**: feature
**Effort**: 8-10 hours
**Dependencies**: CLAUDY-IMPL-1-3
**Success Criteria**:
- [ ] Copies ~/.claude/.session.json to container
- [ ] Copies ~/.claude/settings.json
- [ ] Copies ~/.claude/CLAUDE.md
- [ ] Copies ~/.claude/agents/
- [ ] Does NOT copy hooks/ or credentials/
- [ ] Handles missing host session gracefully
- [ ] File permissions set correctly (chmod 600 for .session.json)

**Deliverables**:
- `setup_authentication()` function
- Permission handling code
- Missing session recovery
- Tests

**Context**: See claudy-authentication-revised.md (core model section)

---

#### CLAUDY-IMPL-2-2: Implement installation script
**Type**: feature
**Effort**: 4-6 hours
**Dependencies**: CLAUDY-IMPL-1-1, CLAUDY-IMPL-1-2
**Success Criteria**:
- [ ] Install script (50-80 lines) created
- [ ] Copies claudy to /usr/local/bin (or equivalent)
- [ ] Makes it executable
- [ ] Works on macOS, Linux (Ubuntu/Debian/Fedora), WSL2
- [ ] Includes verification step

**Deliverables**:
- `install-claudy.sh` script
- Uninstall script
- Cross-platform verification

**Context**: See claudy-installation-setup.md (installation methods section)

---

#### CLAUDY-IMPL-2-3: Implement error handling and help system
**Type**: feature
**Effort**: 6-8 hours
**Dependencies**: CLAUDY-IMPL-1-1 (core)
**Success Criteria**:
- [ ] All errors have descriptive messages
- [ ] --help provides clear usage info
- [ ] --verify checks all prerequisites
- [ ] --diagnose identifies common issues
- [ ] Error codes documented (0=success, 1=error, 2=skipped)

**Deliverables**:
- Help text for all modes
- Error message catalog
- Verification checklist
- Diagnostic flowchart
- Tests for error scenarios

**Context**: See claudy-installation-setup.md (error handling section)

---

#### CLAUDY-IMPL-2-4: Cross-platform testing (Phase 1)
**Type**: task
**Effort**: 6-8 hours
**Dependencies**: All Phase 1 features
**Success Criteria**:
- [ ] Tests on macOS (bash 5.1+)
- [ ] Tests on Linux Ubuntu 22.04 (bash 5.1+)
- [ ] Tests on WSL2 (bash 5.0+)
- [ ] All core functions working
- [ ] No permission dialogs
- [ ] Session isolation verified
- [ ] Auto-profile detection verified

**Deliverables**:
- Test results document
- Platform-specific notes
- Known issues (if any)

**Context**: See claudy-installation-setup.md (platform-specific setup section)

---

## Pending Phases

### Phase 2: Enhanced Features (Weeks 3-4)
- [ ] Configuration system (.claudyrc)
- [ ] Multi-project coordination
- [ ] Environment variable inheritance
- [ ] Profile customization

### Phase 3: Power Features (Weeks 5-6)
- [ ] MCP server integration
- [ ] Skills (/wrap, /sup, /fragile)
- [ ] Advanced orchestration
- [ ] Knowledge storage (chroma-search)

---

**Next**: Update beads as work progresses. Mark complete when all Phase 1 success criteria met.
