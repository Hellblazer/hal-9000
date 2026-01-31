# HAL-9000 Comprehensive Testing Initiative
## Project Management Infrastructure Specification

**Project**: hal-9000-testing-comprehensive
**Scope**: Build complete automated test suite for hal-9000 CLI command
**Duration**: 3-4 weeks
**Estimated Effort**: 120-150 hours
**Team**: 1-2 engineers
**Complexity**: High (distributed system, Docker, multiple subsystems)
**Status**: PLANNING - Ready for infrastructure creation

---

## Executive Summary

This document defines the complete project management infrastructure for the hal-9000-testing-comprehensive initiative. It provides:

- **Phase breakdown** (5 phases over 3-4 weeks)
- **Bead strategy** (229+ test cases organized by category)
- **Success metrics** (quantifiable outcomes)
- **Agent collaboration** (handoff protocols)
- **Quality gates** (each phase has clear acceptance criteria)
- **Risk management** (critical blockers and mitigation)

**What to Do Next**: Use the templates below to create the `.pm/` directory structure with all files listed in Section 2.

---

## 1. Project Structure Overview

### 1.1 Scope & Test Categories

The comprehensive test suite covers 229+ test cases across these categories:

| Category | Tests | Coverage | Duration |
|----------|-------|----------|----------|
| **Unit Tests** | 45 | CLI argument parsing, validation, formatting | 15-20 min |
| **Integration Tests** | 78 | Container lifecycle, volume management, session isolation | 45-60 min |
| **Error Scenarios** | 42 | Edge cases, failure modes, recovery | 25-35 min |
| **Performance Tests** | 28 | Startup time, memory usage, throughput | 10-15 min |
| **Cross-Platform** | 21 | macOS, Linux, WSL2 compatibility | 30-45 min |
| **Docker Subsystem** | 12 | Image building, layer caching, registry operations | 15-20 min |
| **Smoke Tests (CI)** | 3 | Quick validation for GitHub Actions | <5 min |
| **TOTAL** | **229** | **Comprehensive coverage** | **~2.5 hours local** |

**CI/CD Target**: ~5 minutes (smoke tests + critical path)

### 1.2 Technology Stack

- **Test Framework**: Bash/bats (Bash Automated Testing System)
- **Container Management**: Docker + docker-compose
- **CI/CD**: GitHub Actions
- **Monitoring**: Test logs, coverage reports, performance metrics
- **Infrastructure**: Docker, tmux, Bash 5.0+

### 1.3 Success Criteria (Quantifiable)

**Phase Completion**:
- [ ] Phase 1: 45 unit tests passing (100% pass rate)
- [ ] Phase 2: 78 integration tests passing (95%+ pass rate)
- [ ] Phase 3: 42 error scenario tests passing (100% pass rate)
- [ ] Phase 4: CI/CD pipeline running all tests in <5 minutes
- [ ] Phase 5: 90%+ test pass rate in first CI run

**Quality Gates**:
- [ ] Zero flaky tests (tests fail/pass consistently)
- [ ] <100ms per test average (no long-running tests)
- [ ] All tests properly isolated (no test dependencies)
- [ ] 100% documentation of test purpose and assertions
- [ ] All critical blockers from plan-auditor addressed

**Performance Benchmarks**:
- [ ] Local full test run: <2.5 hours
- [ ] CI quick tests: <5 minutes
- [ ] Individual test: <100ms (median)
- [ ] Container startup: <3 seconds
- [ ] Memory per test: <500 MB

---

## 2. .pm/ Directory Structure & Files

### 2.1 Create These Files in `.pm/` Directory

```
.pm/
├── EXECUTION_STATE.md              # Current phase, status, metrics
├── CONTINUATION.md                 # Resumption context after break
├── METHODOLOGY.md                  # Engineering discipline, test approach
├── AGENT_INSTRUCTIONS.md           # How to work with agents
├── CONTEXT_PROTOCOL.md             # Session handoff format
├── TESTING-STRATEGY.md             # Test categories, organization, CI/CD
├── DEPENDENCIES.md                 # Critical path, blockers, sequencing
├── RESOURCES.md                    # Tools, infrastructure, access
│
├── checkpoints/                    # Progress tracking
│   ├── TEMPLATE-checkpoint.md      # Template for daily checkpoints
│   └── phase-1-checkpoint.md       # Completed after Phase 1
│
├── learnings/                      # Accumulated knowledge
│   ├── TEMPLATE-learning.md        # Template for lessons learned
│   └── testing-patterns.md         # Test patterns discovered
│
├── hypotheses/                     # Architectural decisions
│   ├── TEMPLATE-hypothesis.md      # Template for test decisions
│   └── test-isolation-strategy.md  # How to isolate tests
│
├── audits/                         # Quality gates
│   ├── TEMPLATE-audit.md           # Template for audit reports
│   └── phase-gate-checklist.md     # Phase acceptance criteria
│
├── thinking/                       # Deep analysis
│   └── test-architecture-analysis.md # Thinking on test design
│
└── metrics/                        # Performance tracking
    ├── test-performance.md         # Test execution times
    ├── pass-rate-tracking.md       # Test pass rates
    └── coverage-metrics.md         # Test coverage by component
```

### 2.2 Core Files (Must Create First)

These are the **essential files** needed before starting work:

1. **EXECUTION_STATE.md** - Central tracking (see Template 1)
2. **CONTINUATION.md** - Resumption guide (see Template 2)
3. **METHODOLOGY.md** - Engineering standards (see Template 3)
4. **TESTING-STRATEGY.md** - Test organization (see Template 4)
5. **CONTEXT_PROTOCOL.md** - Agent handoff format (see Template 5)

---

## 3. Phase Definitions

### Phase 1: Foundation & Unit Tests (Week 1)
**Duration**: 5 days
**Effort**: 30-40 hours
**Goal**: Establish test framework and basic unit tests

**Deliverables**:
- [ ] Test framework (bats) setup and configuration
- [ ] 45 unit tests for CLI argument parsing
- [ ] Test utilities library (helper functions)
- [ ] CI/CD workflow stub (GitHub Actions)
- [ ] Test documentation and patterns

**Key Beads**:
- HAL-TEST-001: Set up bats framework and test structure
- HAL-TEST-002: Implement argument parsing unit tests (45 tests)
- HAL-TEST-003: Create test utilities and helper functions
- HAL-TEST-004: Create GitHub Actions workflow skeleton

**Success Criteria**:
- [x] 45 unit tests passing (100% pass rate)
- [x] All tests run in <3 minutes locally
- [x] Test documentation complete
- [x] CI workflow triggers on PR

**Quality Gate**: All unit tests pass, zero test dependencies

---

### Phase 2: Integration & Container Tests (Week 2-3)
**Duration**: 8-9 days
**Effort**: 40-50 hours
**Goal**: Comprehensive integration testing

**Deliverables**:
- [ ] 78 integration tests for container lifecycle
- [ ] Docker volume management tests
- [ ] Session isolation verification tests
- [ ] Cross-platform test matrix (macOS, Linux, WSL2)
- [ ] Test infrastructure for parallel execution

