# Volume Isolation Strategy for hal-9000 Testing

**Version**: 1.0
**Date**: 2026-01-27
**Status**: Implemented and Tested

---

## Overview

The hal-9000 test suite uses **Docker volume isolation** to ensure test independence and enable parallel test execution. Each test gets its own set of dedicated Docker volumes, preventing test state from bleeding into other tests.

## Problem Statement

Without volume isolation:
- All tests share the same Docker volumes (`hal9000-claude-home`, `hal9000-claude-session`, `hal9000-memory-bank`)
- Test A's state corrupts Test B's execution
- Tests cannot run in parallel without flaky failures
- Test order matters (improper dependency)
- Cleanup is difficult and unreliable

## Solution

### Volume Naming Convention

Each test gets three isolated volumes using a consistent naming pattern:

```
hal9000-test-{TEST_ID}-claude-home       # CLAUDE_HOME equivalent
hal9000-test-{TEST_ID}-claude-session    # Claude session state (.claude.json)
hal9000-test-{TEST_ID}-memory-bank       # Cross-session memory bank
```

**Examples:**
```
hal9000-test-AUTH-001-claude-home
hal9000-test-AUTH-001-claude-session
hal9000-test-AUTH-001-memory-bank

hal9000-test-INFO-005-claude-home
hal9000-test-INFO-005-claude-session
hal9000-test-INFO-005-memory-bank
```

### Volume Lifecycle

1. **Pre-Test**: Create three volumes for the test ID
2. **Test Execution**: Container runs with test-specific volumes mounted
3. **Post-Test**: Remove all test volumes (automatic cleanup)
4. **Next Test**: Fresh volumes created with same TEST_ID if re-run

### Key Benefits

✅ **Test Independence**: Each test has isolated state
✅ **Parallel Execution**: Multiple tests run simultaneously without interference
✅ **Deterministic**: Test results don't depend on execution order
✅ **Clean Feedback**: Failed tests don't leave artifacts affecting other tests
✅ **Easy Debugging**: Failed test volumes can be kept for manual inspection

---

## Implementation

### Files

1. **`/scripts/tests/lib/volume-helpers.sh`** (335 lines)
   - Core volume management functions
   - Validation and lifecycle hooks
   - Utility functions for inspection/cleanup

2. **`/scripts/tests/run-all-tests.sh`** (250 lines)
   - Test orchestrator
   - Parallel execution support
   - Results reporting

3. **`/scripts/tests/example-test.sh`** (100 lines)
   - Example test implementation
   - Demonstrates volume isolation pattern
   - Template for writing new tests

### Core Functions

#### Volume Naming
```bash
get_test_volume_name TEST_ID VOLUME_TYPE
# Returns: hal9000-test-{TEST_ID}-{VOLUME_TYPE}

get_test_volumes TEST_ID
# Returns: Space-separated list of all three volumes
```

#### Lifecycle Hooks
```bash
setup_test_environment TEST_ID
# Creates volumes, validates Docker, prepares test

teardown_test_environment TEST_ID [TEST_RESULT]
# Removes volumes, records result, cleans up
```

#### Volume Management
```bash
setup_test_volumes TEST_ID
# Creates three volumes for test

cleanup_test_volumes TEST_ID [FORCE]
# Removes three volumes for test

test_volumes_exist TEST_ID
# Returns 0 if all volumes exist, 1 otherwise

list_test_volumes TEST_ID
# Displays test volumes with sizes
```

---

## Usage Pattern

### Writing a Test Script

```bash
#!/bin/bash
set -Eeuo pipefail

# Get test ID from argument
TEST_ID="${1:-TEST-001}"

# Source volume helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/volume-helpers.sh"

# Test implementation
run_test() {
    # Your test code here
    # Use setup_test_environment before test
    # Use teardown_test_environment after test
    echo "Running test: $TEST_ID"
}

# Main
main() {
    # Setup volumes and environment
    if ! setup_test_environment "$TEST_ID"; then
        exit 1
    fi

    # Run test
    local result="fail"
    if run_test; then
        result="pass"
    fi

    # Cleanup volumes
    teardown_test_environment "$TEST_ID" "$result"

    [[ "$result" == "pass" ]] && exit 0 || exit 1
}

main "$@"
```

