# HAL-9000 Testing Guide

Comprehensive guide for running, understanding, and extending the HAL-9000 test suite.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Running Tests Locally](#running-tests-locally)
- [Test Categories](#test-categories)
- [CI/CD Integration](#cicd-integration)
- [Interpreting Results](#interpreting-results)
- [Troubleshooting](#troubleshooting)
- [Adding New Tests](#adding-new-tests)
- [Best Practices](#best-practices)

## Overview

The HAL-9000 test suite provides comprehensive validation of:
- Installation and setup procedures
- Docker integration and containerization
- Profile detection and configuration
- Session management and state persistence
- Error handling and edge cases
- Security features (seccomp profiles)
- Version consistency
- Marketplace integration

**Current Coverage:**
- **58 automated tests** - Run in < 5 minutes
- **136 manual tests** - Documented procedures for Docker/integration scenarios
- **1 regression framework** - Grows as bugs are discovered

## Quick Start

```bash
# Run all automated tests
make test-suite

# Run specific category
make test-category-01

# Run with verbose output
make test-suite-verbose

# Run master test runner directly
./tests/run-all-tests.sh

# Run single category directly
./tests/test-category-07-docker-integration.sh
```

## Prerequisites

### Required

- **Bash 5.0+**: Test scripts require modern bash features
- **Git**: For repository operations
- **hal-9000**: Installed in repository root

### Optional (for full coverage)

- **Docker**: Required for Docker-specific tests (Categories 7, 8, 12)
- **jq**: JSON validation and parsing (Category 11)
- **tmux**: Session attachment tests (Category 4)

### Checking Prerequisites

```bash
# Check bash version
bash --version  # Should be 5.0 or higher

# Check Docker
docker --version
docker ps  # Should connect to daemon

# Check jq
jq --version

# Check tmux
tmux -V
```

## Running Tests Locally

### Master Test Runner

The master test runner (`tests/run-all-tests.sh`) orchestrates all test categories:

```bash
# Basic usage
./tests/run-all-tests.sh

# Verbose mode (shows detailed output)
./tests/run-all-tests.sh --verbose

# Run specific category
./tests/run-all-tests.sh --category=07

# Stop on first failure
./tests/run-all-tests.sh --stop-on-fail

# Help
./tests/run-all-tests.sh --help
```

### Makefile Targets

Convenient shortcuts via Makefile:

```bash
# Run all tests
make test-suite                # Quiet mode
make test-suite-verbose        # Verbose mode

# Individual categories
make test-category-01          # Help & Version Commands
make test-category-02          # Setup & Authentication
make test-category-03          # Profile Detection
make test-category-04          # Session Management
make test-category-05          # Command-Line Arguments
make test-category-06          # Environment Variables
make test-category-07          # Docker Integration
make test-category-08          # Daemon & Pool Management
make test-category-09          # Claude Passthrough
make test-category-10          # Error Handling
make test-category-11          # Installation & Distribution
make test-category-12          # Configuration & State Files
make test-category-14          # Regression Test Suite
```

### Individual Test Scripts

Run test categories directly:

```bash
# Make executable (if needed)
chmod +x tests/test-category-*.sh

# Run category
./tests/test-category-01-help-version.sh
./tests/test-category-07-docker-integration.sh
```

## Test Categories

### Category 1: Help & Version Commands
- **Tests**: 11 automated
- **Coverage**: `--help`, `--version`, `help` subcommand
- **Runtime**: < 5 seconds
- **Prerequisites**: None

```bash
make test-category-01
```

### Category 2: Setup & Authentication
- **Tests**: 6 automated, 10 manual
- **Coverage**: API key validation, setup flow, exit codes
- **Runtime**: < 10 seconds (automated)
- **Prerequisites**: None

```bash
make test-category-02
```

### Category 3: Profile Detection
- **Tests**: 20 automated
- **Coverage**: Java (Maven/Gradle), Python (pip/poetry), Node.js, Base
- **Runtime**: < 30 seconds
- **Prerequisites**: None

```bash
make test-category-03
```

### Category 4: Session Management
- **Tests**: 7 automated, 20 manual
- **Coverage**: Session creation, listing, attach, kill
- **Runtime**: < 15 seconds (automated)
- **Prerequisites**: tmux (for manual tests)

```bash
make test-category-04
```

### Category 5: Command-Line Arguments
- **Tests**: 9 automated, 11 manual
- **Coverage**: Directory paths, flags, options, invalid input
- **Runtime**: < 20 seconds (automated)
- **Prerequisites**: None

```bash
make test-category-05
```

### Category 6: Environment Variables
- **Tests**: 8 automated, 5 manual
- **Coverage**: Variable handling, CLI > ENV > Default precedence
- **Runtime**: < 15 seconds (automated)
- **Prerequisites**: None

```bash
make test-category-06
```

### Category 7: Docker Integration
- **Tests**: 3 automated, 23 manual
- **Coverage**: Container lifecycle, volumes, DinD, image handling
- **Runtime**: < 10 seconds (automated)
- **Prerequisites**: Docker (running)

```bash
make test-category-07
```

### Category 8: Daemon & Pool Management
- **Tests**: 21 manual/orchestrator
- **Coverage**: Daemon lifecycle, ChromaDB, worker pool scaling
- **Runtime**: N/A (requires orchestrator implementation)
- **Prerequisites**: Future orchestrator feature

```bash
make test-category-08
```

### Category 9: Claude Passthrough
- **Tests**: 15 manual
- **Coverage**: Plugins, MCP servers, system commands, slash commands
- **Runtime**: N/A (requires running sessions)
- **Prerequisites**: Docker, running sessions

```bash
make test-category-09
```

### Category 10: Error Handling & Edge Cases
- **Tests**: 8 automated, 12 manual
- **Coverage**: Missing prerequisites, invalid input, failure modes
- **Runtime**: < 20 seconds (automated)
- **Prerequisites**: None

```bash
make test-category-10
```

### Category 11: Installation & Distribution
- **Tests**: 8 automated, 4 manual
- **Coverage**: Install scripts, version consistency, marketplace
- **Runtime**: < 10 seconds (automated)
- **Prerequisites**: jq

```bash
make test-category-11
```

### Category 12: Configuration & State Files
- **Tests**: 2 automated, 15 manual
- **Coverage**: File structure, metadata, Docker labels
- **Runtime**: < 5 seconds (automated)
- **Prerequisites**: None

```bash
make test-category-12
```

### Category 14: Regression Test Suite
- **Tests**: Template framework (grows as bugs discovered)
- **Coverage**: Previously fixed bugs
- **Runtime**: < 5 seconds
- **Prerequisites**: None

```bash
make test-category-14
```

## CI/CD Integration

The test suite runs automatically via GitHub Actions on:
- Pull request creation/update
- Push to `main` branch
- Release publication
- Manual workflow dispatch

### Workflow Jobs

**1. Test Suite** - Runs all automated tests (~2-5 minutes)
**2. Linting** - Shellcheck on all scripts (< 1 minute)
**3. Version Check** - Validates version consistency (< 1 minute)
**4. JSON Validation** - Validates plugin/marketplace JSON (< 1 minute)
**5. Security Checks** - Scans for secrets, validates seccomp (< 1 minute)

**Total runtime: ~3-7 minutes**

### Viewing CI Results

1. Navigate to repository on GitHub
2. Click "Actions" tab
3. Select workflow run
4. View job details and logs
5. Download test artifacts (if available)

### Local CI Simulation

Run the same checks locally before pushing:

```bash
# Test suite
make test-suite

# Linting
shellcheck hal-9000
shellcheck install-hal-9000.sh
shellcheck tests/*.sh

# Version consistency
make test-category-11

# JSON validation
jq empty .claude-plugin/marketplace.json
jq empty plugins/hal-9000/.claude-plugin/plugin.json

# Security (manual check for secrets)
grep -r "sk-ant-" . --exclude-dir=.git
```

## Interpreting Results

### Test Output Format

```
==========================================
Test Category N: Category Name
==========================================
HAL-9000 command: /path/to/hal-9000

[TEST] TEST-001: Description of test
[PASS] Success message
[TEST] TEST-002: Another test description
[SKIP] Manual test - requires Docker
  1. Step one
  2. Step two
  3. Verify: Expected result

==========================================
Test Results
==========================================
Passed:  8
Failed:  0
Skipped: 4 (manual or requires Docker)
Total:   12
==========================================
✅ All automated tests passed!
```

### Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed
- **>1**: Script error or invalid usage

### Test Status Indicators

- **[PASS]** ✅: Test passed successfully
- **[FAIL]** ❌: Test failed (needs attention)
- **[SKIP]** ⚠️: Test skipped (manual or missing prerequisites)
- **[TEST]**: Test starting
- **[INFO]**: Informational message

## Troubleshooting

### Common Issues

#### "Docker not available"

**Problem**: Docker tests skip due to missing Docker daemon

**Solution**:
```bash
# Check Docker status
docker ps

# On macOS
open -a Docker

# On Linux
sudo systemctl start docker
```

#### "jq: command not found"

**Problem**: JSON validation tests skip

**Solution**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

#### "Version mismatch" in Category 11

**Problem**: Versions not synchronized across files

**Solution**:
```bash
# Check current versions
grep -o 'version-[0-9.]*-blue' README.md
grep 'SCRIPT_VERSION=' hal-9000
jq -r '.version' plugins/hal-9000/.claude-plugin/plugin.json

# Update all to match (e.g., 2.0.0)
# - README.md: version badge
# - hal-9000: SCRIPT_VERSION variable
# - plugin.json: version field
# - marketplace.json: hal-9000 plugin version
```

#### Test hangs indefinitely

**Problem**: Test waiting for user input or external resource

**Solution**:
```bash
# Use timeout
timeout 60 ./tests/test-category-XX-name.sh

# Check for background processes
ps aux | grep hal-9000

# Kill if needed
pkill -f hal-9000
```

#### Permission denied on test scripts

**Problem**: Test scripts not executable

**Solution**:
```bash
chmod +x tests/test-category-*.sh
chmod +x tests/run-all-tests.sh
```

### Debugging Failed Tests

1. **Run with verbose mode**:
   ```bash
   ./tests/run-all-tests.sh --verbose
   ```

2. **Run specific failing category**:
   ```bash
   ./tests/test-category-XX-name.sh
   ```

3. **Check prerequisites**:
   ```bash
   # Bash version
   bash --version

   # Docker
   docker --version && docker ps

   # jq
   jq --version
   ```

4. **Review test code**:
   - Test scripts are in `tests/` directory
   - Well-commented with clear expectations
   - Can run individual test functions for debugging

5. **Check recent changes**:
   ```bash
   git log --oneline -10
   git diff HEAD~1
   ```

## Adding New Tests

### Adding to Existing Category

1. **Open test script**: `tests/test-category-XX-name.sh`

2. **Add test function**:
   ```bash
   test_xxx_NNN() {
       log_test "XXX-NNN: Brief description"

       # Test logic here
       if [[ condition ]]; then
           log_pass "Success message"
       else
           log_fail "Failure message"
       fi
   }
   ```

3. **Add to main() runner**:
   ```bash
   main() {
       # ... existing tests
       test_xxx_NNN || true
       # ...
   }
   ```

4. **Update test counts** in `tests/README.md`

5. **Test locally**:
   ```bash
   ./tests/test-category-XX-name.sh
   ```

### Adding New Test Category

1. **Create test script**: `tests/test-category-NN-name.sh`

2. **Use template structure**:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Colors and counters
   # ... (copy from existing test)

   # Test functions
   test_xxx_001() { ... }

   # Main runner
   main() {
       test_xxx_001 || true
       # Summary
   }

   main "$@"
   ```

3. **Make executable**:
   ```bash
   chmod +x tests/test-category-NN-name.sh
   ```

4. **Add to master runner** (`tests/run-all-tests.sh`):
   ```bash
   TESTS=(
       # ...
       "NN:Category Name:test-category-NN-name.sh"
   )
   ```

5. **Add Makefile target**:
   ```makefile
   test-category-NN:
       @echo "$(YELLOW)Running Test Category NN: Name...$(NC)"
       $(QUIET)./tests/test-category-NN-name.sh

   .PHONY: test-category-NN
   ```

6. **Update documentation**:
   - `tests/README.md`: Add category section
   - This file: Add to Test Categories section

7. **Test thoroughly**:
   ```bash
   # Run new category
   make test-category-NN

   # Run full suite
   make test-suite
   ```

### Adding Regression Tests

1. **Open** `tests/test-category-14-regression-suite.sh`

2. **Copy template** from comments in file

3. **Create test function**:
   ```bash
   # REG-NNN: [Description of bug]
   # Discovered: YYYY-MM-DD
   # Fixed: commit SHA
   test_reg_NNN() {
       log_test "REG-NNN: Bug description"

       # Reproduction steps
       # ...

       if [verification passes]; then
           log_pass "Bug REG-NNN fixed"
       else
           log_fail "Bug REG-NNN still present"
       fi
   }
   ```

4. **Add to main() runner**

5. **Document**:
   - Original issue date
   - Reproduction steps
   - Expected vs actual behavior
   - Fix commit SHA

## Best Practices

### Writing Tests

- **Clear descriptions**: Test names should explain what's being tested
- **Independent tests**: Each test should be self-contained
- **Idempotent**: Tests should be repeatable without side effects
- **Fast**: Automated tests should complete quickly (< 1 second each)
- **Documented**: Manual tests need clear step-by-step instructions

### Test Organization

- **Group related tests**: By category (setup, Docker, errors, etc.)
- **Use meaningful IDs**: TEST-001, DOCK-042, etc.
- **Consistent naming**: `test_prefix_number()` format
- **Helper functions**: Extract common logic

### Manual vs Automated

**Automate when**:
- Test can run without user interaction
- Prerequisites are commonly available
- Result is deterministic
- Runs quickly (< 10 seconds)

**Manual when**:
- Requires Docker container interaction
- Needs user authentication
- External dependencies (network, services)
- Long-running (> 30 seconds)

### Test Maintenance

- **Run tests regularly**: Before commits, during development
- **Update for changes**: When adding features or fixing bugs
- **Fix flaky tests**: Investigate and resolve non-deterministic failures
- **Keep current**: Update test expectations when behavior changes legitimately

### CI/CD Hygiene

- **Green main**: Main branch should always pass tests
- **Fix failures promptly**: Don't accumulate broken tests
- **Review before merge**: Check CI results on PRs
- **Version consistency**: Ensure synchronized before releases

## Additional Resources

- **Test plan**: `tests/HAL9000_TEST_PLAN.md` - Comprehensive test specifications
- **Test README**: `tests/README.md` - Overview and usage
- **CI/CD docs**: `.github/workflows/README.md` - GitHub Actions details
- **Makefile**: `Makefile` - All test targets and options

---

**Questions or issues?** Open an issue on GitHub or consult the test plan for detailed specifications.