**Key Beads**:
- HAL-TEST-005: Implement container lifecycle tests (25 tests)
- HAL-TEST-006: Implement volume management tests (20 tests)
- HAL-TEST-007: Implement session isolation tests (18 tests)
- HAL-TEST-008: Implement cross-platform matrix tests (15 tests)

**Success Criteria**:
- [x] 78 integration tests passing (95%+ pass rate)
- [x] All tests properly isolated (no dependencies between tests)
- [x] Tests run on macOS, Linux, WSL2
- [x] Parallel execution working (<1.5 hours for all 123 tests)

**Quality Gate**: 95%+ pass rate, tests run in parallel, zero flaky tests

---

### Phase 3: Error Handling & Edge Cases (Week 3)
**Duration**: 5-6 days
**Effort**: 30-40 hours
**Goal**: Comprehensive error scenario testing

**Deliverables**:
- [ ] 42 error scenario tests
- [ ] Edge case coverage (long paths, special characters, etc.)
- [ ] Recovery scenario testing
- [ ] Error message validation
- [ ] Test result documentation

**Key Beads**:
- HAL-TEST-009: Implement error scenario tests (25 tests)
- HAL-TEST-010: Implement edge case tests (17 tests)
- HAL-TEST-011: Document error scenarios and recovery

**Success Criteria**:
- [x] 42 error scenario tests passing (100% pass rate)
- [x] All documented edge cases covered
- [x] Recovery procedures validated
- [x] Error messages clear and actionable

**Quality Gate**: 100% pass rate, all edge cases documented

---

### Phase 4: Performance & CI/CD Integration (Week 4)
**Duration**: 5-6 days
**Effort**: 25-35 hours
**Goal**: Performance benchmarking and CI/CD pipeline

**Deliverables**:
- [ ] 28 performance tests
- [ ] Performance baseline established
- [ ] GitHub Actions pipeline complete
- [ ] Test reporting and metrics dashboard
- [ ] Flaky test detection

**Key Beads**:
- HAL-TEST-012: Implement performance tests (28 tests)
- HAL-TEST-013: Complete GitHub Actions CI/CD pipeline
- HAL-TEST-014: Set up performance metrics tracking
- HAL-TEST-015: Create test reporting dashboard

**Success Criteria**:
- [x] Performance tests establishing baseline
- [x] CI/CD pipeline running all tests in <5 minutes (quick path)
- [x] Performance metrics tracked
- [x] No flaky tests detected (0 test failures in 10 consecutive runs)

**Quality Gate**: <5 minute CI/CD runs, zero flaky tests, metrics established

---

### Phase 5: Documentation & Handoff (1 week)
**Duration**: 4-5 days
**Effort**: 15-20 hours
**Goal**: Complete documentation and knowledge transfer

**Deliverables**:
- [ ] Comprehensive test documentation
- [ ] Test troubleshooting guide
- [ ] Performance baseline documentation
- [ ] Maintenance procedures
- [ ] Knowledge transfer to team

**Key Beads**:
- HAL-TEST-016: Document test suite comprehensively
- HAL-TEST-017: Create troubleshooting guide
- HAL-TEST-018: Document maintenance procedures
- HAL-TEST-019: Knowledge transfer and handoff

**Success Criteria**:
- [x] All tests documented with purpose and assertions
- [x] Troubleshooting guide covers common issues
- [x] Maintenance procedures clear
- [x] Team trained on test suite

**Quality Gate**: Complete documentation, team ready for maintenance

---

## 4. Bead Strategy

### 4.1 Bead Organization

All work is tracked through beads with this structure:

```
Bead ID: HAL-TEST-NNN
Title: [Clear, actionable title]
Type: feature (use 'feature' for all test bead categories)
Priority: 1-3 (1=critical, 2=important, 3=nice-to-have)
Phase: 1-5
Status: ready → in_progress → completed

Dependencies:
- HAL-TEST-XXX (if bead depends on another)

Acceptance Criteria:
- [ ] Criterion 1 (testable, specific)
- [ ] Criterion 2 (with measurement)

Design:
- Test framework used
- Test patterns applied
- Integration points
- Context links: .pm/TESTING-STRATEGY.md

Files to Modify:
- test/unit/argument-parsing.bats
- test/lib/helpers.sh
- .github/workflows/test.yml

Patterns to Follow:
- See .pm/TESTING-STRATEGY.md for test patterns
- Link to example tests in codebase
```

### 4.2 Bead Categories

| Category | Beads | Purpose |
|----------|-------|---------|
| **Infrastructure** | HAL-TEST-001, HAL-TEST-013 | Test framework, CI/CD setup |
| **Unit Tests** | HAL-TEST-002 | CLI argument parsing (45 tests) |
| **Integration** | HAL-TEST-005 to HAL-TEST-008 | Container, volume, session, platform |
| **Error Handling** | HAL-TEST-009, HAL-TEST-010 | Error scenarios, edge cases |
| **Performance** | HAL-TEST-012, HAL-TEST-014 | Benchmarking, metrics |
| **Documentation** | HAL-TEST-003, HAL-TEST-016 to HAL-TEST-019 | Guides, procedures, handoff |

### 4.3 Critical Path (Minimum for Release)

**Must Complete**:
1. HAL-TEST-001 (test framework setup)
2. HAL-TEST-002 (unit tests)
3. HAL-TEST-005, HAL-TEST-006 (core integration)
4. HAL-TEST-013 (CI/CD pipeline)

**If Running Behind**:
- Defer: Performance tests (HAL-TEST-012)
- Defer: Detailed documentation (Phase 5)
- Prioritize: Core integration tests, CI/CD

---

## 5. Test Categories in Detail

### 5.1 Unit Tests (45 tests)

**Bead**: HAL-TEST-002
**File**: `test/unit/argument-parsing.bats`

**Categories** (organized by CLI function):

**Argument Parsing (15 tests)**:
- [ ] Parse project path correctly
- [ ] Parse profile selection (base, python, node, java)
- [ ] Parse Docker options
- [ ] Parse Claude subcommands
- [ ] Reject invalid profiles
- [ ] Handle missing arguments
- [ ] Handle extra arguments
- [ ] Parse environment variables
- [ ] Parse config file options
- [ ] Merge config + CLI args
- [ ] Validate argument combinations
- [ ] Handle special characters in paths
- [ ] Handle quoted arguments
- [ ] Handle long paths (>256 chars)
- [ ] Handle paths with spaces

**Validation (15 tests)**:
- [ ] Validate project directory exists
- [ ] Validate project directory is readable
- [ ] Validate profile supported
- [ ] Validate Docker image exists
- [ ] Validate Docker daemon running
- [ ] Validate Docker socket readable
- [ ] Validate tmux installed
- [ ] Validate bash version 5.0+
- [ ] Validate disk space available
- [ ] Validate permissions
- [ ] Validate network connectivity
- [ ] Validate volume names valid
- [ ] Validate session names unique
- [ ] Validate config file format
- [ ] Validate API key format (if provided)