### Running a Test

```bash
# Single test with isolation
bash scripts/tests/example-test.sh AUTH-001

# With cleanup
bash scripts/tests/run-all-tests.sh --cleanup-all

# Parallel execution (4 at a time)
bash scripts/tests/run-all-tests.sh --parallel 4

# Specific category
bash scripts/tests/run-all-tests.sh --category AUTH -v
```

---

## Docker Volume Mounting

When launching containers in tests, mount the test-specific volumes:

```bash
# Manual Docker run with test volumes
docker run \
  -v hal9000-test-AUTH-001-claude-home:/root/.claude \
  -v hal9000-test-AUTH-001-claude-session:/root/.claude-session \
  -v hal9000-test-AUTH-001-memory-bank:/root/memory-bank \
  ghcr.io/hellblazer/hal-9000:base
```

Or use the helper function:

```bash
# Helper function (automatically mounts test volumes)
run_with_test_volumes TEST_ID IMAGE_NAME [DOCKER_ARGS...]
```

---

## Parallel Execution

Tests can run in parallel because each has isolated volumes:

```bash
# Sequential (default)
./scripts/tests/run-all-tests.sh

# Parallel: 4 tests at a time
./scripts/tests/run-all-tests.sh --parallel 4

# Parallel: all available CPUs
./scripts/tests/run-all-tests.sh --parallel $(nproc)
```

**Important**: Test execution is deterministic regardless of order, since there are no shared resources.

---

## Cleanup Strategies

### Automatic Cleanup (Recommended)
```bash
# Cleanup happens automatically after each test
teardown_test_environment TEST_ID "pass"
```

### Debug Mode (Keep Failed Test Volumes)
```bash
./scripts/tests/run-all-tests.sh --cleanup-failed

# Inspect failed test volumes manually
docker volume ls | grep hal9000-test-AUTH-001
```

### Manual Cleanup
```bash
# Single test volumes
cleanup_test_volumes AUTH-001

# All test volumes
cleanup_all_test_volumes "hal9000-test-*"
```

### Emergency Cleanup
```bash
# Force remove (even if in use)
force_cleanup_test_volumes AUTH-001
```

---

## Monitoring and Debugging

### List All Test Volumes
```bash
list_all_test_volumes
# Shows all active test volumes and their status
```

### Inspect Single Test
```bash
list_test_volumes AUTH-001
# Shows volumes, mountpoints, sizes for AUTH-001
```

### Get Volume Size
```bash
get_test_volume_size AUTH-001 claude-home
# Returns size of claude-home volume for AUTH-001
```

### Verify Volumes Exist
```bash
test_volumes_exist AUTH-001
# Returns 0 if all volumes exist, 1 if missing
```

---

## Architecture Diagram

```
Test Execution Flow with Volume Isolation
═════════════════════════════════════════

START TEST
    ↓
setup_test_environment(AUTH-001)
    ├─ Validate Docker support
    ├─ Create: hal9000-test-AUTH-001-claude-home
    ├─ Create: hal9000-test-AUTH-001-claude-session
    └─ Create: hal9000-test-AUTH-001-memory-bank
    ↓
RUN TEST with isolated volumes
    ├─ Mount: /root/.claude → hal9000-test-AUTH-001-claude-home
    ├─ Mount: /root/.claude-session → hal9000-test-AUTH-001-claude-session
    └─ Mount: /root/memory-bank → hal9000-test-AUTH-001-memory-bank
    ↓
TEST COMPLETES (PASS/FAIL)
    ↓
teardown_test_environment(AUTH-001, result)
    ├─ Remove: hal9000-test-AUTH-001-claude-home
    ├─ Remove: hal9000-test-AUTH-001-claude-session
    └─ Remove: hal9000-test-AUTH-001-memory-bank
    ↓
NEXT TEST (independent, no state bleed)
```

