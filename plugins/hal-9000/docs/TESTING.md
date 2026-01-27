# hal-9000 Phase 1 - Testing Plan

**Status**: Not yet fully executed
**Priority**: High (blocks Phase 1 completion)

## Testing Summary

### Completed ✅
- [x] Syntax validation (bash -n)
- [x] Profile detection (4/4 unit tests)
- [x] Session naming (collision detection)
- [x] Help system (--help output)
- [x] Gitignore configuration

### Pending ⏳
- [ ] Installation script execution
- [ ] Container launch
- [ ] Session directory creation
- [ ] File permission verification
- [ ] Authentication token copying
- [ ] Cross-platform execution
- [ ] End-to-end workflow

## Unit Tests (Complete)

### Profile Detection Tests ✅

**Test 1: Java Project**
```bash
mkdir -p /tmp/test-java
touch /tmp/test-java/pom.xml
# Result: PASS (detects "java")
```

**Test 2: Python Project**
```bash
mkdir -p /tmp/test-python
touch /tmp/test-python/pyproject.toml
# Result: PASS (detects "python")
```

**Test 3: Node Project**
```bash
mkdir -p /tmp/test-node
touch /tmp/test-node/package.json
# Result: PASS (detects "node")
```

**Test 4: Base Project**
```bash
mkdir -p /tmp/test-base
# Result: PASS (detects "base")
```

### Session Naming Tests ✅

**Test 1: Deterministic Naming**
```bash
# Same project path = same session name
NAME1=$(./hal-9000 --name test-project /tmp/test-project 2>&1 | grep "session:")
NAME2=$(./hal-9000 --name test-project /tmp/test-project 2>&1 | grep "session:")
# Result: PASS (names match)
```

**Test 2: Hash Collision**
```bash
# Different paths = different session names
./hal-9000 /tmp/project1
./hal-9000 /tmp/project2
# Result: PASS (different names)
```

## Integration Tests (Pending)

### Test: Installation Script ⏳

**Prerequisites**:
- bash 5.0+
- Sudo access (or /usr/local/bin writable)
- Docker installed

**Steps**:
1. Run: `./install-hal-9000.sh`
2. Verify: `which hal-9000` returns `/usr/local/bin/hal-9000`
3. Verify: `hal-9000 --version` works
4. Verify: `hal-9000 --verify` succeeds
5. Run: `./install-hal-9000.sh verify`
6. Run: `./install-hal-9000.sh uninstall`
7. Verify: `which hal-9000` fails

**Expected**: All steps succeed, no errors

### Test: Session Directory Creation ⏳

**Prerequisites**:
- ~/.hal9000 directory writable

**Steps**:
1. Run: `./hal-9000 --verify /tmp/test-project`
2. Check: `ls -la ~/.hal9000/claude/`
3. Check: `ls -la ~/.hal9000/claude/hal-9000-test-project-*/`
4. Verify structure:

   ```mermaid
   graph LR
       subgraph session["~/.hal9000/claude/hal-9000-test-project-HASH/"]
           claude[".claude/"]
           sessionjson[".session.json"]
           workspace[".workspace/"]
       end
   ```

**Expected**: Directory structure created with correct permissions

### Test: Authentication Token Copying ⏳

**Prerequisites**:
- ~/.claude/.session.json exists (Claude authenticated)

**Steps**:
1. Save original token: `cp ~/.claude/.session.json /tmp/token-backup.json`
2. Run: `./hal-9000 --verify /tmp/test-project`
3. Check: `ls ~/.hal9000/claude/hal-9000-test-project-*/`
4. Verify: `.session.json` was copied
5. Verify: `chmod 600` was applied

**Expected**: Token copied with correct permissions (600)

### Test: File Permissions ⏳

**Prerequisites**:
- Installation complete
- Session directory created

**Steps**:
```bash
ls -la ~/.hal9000/claude/hal-9000-*/
ls -la ~/.hal9000/claude/hal-9000-*/.session.json
```

**Expected**:
- `.session.json` has perms: `-rw-------` (600)
- `.claude/` has perms: `drwx------` (700)