**Formatting & Output (15 tests)**:
- [ ] Format error messages correctly
- [ ] Format success messages correctly
- [ ] Format warning messages correctly
- [ ] Format info messages correctly
- [ ] Colorize output correctly (when TTY)
- [ ] Handle non-TTY output (no colors)
- [ ] Format help text correctly
- [ ] Format version output
- [ ] Format JSON output (when requested)
- [ ] Format table output for lists
- [ ] Handle long output lines (wrap correctly)
- [ ] Handle empty output
- [ ] Handle special characters in output
- [ ] Escape shell metacharacters
- [ ] Handle unicode characters

---

### 5.2 Integration Tests (78 tests)

**Container Lifecycle (25 tests)** - Bead HAL-TEST-005:
- [ ] Start parent container successfully
- [ ] Verify parent container running
- [ ] Create worker session in parent
- [ ] Verify worker session active
- [ ] Attach to existing session
- [ ] Detach from session gracefully
- [ ] Stop worker session
- [ ] Stop parent container gracefully
- [ ] Handle parent already running
- [ ] Handle session already exists
- [ ] Handle container restart
- [ ] Handle docker daemon restart
- [ ] Clean up containers on error
- [ ] Handle interruption (Ctrl+C)
- [ ] Handle timeout scenarios
- [ ] Verify container resource limits
- [ ] Check container security settings
- [ ] Verify container logs available
- [ ] Check container status reporting
- [ ] Handle container upgrade path
- [ ] Verify container environment variables
- [ ] Check Claude session variables
- [ ] Validate tmux session configuration
- [ ] Verify session persistence
- [ ] Test session recovery after crash

**Volume Management (20 tests)** - Bead HAL-TEST-006:
- [ ] Create volume if missing
- [ ] Use existing volume if present
- [ ] Mount volume correctly
- [ ] Verify volume accessible in container
- [ ] Verify volume accessible from host
- [ ] Check volume permissions (600 for auth)
- [ ] Verify data persists across sessions
- [ ] Handle volume full scenario
- [ ] Handle volume permission denied
- [ ] Handle volume stale handle
- [ ] Verify volume isolation between projects
- [ ] Check volume cleanup on error
- [ ] Handle volume deletion
- [ ] Verify volume size limits
- [ ] Test volume mount options
- [ ] Verify ChromaDB volume functionality
- [ ] Test Memory Bank volume access
- [ ] Check session volume isolation
- [ ] Verify volume backup strategy
- [ ] Test volume snapshot/restore

**Session Isolation (18 tests)** - Bead HAL-TEST-007:
- [ ] Project A session isolated from B
- [ ] Different workspaces per project
- [ ] Different session names per project
- [ ] Claude environment isolated
- [ ] History isolated per session
- [ ] Plugins isolated per session
- [ ] Configuration isolated per session
- [ ] No cross-project file access
- [ ] No cross-project memory access
- [ ] Process isolation verified
- [ ] Network isolation verified (if applicable)
- [ ] Volume access restricted
- [ ] No credential leakage
- [ ] Session cleanup on exit
- [ ] Handle concurrent sessions
- [ ] Verify session deterministic naming
- [ ] Test hash collision handling
- [ ] Verify reattachment to same session

**Cross-Platform Tests (15 tests)** - Bead HAL-TEST-008:
- [ ] macOS: Docker Desktop integration
- [ ] macOS: Homebrew installation
- [ ] macOS: File path handling
- [ ] Linux: systemd socket integration
- [ ] Linux: SELinux compatibility
- [ ] Linux: AppArmor compatibility
- [ ] WSL2: Volume mounting
- [ ] WSL2: Docker socket access
- [ ] WSL2: File path conversion
- [ ] Path expansion (~/projects)
- [ ] Symlink handling
- [ ] Case-sensitive filesystems
- [ ] File permissions (755, 600)
- [ ] Line endings (CRLF vs LF)
- [ ] Locale/encoding handling

---

### 5.3 Error Scenario Tests (42 tests)

**Error Scenarios (25 tests)** - Bead HAL-TEST-009:
- [ ] Invalid project directory
- [ ] Project directory doesn't exist
- [ ] Project directory not readable
- [ ] Project directory is file (not dir)
- [ ] Missing Docker daemon
- [ ] Docker daemon permission denied
- [ ] Docker image not found
- [ ] Docker image pull fails
- [ ] Insufficient disk space
- [ ] Insufficient memory
- [ ] Port conflicts (port already in use)
- [ ] Volume mount fails
- [ ] tmux not installed
- [ ] Bash version too old
- [ ] Invalid profile specified
- [ ] Invalid container image name
- [ ] Network connectivity issues
- [ ] DNS resolution fails
- [ ] Registry authentication fails
- [ ] Container startup timeout
- [ ] Container OOM kill
- [ ] Container segfault
- [ ] Container exit on signal
- [ ] Broken pipe errors
- [ ] Connection refused

**Edge Cases (17 tests)** - Bead HAL-TEST-010:
- [ ] Very long path (>4096 chars)
- [ ] Path with spaces and special chars
- [ ] Path with unicode characters
- [ ] Project name with leading dash
- [ ] Project name with spaces
- [ ] Session name collision
- [ ] Volume name collision
- [ ] Container name collision
- [ ] Empty project directory
- [ ] Directory with many files (>10k)
- [ ] Read-only filesystem
- [ ] No write permissions
- [ ] Symbolic links in path
- [ ] Hard links in data
- [ ] Circular directory references
- [ ] Very old container image
- [ ] Concurrent launches of same project

---

### 5.4 Performance Tests (28 tests)

**Startup Performance** (10 tests):
- [ ] Cold start time <3 seconds
- [ ] Warm start time <1 second
- [ ] Session reattach <500ms
- [ ] Parent container creation <5 seconds
- [ ] Worker session spawn <1 second
- [ ] Volume mount overhead <200ms
- [ ] CLI parsing <50ms
- [ ] Validation checks <100ms
- [ ] Docker command execution <500ms
- [ ] Startup scalability (10 sequential sessions)

**Memory Usage** (8 tests):
- [ ] Parent container <1GB
- [ ] Worker session <800MB
- [ ] Shared volumes <500MB
- [ ] CLI script <10MB
- [ ] Memory per concurrent session
- [ ] No memory leaks over 10+ sessions
- [ ] GC after session cleanup
- [ ] Memory under load (10 sessions)

**Throughput & Scalability** (10 tests):
- [ ] Handle 10 concurrent sessions
- [ ] Handle 50 sequential sessions
- [ ] Volume I/O: 1000 ops/sec
- [ ] Container spawn: 2 per second
- [ ] Session creation rate: 1 per second
- [ ] File mount throughput: 100 MB/s
- [ ] Docker command concurrency
- [ ] Resource cleanup after 100 sessions
- [ ] No degradation over 24h uptime
- [ ] Rebalance after session exit

---

### 5.5 Docker Subsystem Tests (12 tests)

- [ ] Build parent image successfully
- [ ] Build worker image successfully
- [ ] Image layer caching works
- [ ] Image size within limits (<3GB parent, <500MB worker)
- [ ] Image scan for vulnerabilities (no critical)
- [ ] Image push to registry
- [ ] Image pull from registry
- [ ] Multi-platform build (linux/amd64, linux/arm64)
- [ ] Registry authentication
- [ ] Registry timeout handling
- [ ] Rollback to previous image
- [ ] Image garbage collection

---

### 5.6 Smoke Tests for CI (3 tests)