---

## Parallel Execution Example

```
With Volume Isolation
═════════════════════

Thread 1: AUTH-001 volumes
├─ hal9000-test-AUTH-001-claude-home
├─ hal9000-test-AUTH-001-claude-session
└─ hal9000-test-AUTH-001-memory-bank
    ↓ Running AUTH-001

Thread 2: AUTH-002 volumes
├─ hal9000-test-AUTH-002-claude-home
├─ hal9000-test-AUTH-002-claude-session
└─ hal9000-test-AUTH-002-memory-bank
    ↓ Running AUTH-002 (no interference!)

Thread 3: PROF-001 volumes
├─ hal9000-test-PROF-001-claude-home
├─ hal9000-test-PROF-001-claude-session
└─ hal9000-test-PROF-001-memory-bank
    ↓ Running PROF-001 (completely isolated!)

All tests complete independently ✓
```

---

## Performance Impact

### Volume Creation Overhead
- Per-volume creation: ~50-100ms
- Three volumes per test: ~150-300ms
- Negligible compared to test execution time

### Storage Requirements
- Empty volumes: ~1-10MB each
- Three per test: ~3-30MB per test
- Automatic cleanup between tests
- No disk accumulation

### Execution Time
- Sequential 227 tests: 1-2 hours (estimated)
- Parallel (4 tests): ~30-40 minutes
- Parallel (8 tests): ~15-20 minutes

---

## Error Handling

### Volume Already Exists
- Automatically skipped (idempotent)
- No error if volume exists
- Safe for re-runs

### Volume Creation Failure
- Returns error, test fails immediately
- Prevents running test with shared volumes
- Safer than silently using wrong volumes

### Cleanup Failure
- Logged as warning
- Test still marked as passed/failed
- Prevents cascading failures
- Volumes removed next cleanup cycle

---

## Future Enhancements

1. **Volume Snapshots**: Save volume state between test runs
2. **Volume Metrics**: Track size, access patterns per test
3. **Failure Replay**: Re-run failed test with saved volumes
4. **Performance Profiling**: Measure test execution with isolated volumes
5. **Test Dependency Graph**: Optimize parallel execution based on dependencies

---

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run hal-9000 tests in parallel
  run: |
    ./scripts/tests/run-all-tests.sh \
      --parallel $(nproc) \
      --cleanup-all \
      -v
```

### Exit Codes
- `0`: All tests passed
- `1`: One or more tests failed
- Useful for CI/CD pipeline gates

---

## Troubleshooting

### Issue: Docker volumes not being created
**Solution**: Ensure Docker daemon is running and accessible
```bash
docker ps
# Should show running containers
```

### Issue: Volumes not cleaning up
**Solution**: Check for stuck containers
```bash
docker ps | grep hal9000-test-
# Kill stuck containers manually if needed
```

### Issue: Parallel tests interfering
**Solution**: This shouldn't happen - check volume names
```bash
docker volume ls | grep hal9000-test-
# Verify each test has unique volumes
```

### Issue: Running out of disk space
**Solution**: Force cleanup of all test volumes
```bash
./scripts/tests/lib/volume-helpers.sh
cleanup_all_test_volumes
```

---

## Testing the Framework

```bash
# Run example test to verify framework
bash scripts/tests/example-test.sh TEST-VERIFY-001

# Expected output:
# ✓ Test environment prepared
# ✓ Test volumes created
# ✓ Test executed
# ✓ Volumes cleaned up
```

---

## References

- `/scripts/tests/lib/volume-helpers.sh` - Core implementation
- `/scripts/tests/run-all-tests.sh` - Test orchestrator
- `/scripts/tests/example-test.sh` - Example usage
- `/tests/HAL9000_TEST_PLAN.md` - Test specifications
- Docker Volume Documentation: https://docs.docker.com/storage/volumes/