## Cross-Platform Tests (Pending)

### macOS (Tested Syntax Only)

**Environment**:
- macOS 10.15+
- bash 5.1+
- Docker Desktop running

**Test Steps**:
1. `cd ~/project`
2. `./hal-9000 --verify`
3. `./hal-9000 --diagnose`
4. Check: All prerequisites verified

**Expected**: All checks pass

### Linux Ubuntu (Not Tested)

**Environment**:
- Ubuntu 22.04 LTS
- bash 5.1+
- Docker installed and running

**Test Steps**:
1. Same as macOS
2. Verify: Session directory permissions correct on Linux

**Expected**: All checks pass, session created

### Linux Debian (Not Tested)

**Environment**:
- Debian 11+
- bash 4.4+
- Docker installed

**Test Steps**:
1. Same as macOS

**Expected**: All checks pass

### WSL2 Windows (Not Tested)

**Environment**:
- Windows 11 Build 22000+
- WSL2 Ubuntu 22.04
- Docker Desktop with WSL2 integration

**Test Steps**:
1. Same as macOS
2. Special: Verify path handling with Windows mounts

**Expected**: All checks pass

## End-to-End Workflow Test (Pending)

**Test: Complete User Flow**

**Prerequisites**:
- Install hal-9000
- Project directory with pom.xml (Java)
- Docker with hal-9000:java image available or fallback to base

**Steps**:
1. Create test project:
   ```bash
   mkdir ~/test-hal-9000-e2e
   cd ~/test-hal-9000-e2e
   touch pom.xml
   ```

2. Run hal-9000:
   ```bash
   hal-9000
   ```

3. Verify:
   - [ ] Profile detected as "java"
   - [ ] Session created in ~/.hal9000/
   - [ ] tmux session opened
   - [ ] Claude accessible in session
   - [ ] Project mounted at /workspace
   - [ ] Authentication token available

4. Test session reattach:
   ```bash
   tmux list-sessions
   tmux attach -t hal-9000-*
   ```

5. Clean up:
   ```bash
   hal-9000 --cleanup
   ```

**Expected**: All steps succeed, user can interact with Claude

## Error Scenario Tests (Pending)

### Test: Missing Docker

**Steps**:
1. Rename docker binary (simulate missing)
2. Run: `./hal-9000 --verify`

**Expected**: Clear error message, suggests installation

### Test: Missing Claude Session

**Steps**:
1. Rename ~/.claude/.session.json
2. Run: `./hal-9000`

**Expected**: Warning but continues, suggests /login

### Test: Docker Daemon Not Running

**Steps**:
1. Stop Docker daemon
2. Run: `./hal-9000`

**Expected**: Clear error message, suggests starting Docker

### Test: Invalid Project Directory

**Steps**:
1. Run: `./hal-9000 /nonexistent/path`

**Expected**: Error: "Directory not found"

### Test: Permission Denied

**Steps**:
1. Create read-only directory
2. Run: `./hal-9000 --name test /readonly`

**Expected**: Error with recovery suggestion

## Test Execution Checklist

### Before Phase 1 Completion

- [ ] Installation test (local)
- [ ] Session creation test
- [ ] File permission test
- [ ] macOS cross-platform test
- [ ] Error handling tests (3 critical scenarios)

### Before Phase 2 Start

- [ ] Linux Ubuntu test
- [ ] Linux Debian test
- [ ] WSL2 test
- [ ] End-to-end workflow test
- [ ] Container launch test (if images available)

## Known Issues / Blockers

1. **Container Images**: Can't test container launch without hal-9000:* images built
2. **Docker**: Testing requires Docker daemon running
3. **Cross-platform**: Limited to macOS currently, Linux/WSL2 untested

## Next Steps

1. **Immediate**: Run installation and session creation tests locally
2. **Follow-up**: Execute error scenario tests
3. **Before Phase 2**: Complete cross-platform testing matrix

---

**Ticket**: ART-880-TESTING
**Related**: .pm/BEADS.md (HAL9000-IMPL-2-4)
**Updated**: 2026-01-25