**Quick validation in GitHub Actions**:
- [ ] Bash syntax validation (shellcheck)
- [ ] Docker image build succeeds
- [ ] CLI help command works
- [ ] (Run in <5 minutes)

---

## 6. Success Metrics & KPIs

### 6.1 Test Coverage Metrics

| Metric | Target | Method |
|--------|--------|--------|
| **Test Count** | 229 total | Count all test cases |
| **Unit Tests** | 45 passing | bats test count |
| **Integration Tests** | 78 passing | bats test count |
| **Error Tests** | 42 passing | bats test count |
| **Performance Tests** | 28 passing | bats test count |
| **Pass Rate** | 90%+ first run | (Passing / Total) * 100 |
| **Code Coverage** | 80%+ lines | gcov/coverage.py on hal-9000 |

### 6.2 Performance Metrics

| Metric | Target | Current | Tracked |
|--------|--------|---------|---------|
| **Local Test Run** | <2.5 hours | TBD | metrics/test-performance.md |
| **CI Test Run** | <5 minutes | TBD | GitHub Actions timing |
| **Individual Test** | <100ms median | TBD | bats timing |
| **Container Startup** | <3 seconds | 2s (baseline) | Monitored |
| **Memory per Test** | <500MB | TBD | metrics/memory-usage.md |

### 6.3 Quality Metrics

| Metric | Target | Status |
|--------|--------|--------|
| **Flaky Tests** | 0 (10 consecutive runs) | In progress |
| **Test Dependencies** | 0 | Architecture verified |
| **Test Isolation** | 100% | Design requirement |
| **Documentation** | 100% (all tests documented) | In progress |
| **Blocker Resolution** | 100% (plan-auditor findings) | In progress |

### 6.4 Delivery Metrics

| Metric | Target | Status |
|--------|--------|--------|
| **Phase 1 Complete** | End of Week 1 | Ready to start |
| **Phase 2 Complete** | End of Week 3 | Planned |
| **Phase 3 Complete** | End of Week 3 | Planned |
| **Phase 4 Complete** | End of Week 4 | Planned |
| **Phase 5 Complete** | +1 week buffer | Planned |
| **Total Duration** | 3-4 weeks | On track |

---

## 7. Risk Management

### 7.1 Critical Risks

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|-----------|--------|
| **Docker integration complexity** | Medium | HIGH | Phase 0 validation complete, architecture proven | Mitigated |
| **Test flakiness** | Medium | HIGH | Volume isolation testing, deterministic test data | In progress |
| **Cross-platform issues** | High | MEDIUM | Matrix testing (Mac, Linux, WSL2), platform-specific code | Planned |
| **Performance regression** | Low | MEDIUM | Performance baseline tests, regression detection | Planned |
| **Test maintenance burden** | Medium | MEDIUM | Clear test patterns, helper library, documentation | In progress |

### 7.2 Blockers (from plan-auditor findings)

**Must Address**:
1. [ ] Circular dependency between container startup and volume setup
   - **Mitigation**: Separate bead HAL-TEST-001 (framework) before HAL-TEST-005 (container tests)

2. [ ] Test data isolation (different tests need different container state)
   - **Mitigation**: Each test gets fresh container, volumes, cleanup after each test

3. [ ] CI/CD infrastructure (GitHub Actions not set up)
   - **Mitigation**: HAL-TEST-013 sets up Actions workflow with proper caching

4. [ ] Performance baseline not established
   - **Mitigation**: HAL-TEST-012 establishes baseline before optimization work

5. [ ] No flaky test detection mechanism
   - **Mitigation**: Tests run 5x in CI before marking as stable

---

## 8. Agent Collaboration Protocol

### 8.1 Agent Assignments

**Strategic Planning** (strategic-planner):
- Create phase plans
- Break down work into beads
- Define success criteria

**Implementation** (java-developer or equivalent):
- Write test code
- Implement test framework
- Debug failing tests

**Code Review** (code-review-expert):
- Review test quality
- Check test patterns
- Verify test isolation

**Test Validation** (test-validator):
- Verify test coverage
- Check test completeness
- Validate acceptance criteria

**Plan Auditing** (plan-auditor):
- Audit phase completion
- Check blocker resolution
- Verify quality gates

---

### 8.2 Handoff Format for Agents

```
## Handoff: [Target Agent Name]

**Task**: [Clear 1-2 sentence summary]
**Bead**: [HAL-TEST-NNN] (status: [ready/in_progress])

### Input Artifacts
- ChromaDB: [doc IDs or "none"]
- Memory Bank: [file path or "none"]
- Files: [key files to review]

### Deliverable
[What the agent should produce]

### Quality Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Context Notes
[Special context, blockers, or warnings]

### Critical Dependencies
- Must complete: [other beads]
- Blocked by: [active beads]
```

---

### 8.3 Specific Handoffs

**To Implementation Agent (HAL-TEST-002)**:
```
Task: Implement 45 unit tests for CLI argument parsing
Bead: HAL-TEST-002 (status: ready)
Input: .pm/TESTING-STRATEGY.md, test/lib/helpers.sh from HAL-TEST-003
Deliverable: test/unit/argument-parsing.bats with all 45 tests passing
Quality: 100% pass rate, no test dependencies, <3min runtime
Context: Framework from HAL-TEST-001 must be complete first
```

**To Code Review Agent (Phase 1 checkpoint)**:
```
Task: Review unit test quality and patterns
Bead: HAL-TEST-002 (status: completed)
Input: test/unit/argument-parsing.bats, test/lib/helpers.sh
Deliverable: Code review feedback, pattern compliance report
Quality: All tests follow patterns, isolated, clear assertions
Context: Review for test isolation, no helper dependencies between tests
```

---

## 9. CI/CD Pipeline Design

### 9.1 GitHub Actions Workflow Stages

**Stage 1: Quick Tests** (<5 minutes - runs on every PR):
```yaml
- Syntax validation (shellcheck)
- Docker build check
- Help command validation
```

**Stage 2: Unit Tests** (<3 minutes - runs on every PR):
```yaml
- All 45 unit tests
- No container required
```

**Stage 3: Integration Tests** (<15 minutes - runs on main/branch):
```yaml
- Core container tests (HAL-TEST-005, HAL-TEST-006)
- Session isolation (subset)
```

**Stage 4: Full Tests** (<45 minutes - runs nightly):
```yaml
- All 229 tests
- Performance tests
- Cross-platform matrix
```

### 9.2 Test Execution Order (Dependency Graph)

```
Phase 1: Foundation
  HAL-TEST-001 (framework setup)
    ↓
Phase 1b: Unit Tests
  HAL-TEST-002 (unit tests)
  HAL-TEST-003 (helpers)
    ↓
Phase 2: Integration
  HAL-TEST-005 (container lifecycle)
  HAL-TEST-006 (volume management)
  HAL-TEST-007 (session isolation)
  HAL-TEST-008 (cross-platform)
    ↓
Phase 3: Error Handling
  HAL-TEST-009 (error scenarios)
  HAL-TEST-010 (edge cases)
    ↓
Phase 4: Performance
  HAL-TEST-012 (performance)
  HAL-TEST-013 (CI/CD)
  HAL-TEST-014 (metrics)
    ↓
Phase 5: Documentation
  HAL-TEST-016-019 (docs)
```

---

## 10. Metrics & Tracking

### 10.1 Daily Tracking (checkpoints/)

**File**: `.pm/checkpoints/phase-X-checkpoint.md`

```markdown
# Phase X Checkpoint - [Date]

## Progress Summary
- Tests completed: XX/XX
- Tests passing: XX/XX (X%)
- Time spent: X hours
- Blockers: [if any]

## Work Completed
- [Bead completed]
- [Bead completed]

## Current Blockers
- [Issue 1]: [Impact] - [ETA to resolve]

## Next Actions
- [Action 1]
- [Action 2]

## Metrics Update
- Test performance: X ms median
- Memory usage: X MB
- Pass rate: X%

## Decisions Made
- [Decision 1]: [Rationale]
```

### 10.2 Weekly Status

**File**: `.pm/EXECUTION_STATE.md`

```markdown
# Testing Initiative - Current Execution State

**Project**: hal-9000-testing-comprehensive
**Status**: IN_PROGRESS
**Current Phase**: [1-5]
**Week**: [X/4]
**Overall Progress**: XX%

## Phase Status Table
| Phase | Name | Status | Tests | Pass % | Effort Used |
|-------|------|--------|-------|--------|-------------|
| 1 | Foundation | [status] | 45 | XX% | XX hrs |
| 2 | Integration | [status] | 78 | XX% | XX hrs |
| 3 | Error Handling | [status] | 42 | XX% | XX hrs |
| 4 | Performance | [status] | 28 | XX% | XX hrs |
| 5 | Documentation | [status] | - | - | XX hrs |

## Metrics
- Total tests passing: XXX/229 (XX%)
- Flaky tests: X
- Test execution time: X min (local), X min (CI)
- Blockers: X active

## Quality Gates
- Unit tests: [ ] 45/45 (100%)
- Integration tests: [ ] 74/78 (95%+)
- Error tests: [ ] 42/42 (100%)
- CI/CD: [ ] <5 min runs
- Pass rate first run: [ ] 90%+

## Next Week Goals
- [Goal 1]
- [Goal 2]
```

---

## 11. Templates for .pm/ Files

### Template 1: EXECUTION_STATE.md

```markdown
# Testing Initiative - Execution State

**Project**: hal-9000-testing-comprehensive
**Status**: PLANNING → IN_PROGRESS → COMPLETE
**Start Date**: 2026-01-27
**Target Completion**: 2026-02-24
**Current Phase**: 1 (Foundation & Unit Tests)

## Phase Progress

### Phase 1: Foundation & Unit Tests
- **Duration**: 5 days (Jan 27 - Jan 31)
- **Status**: PLANNING
- **Tests**: 45 unit tests
- **Effort**: 30-40 hours
- **Blockers**: None yet

## Overall Metrics

### Test Coverage
- Unit Tests: 0/45 (0%)
- Integration: 0/78 (0%)
- Error: 0/42 (0%)
- Performance: 0/28 (0%)
- TOTAL: 0/229 (0%)

### Quality Metrics
- Pass Rate: 0% (before start)
- Flaky Tests: 0
- Avg Test Time: TBD
- Total Runtime: TBD

## Key Milestones

| Milestone | Date | Status |
|-----------|------|--------|
| Framework setup complete | 2026-01-29 | Not started |
| 45 unit tests passing | 2026-01-31 | Not started |
| 78 integration tests passing | 2026-02-07 | Not started |
| CI/CD pipeline complete | 2026-02-14 | Not started |
| All docs complete | 2026-02-24 | Not started |

## Known Blockers
None at planning stage.

## Recent Checkpoints
None yet - project just starting.
```

### Template 2: CONTINUATION.md

```markdown
# Testing Initiative - Resumption Guide

**Project**: hal-9000-testing-comprehensive
**Last Updated**: [Date]
**Status**: [PLANNING/IN_PROGRESS/BLOCKED/COMPLETE]

## Quick Context

This is a comprehensive testing initiative for the hal-9000 CLI command, building a suite of 229 automated tests across 5 phases over 3-4 weeks.

**Quick Status**: [1-2 sentence summary of where we are]

## Current Phase

**Phase**: [1-5] - [Phase Name]
**Days into Phase**: [X/5-9]
**Progress**: [XX% complete]

**What's Done**:
- [Completed item 1]
- [Completed item 2]

**What's In Progress**:
- [Active bead 1]: Description
- [Active bead 2]: Description

**What's Next**:
- [Next action 1]
- [Next action 2]

## Critical Blockers

**If any**: Highest priority issues blocking progress
- [Blocker 1]: [Impact] - [Mitigation]
- [Blocker 2]: [Impact] - [Mitigation]

## Key Beads Status

| Bead | Title | Status | % Complete |
|------|-------|--------|-----------|
| HAL-TEST-001 | Framework setup | [status] | [%] |
| HAL-TEST-002 | Unit tests | [status] | [%] |

## Metrics Snapshot

- **Test Pass Rate**: XX%
- **Tests Passing**: XXX/229
- **Flaky Tests**: X
- **Time Invested**: XX hours
- **Time Remaining (estimated)**: XX hours

## Context Links

- Strategy: `.pm/TESTING-STRATEGY.md`
- Architecture: `.pm/thinking/test-architecture-analysis.md`
- Last Checkpoint: `.pm/checkpoints/phase-X-checkpoint.md`

## Resumption Checklist

When resuming after a break:
- [ ] Read EXECUTION_STATE.md for full status
- [ ] Check latest checkpoint in checkpoints/
- [ ] Review active beads: `bd list --status=in_progress`
- [ ] Check for new blockers in DEPENDENCIES.md
- [ ] Review learnings/ for recent discoveries

## Questions to Ask

If confused about direction:
1. What phase are we in? See EXECUTION_STATE.md
2. What's the current blocker? See DEPENDENCIES.md
3. What test patterns should I follow? See TESTING-STRATEGY.md
4. How do I work with agents? See AGENT_INSTRUCTIONS.md
```

### Template 3: METHODOLOGY.md

```markdown
# Testing Initiative - Engineering Methodology

## Task Execution Discipline

### Before Starting Each Day
1. Read `.pm/checkpoints/` for latest checkpoint
2. Check active beads: `bd list --status=in_progress`
3. Review `.pm/CONTINUATION.md` for context
4. Check `.pm/DEPENDENCIES.md` for blockers

### During Implementation

**Test Development Cycle**:
1. Create bead: `bd create "Test Description" -t feature -p 2`
2. Mark in progress: `bd update [bead-id] --status in_progress`
3. Write test code following patterns in TESTING-STRATEGY.md
4. Run tests locally: `./test/run-tests.sh`
5. Debug failures
6. Commit changes
7. Mark complete: `bd close [bead-id]`

### Code Quality Standards

**All tests must**:
- [ ] Run in isolation (no dependencies on other tests)
- [ ] Clean up after themselves (remove temp files, volumes, containers)
- [ ] Have clear purpose documented in test comment
- [ ] Include specific assertions (not vague)
- [ ] Pass consistently (run 5x locally before committing)
- [ ] Use helper functions from test/lib/helpers.sh
- [ ] Follow naming convention: `test_descriptive_name()`

**Test patterns**:
```bash
# Good test
@test "should reject invalid profile" {
    run hal-9000 /tmp/project --profile=invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid profile"* ]]
}

# Bad test (too vague)
@test "profile test" {
    run hal-9000 /tmp/project
    [ "$status" -eq 0 ]
}
```

### After Completing Each Bead

1. Update checkpoint in `.pm/checkpoints/`
2. Record metrics (test count, pass rate)
3. Document blockers if any
4. Update learnings/ if discovered pattern
5. Commit work with reference to bead

### Weekly Cycle

**Monday**: Review prior week, plan this week's beads
**Wed**: Mid-week checkpoint, check for blockers
**Friday**: Week summary, update EXECUTION_STATE.md

## Documentation Standards

**Every test must document**:
- **Purpose**: What is this test validating?
- **Setup**: What state must exist before test?
- **Action**: What CLI command is being tested?
- **Assertion**: What is the expected outcome?

**Pattern**:
```bash
@test "should create session with valid project" {
    # Purpose: Verify CLI creates tmux session for valid project
    # Setup: Temporary project directory
    mkdir -p /tmp/test-project

    # Action: Run CLI with valid project
    run hal-9000 /tmp/test-project --profile=base

    # Assertion: Session should exist
    [ "$status" -eq 0 ]
    docker exec hal9000-parent tmux list-sessions | grep -q ".*"
}
```

## When to Escalate

**Call for help if**:
- Test fails after 3 debug attempts
- Blocker blocking >2 hours of work
- Architecture question on test design
- Performance baseline unclear

## Context Protocol

See CONTEXT_PROTOCOL.md for how to:
- Ask for agent help
- Hand off work between sessions
- Coordinate with other agents
- Document decisions
```

### Template 4: TESTING-STRATEGY.md

```markdown
# Testing Initiative - Strategy & Organization

## Test Framework

**Framework**: Bats (Bash Automated Testing System)
**Language**: Bash
**Location**: `test/unit/`, `test/integration/`, `test/performance/`

**Why Bats**:
- Tests the Bash script directly (no translation layer)
- Native Docker support
- Clear assertion syntax
- Easy to parallelize

## Test Organization

### Directory Structure
```
test/
├── unit/                          # Unit tests (isolated, no containers)
│   ├── argument-parsing.bats      # CLI argument parsing (45 tests)
│   └── helpers.bats               # Helper function tests
│
├── integration/                   # Integration tests (with containers)
│   ├── container-lifecycle.bats   # Container management (25 tests)
│   ├── volume-management.bats     # Volume operations (20 tests)
│   ├── session-isolation.bats     # Session isolation (18 tests)
│   ├── cross-platform.bats        # Platform-specific (15 tests)
│   └── docker-subsystem.bats      # Docker operations (12 tests)
│
├── error/                         # Error scenario tests
│   ├── error-scenarios.bats       # Error handling (25 tests)
│   ├── edge-cases.bats            # Edge cases (17 tests)
│   └── recovery.bats              # Recovery procedures
│
├── performance/                   # Performance benchmarks
│   ├── startup.bats               # Startup time (10 tests)
│   ├── memory.bats                # Memory usage (8 tests)
│   └── throughput.bats            # Scalability (10 tests)
│
├── lib/
│   └── helpers.sh                 # Shared test utilities
│
└── fixtures/                      # Test data
    ├── projects/                  # Sample project directories
    └── config/                    # Sample configs
```

## Test Patterns

### Pattern 1: Simple CLI Test

```bash
@test "should parse --profile argument" {
    # Arrange: Set up environment
    local profile="python"

    # Act: Run command
    run hal-9000 /tmp/project --profile="$profile"

    # Assert: Check results
    [ "$status" -eq 0 ]
    [[ "$output" == *"Starting hal-9000"* ]]
}
```

### Pattern 2: Container Lifecycle Test

```bash
@test "should start parent container" {
    # Arrange: Ensure container doesn't exist
    docker rm -f hal9000-parent 2>/dev/null || true

    # Act: Start container
    run hal-9000 /tmp/project
    [ "$status" -eq 0 ]

    # Assert: Container running
    docker ps --filter "name=hal9000-parent" --filter "status=running" | grep -q "hal9000-parent"

    # Cleanup
    docker rm -f hal9000-parent
}
```

### Pattern 3: Error Scenario Test

```bash
@test "should fail with nonexistent project" {
    # Act: Run with invalid path
    run hal-9000 /nonexistent/path

    # Assert: Should fail with error message
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]]
}
```

### Pattern 4: Performance Test

```bash
@test "startup time under 3 seconds" {
    # Act: Measure startup
    start_time=$(date +%s%N)
    run hal-9000 /tmp/project
    end_time=$(date +%s%N)

    # Calculate elapsed (nanoseconds to seconds)
    elapsed=$(( (end_time - start_time) / 1000000 ))

    # Assert: Under 3000 ms
    [ "$elapsed" -lt 3000 ]

    # Cleanup
    docker rm -f hal9000-parent
}
```

## Helper Functions

**From `test/lib/helpers.sh`**:

```bash
# Setup/cleanup
setup_test_project()           # Create temp project with files
cleanup_test_project()         # Remove temp project
ensure_docker_running()        # Verify Docker is available
cleanup_containers()           # Remove test containers
cleanup_volumes()              # Remove test volumes

# Assertions
assert_container_running()     # Check container status
assert_volume_exists()         # Verify volume created
assert_session_exists()        # Check tmux session
assert_file_permissions()      # Check file mode (e.g., 600)

# Docker operations
docker_run_wrapper()           # Safe Docker run wrapper
get_container_pid()            # Get container PID
get_container_memory()         # Get memory usage
```

## Test Isolation Requirements

**Each test must**:
1. Not depend on other tests running first
2. Clean up all created resources (containers, volumes, files)
3. Use unique names (avoid collisions)
4. Handle cleanup on failure
5. Not modify host system outside `/tmp/` or Docker volumes

**Cleanup Pattern**:
```bash
@test "example test with cleanup" {
    # Setup
    local test_dir=$(mktemp -d)

    # Test code
    run hal-9000 "$test_dir"

    # Cleanup (ALWAYS run, even on failure)
    rm -rf "$test_dir"
    docker rm -f test-container 2>/dev/null || true
}
```

## CI/CD Integration

**Test execution in CI** runs in stages:

1. **Quick Stage** (5 min): Syntax, build, help
2. **Unit Stage** (3 min): 45 unit tests only
3. **Integration Stage** (15 min): Core integration tests
4. **Full Stage** (45 min nightly): All 229 tests

**Parallelization**: Tests run with `--parallel 4` (4 tests at once)

## Performance Baselines

**To establish baseline**:
```bash
./test/run-tests.sh --performance --baseline
```

Results stored in: `.pm/metrics/test-performance.md`

## Test Stability Requirements

**Before marking test as stable**:
- [ ] Run locally 10x - all pass
- [ ] Run in CI 5x - all pass
- [ ] No dependencies on external services
- [ ] No timing-sensitive assertions
- [ ] Cleanup verified in all paths

## Troubleshooting Tests

| Issue | Solution |
|-------|----------|
| **Test fails in CI, passes locally** | Likely cleanup issue. Add explicit cleanup. |
| **Flaky test (sometimes passes, sometimes fails)** | Timing dependency. Use wait loops. |
| **Test takes >500ms** | Too slow. Break into smaller tests or optimize. |
| **Docker error in test** | Ensure docker socket accessible. Check permissions. |
```

### Template 5: CONTEXT_PROTOCOL.md

```markdown
# Testing Initiative - Context Protocol

This document defines how agents, developers, and sessions handoff context and coordinate work on the testing initiative.

## Session Lifecycle

### SessionStart (When Starting Work)
1. Check if `.pm/` exists
2. Read `.pm/EXECUTION_STATE.md` for current phase
3. Read `.pm/CONTINUATION.md` for recent progress
4. Check `bd list --status=in_progress` for active work
5. Review latest checkpoint in `.pm/checkpoints/`

### During Work (Continuous)
- Update `.pm/checkpoints/` daily with progress
- Commit work with bead reference: `HAL-TEST-NNN: commit message`
- Update `.pm/EXECUTION_STATE.md` with metrics
- Document blockers immediately

### PreCompact (Before Ending Session)
1. Commit all work
2. Create checkpoint: `.pm/checkpoints/phase-X-checkpoint.md`
3. Update `.pm/CONTINUATION.md` with current state
4. Mark beads: active work in `in_progress`, completed work as `completed`
5. Document any blockers or decisions

## Handoff Format Between Agents

### Standard Handoff Template

```
## Handoff: [Receiving Agent Name]

**Task**: [Clear 1-2 sentence description of work]
**Bead**: [HAL-TEST-NNN] (status: [ready/in_progress/blocked])

### Input Artifacts
- **ChromaDB Docs**: [doc IDs or "none"]
- **Memory Bank**: [file path or "none"]
- **GitHub Files**: [specific files to review]
- **Test Fixtures**: [test data locations]

### Deliverable
[Specific, measurable output expected]

Example: "40 passing unit tests in test/unit/argument-parsing.bats"

### Quality Criteria
- [ ] [Criterion 1 - specific and testable]
- [ ] [Criterion 2 - with measurement]
- [ ] [Criterion 3 - acceptance gate]

### Context Notes
[Any special considerations, known challenges, gotchas]

### Critical Dependencies
- **Must be complete first**: [other beads]
- **Is blocked by**: [active beads]
- **Blocks these**: [downstream beads]
```

### Example: Handing Off to Test Implementation

```
## Handoff: Implementation Agent

**Task**: Implement 45 unit tests for CLI argument parsing in bats framework

**Bead**: HAL-TEST-002 (status: ready)

### Input Artifacts
- ChromaDB: none (new project)
- Memory Bank: `hal-9000-testing_active/test-framework-setup.md`
- Files:
  - `hal-9000` (script to test)
  - `test/lib/helpers.sh` (helpers from HAL-TEST-003)
  - `.pm/TESTING-STRATEGY.md` (test patterns)

### Deliverable
All 45 unit tests in `test/unit/argument-parsing.bats` passing:
- 15 argument parsing tests
- 15 validation tests
- 15 formatting/output tests

### Quality Criteria
- [ ] 45/45 tests passing (100% pass rate)
- [ ] Each test runs in <50ms
- [ ] No test dependencies
- [ ] Clear comments explaining test purpose
- [ ] Follows patterns in TESTING-STRATEGY.md
- [ ] No test failures in 5 consecutive runs

### Context Notes
- Framework from HAL-TEST-001 must be complete first
- Use helper functions from test/lib/helpers.sh
- Don't import from other test categories (isolation)
- See TESTING-STRATEGY.md "Pattern 1: Simple CLI Test" for structure

### Critical Dependencies
- Must be complete: HAL-TEST-001 (framework setup)
- Must be complete: HAL-TEST-003 (helper functions)
- Blocks: HAL-TEST-005+ (integration tests need working unit tests)
```

## Bead Status Tracking

### Status Values

| Status | Meaning | Who Updates |
|--------|---------|------------|
| `ready` | Unblocked, ready to start | Planning agent |
| `in_progress` | Currently being worked | Implementation agent |
| `blocked` | Cannot proceed, reason documented | Discovery |
| `completed` | Done and accepted | Code review / Quality gate |

### Bead Update Pattern

```bash
# Create new bead
bd create "Implement 45 unit tests" -t feature -p 2

# Mark as in progress
bd update HAL-TEST-002 --status in_progress

# On completion
bd close HAL-TEST-002

# Add dependency
bd dep add HAL-TEST-005 HAL-TEST-001  # Test-005 depends on Test-001
```

## Knowledge Persistence

### ChromaDB Entries (Long-term Storage)

Create ChromaDB entries for discoveries that should persist across projects:

**Entry Type**: `testing::pattern::{pattern-name}`

Examples:
- `testing::pattern::test-isolation-with-docker`
- `testing::pattern::flaky-test-detection`
- `testing::lesson::cross-platform-volume-mounting`

### Memory Bank Entries (Session Storage)

Use Memory Bank for active session knowledge:

**Project**: `hal-9000-testing_active`

Files:
- `test-framework-setup.md` - Framework decisions
- `test-patterns.md` - Discovered patterns
- `blockers.md` - Current blockers
- `metrics-snapshot.md` - Latest metrics

## Communication Protocols

### Within Session

- **Status Updates**: Update `.pm/checkpoints/` daily
- **Blocker Reports**: Document in `.pm/DEPENDENCIES.md` immediately
- **Metrics**: Update `.pm/metrics/` after each phase

### Between Sessions

- **Context Handoff**: Write comprehensive `.pm/CONTINUATION.md`
- **Recent Learnings**: Update `.pm/learnings/` at session end
- **Decisions Made**: Document in `.pm/hypotheses/`

### With Agents

- **Assignment**: Use Handoff format above
- **Status Requests**: Query `bd list` for active work
- **Quality Gates**: Run checkpoint validation before phase completion

## Architecture Decision Recording

When making test architecture decisions:

1. Document in `.pm/hypotheses/test-{decision-name}.md`
2. Include: rationale, alternatives considered, validation approach
3. Link from related bead
4. Update `.pm/thinking/` if major decision

Example:
```markdown
# Hypothesis: Use Docker volumes for test data isolation

**Status**: VALIDATED ✓

**Rationale**: Volumes provide strong isolation, survive container restarts

**Alternatives Considered**:
- Mount host /tmp: Less isolation, flakiness risk
- In-container storage: No persistence between tests

**Validation**: HAL-TEST-007 (session isolation tests)

**Result**: VALIDATED - volumes provide required isolation
```

## Escalation Path

If blocked for >2 hours:

1. Document blocker in `.pm/DEPENDENCIES.md`
2. Create "blocked" bead with issue details
3. Request help from plan-auditor
4. Escalate architectural issues to strategic-planner

## Questions?

- **"Where are we in the project?"** → Read `.pm/EXECUTION_STATE.md`
- **"What should I work on?"** → Check `bd list --status=ready`
- **"How do I write a test?"** → See `.pm/TESTING-STRATEGY.md`
- **"What's blocking progress?"** → See `.pm/DEPENDENCIES.md`
- **"How do I hand off?"** → Use format above, include all required fields
```

---

## 12. Implementation Checklist

### Before Creating .pm/ Files

- [ ] Archive previous project (if any): `.pm-archive/previous/`
- [ ] Create fresh `.pm/` directory: `mkdir -p .pm/`
- [ ] Create subdirectories: `checkpoints/, learnings/, hypotheses/, audits/, thinking/, metrics/`

### Create Core Files (In This Order)

1. [ ] `.pm/EXECUTION_STATE.md` (Template 1)
2. [ ] `.pm/CONTINUATION.md` (Template 2)
3. [ ] `.pm/METHODOLOGY.md` (Template 3)
4. [ ] `.pm/TESTING-STRATEGY.md` (Template 4)
5. [ ] `.pm/CONTEXT_PROTOCOL.md` (Template 5)

### Additional Infrastructure Files

6. [ ] `.pm/DEPENDENCIES.md` - Critical path and blockers (see Section 12.2)
7. [ ] `.pm/RESOURCES.md` - Tools and infrastructure (see Section 12.3)
8. [ ] `.pm/AGENT_INSTRUCTIONS.md` - Updated for testing domain
9. [ ] `.pm/checkpoints/TEMPLATE-checkpoint.md` - Daily tracking template

### Initialize Supporting Files

10. [ ] `.pm/learnings/TEMPLATE-learning.md`
11. [ ] `.pm/hypotheses/TEMPLATE-hypothesis.md`
12. [ ] `.pm/audits/TEMPLATE-audit.md`
13. [ ] `.pm/metrics/test-performance.md` (empty, fill as tests run)
14. [ ] `.pm/metrics/pass-rate-tracking.md` (empty, fill as tests run)

---

## 13. Additional Template Files

### Template 6: DEPENDENCIES.md

```markdown
# Testing Initiative - Dependencies & Critical Path

## Critical Path (Minimum for Release)

Must complete in this order:

1. **HAL-TEST-001**: Test framework setup (3 days)
   - Deliverable: bats framework configured, CI/CD pipeline stub
   - Blocks: All other test beads
   - Risk: Medium (new framework unfamiliar)

2. **HAL-TEST-002**: 45 unit tests (3 days)
   - Depends on: HAL-TEST-001, HAL-TEST-003
   - Blocks: HAL-TEST-005+
   - Risk: Medium (many tests to maintain)

3. **HAL-TEST-005, 006**: Core integration tests (4 days)
   - Depends on: HAL-TEST-002
   - Blocks: HAL-TEST-013 (CI integration)
   - Risk: High (Docker complexity)

4. **HAL-TEST-013**: CI/CD pipeline (2 days)
   - Depends on: HAL-TEST-005, 006
   - Blocks: Release
   - Risk: Medium (GitHub Actions config)

**Critical Path Total**: ~12 days

**If Running Behind**:
- Defer HAL-TEST-012 (performance tests)
- Defer Phase 5 documentation
- Focus on: Core integration tests (HAL-TEST-005, 006)

## Blocker Log

### Currently Active Blockers
None at startup.

### Resolved Blockers
(None yet)

### Future Risks
- Docker integration complexity
- Test flakiness in CI
- Cross-platform issues

## Dependency Graph

```
Phase 1:
  HAL-TEST-001 ─── HAL-TEST-003
         │               │
         └───────┬───────┘
                 │
              HAL-TEST-002

Phase 2:
   HAL-TEST-002
         │
    ┌────┼────┬────┐
    │    │    │    │
  HAL-TEST-005 006 007 008
         │
    HAL-TEST-013

Phase 3:
   HAL-TEST-009, 010

Phase 4:
   HAL-TEST-012, 014

Phase 5:
   HAL-TEST-016-019
```

## External Dependencies

- Docker daemon available
- GitHub Actions access
- Network for pulling images
- Bash 5.0+ on CI runner
```

### Template 7: RESOURCES.md

```markdown
# Testing Initiative - Resources & Infrastructure

## Tools Required

- **Bats framework** (installed in CI, local via brew/apt)
- **Docker** (20.10+, already available)
- **tmux** (3.0+, used by hal-9000 CLI)
- **Bash** (5.0+, validation in unit tests)
- **jq** (for JSON parsing in tests)

## Infrastructure

### Local Development
- 5 GB disk space for test containers/volumes
- 4 GB RAM available during test runs
- Docker socket accessible
- `/tmp` writable for test files

### CI/CD (GitHub Actions)
- Ubuntu 22.04 runner
- Docker enabled (`ubuntu-latest` has this)
- GitHub Actions secrets for API keys (if needed)
- ~30 min total workflow time

### Test Data
- Sample projects in `test/fixtures/projects/`
- Sample configs in `test/fixtures/config/`
- No real credentials needed (use dummy values)

## Access & Credentials

### None Required For Tests
- All tests use mock/dummy data
- No real Docker Hub/registry credentials needed
- No API keys embedded in test code
- No database credentials

### CI/CD Credentials
- `ANTHROPIC_API_KEY`: If testing real Claude integration
  - Store as GitHub secret: Settings → Secrets and variables → Actions
  - Only needed for optional integration tests

## Artifact Storage

### GitHub Actions
- Test results: `/tmp/test-results.log` (uploaded as artifact)
- Performance metrics: `.pm/metrics/` (committed to repo)
- Flaky test report: `.pm/metrics/flaky-tests.md` (if found)

### ChromaDB (Long-term)
- Test patterns discovered
- Performance baselines
- Cross-platform findings

### Memory Bank (Session)
- Active test development
- Blocker details
- Phase coordination
```

---

## 14. Ready to Start

This infrastructure specification is **complete and ready to implement**.

### Next Steps for Project Manager:

1. **Archive Previous Project** (if needed):
   ```bash
   mkdir -p /Users/hal.hildebrand/git/hal-9000/.pm-archive/testing-setup-plan-$(date +%Y%m%d)
   ```

2. **Create Fresh .pm/ Structure**:
   ```bash
   cd /Users/hal.hildebrand/git/hal-9000
   mkdir -p .pm/{checkpoints,learnings,hypotheses,audits,thinking,metrics}
   ```

3. **Use Templates Above to Create Core Files** (see Section 2.2)

4. **Create Initial Beads**:
   ```bash
   bd create "Set up bats test framework" -t feature -p 1 -d "HAL-TEST-001"
   bd create "Implement 45 unit tests for CLI" -t feature -p 2 -d "HAL-TEST-002"
   ```

5. **Archive This Document** to `.pm/TESTING-INITIATIVE-INFRASTRUCTURE.md` (reference)

### Success Criteria for Infrastructure

- [ ] All files in `.pm/` created and valid JSON/Markdown
- [ ] EXECUTION_STATE.md shows Phase 1 READY
- [ ] CONTINUATION.md provides clear resumption path
- [ ] All beads created with proper dependencies
- [ ] First three beads (001, 002, 003) marked as "ready"

---

**Document Status**: COMPLETE - Ready for .pm/ creation
**Created**: 2026-01-27
**For Project**: hal-9000-testing-comprehensive
