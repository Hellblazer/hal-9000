# HAL-9000 CI/CD Workflows

This directory contains GitHub Actions workflows for automated testing, validation, and security checks.

## Workflows

### test-suite.yml

Comprehensive test and validation pipeline that runs on:
- **Pull Requests**: Validates changes before merge
- **Push to main**: Ensures main branch remains healthy
- **Releases**: Validates release builds
- **Manual trigger**: Can be run on-demand via Actions tab

#### Jobs

**1. Test Suite (`test`)**
- Runs comprehensive test suite (all 13+ categories)
- Validates Docker availability
- Uploads test results as artifacts
- Exit code indicates pass/fail

**2. Shell Script Linting (`lint`)**
- Runs shellcheck on hal-9000 main script
- Lints install-hal-9000.sh
- Checks all test category scripts
- Continues on errors (warnings only)

**3. Version Consistency (`version-check`)**
- Extracts version from:
  - README.md badge
  - hal-9000 script (SCRIPT_VERSION)
  - plugin.json
  - marketplace.json
- Fails if versions don't match
- Critical for releases

**4. JSON Validation (`json-validation`)**
- Validates marketplace.json syntax and structure
- Validates plugin.json syntax
- Ensures required fields present
- Prevents broken plugin installations

**5. Security Checks (`security-check`)**
- Scans for hardcoded secrets/API keys
- Verifies seccomp profiles exist
- Validates seccomp JSON syntax
- Prevents security vulnerabilities

## Usage

### Automatic Triggers

Workflows run automatically on:
```bash
# Pull request creation/update
git push origin feature-branch
# Then create PR on GitHub

# Push to main (after PR merge)
git push origin main

# Release publication
gh release create v2.0.0 --title "Release 2.0.0"
```

### Manual Trigger

Run workflow on-demand:
1. Go to Actions tab on GitHub
2. Select "HAL-9000 Test Suite"
3. Click "Run workflow"
4. Choose branch
5. Click green "Run workflow" button

### Local Testing

Run the same checks locally before pushing:

```bash
# Full test suite
make test-suite

# Individual checks
make test-category-01
make test-category-07
# ... etc

# Version consistency check
./tests/test-category-11-installation-distribution.sh

# JSON validation
jq empty .claude-plugin/marketplace.json
jq empty plugins/hal-9000/.claude-plugin/plugin.json

# Shellcheck linting
shellcheck hal-9000
shellcheck install-hal-9000.sh
shellcheck tests/*.sh
```

## Test Results

### Viewing Results

**On GitHub:**
1. Go to Actions tab
2. Click on workflow run
3. View job output for details
4. Download test artifacts (if available)

**Artifacts:**
- Test logs (retained 30 days)
- Individual test category results
- Error details for failures

### Interpreting Results

**✅ Green checkmark**: All tests passed
**❌ Red X**: One or more tests failed
**⚠️ Yellow dot**: Workflow in progress

**Common failures:**
- Version mismatch: Update all version strings to match
- JSON syntax error: Validate JSON with jq
- Test failure: Check test output for specific error
- Docker unavailable: Ensure Docker service running

## Adding New Tests

When adding test categories:

1. Create test script: `tests/test-category-NN-name.sh`
2. Make executable: `chmod +x tests/test-category-NN-name.sh`
3. Add to master runner: `tests/run-all-tests.sh`
4. Add Makefile target: `Makefile`
5. Update README: `tests/README.md`
6. CI will automatically include it (runs `run-all-tests.sh`)

## Skipping CI

To skip CI on a commit (use sparingly):
```bash
git commit -m "docs: update README [skip ci]"
```

## Troubleshooting

**Version check fails:**
- Ensure README badge, hal-9000 script, plugin.json, marketplace.json all have same version
- Run: `make test-category-11` locally to verify

**JSON validation fails:**
- Validate locally: `jq empty <file.json>`
- Check for trailing commas, missing quotes, syntax errors

**Test suite times out:**
- Default timeout: 60 minutes
- Most tests are fast (automated)
- Manual/Docker tests are skipped in CI
- If timeout occurs, check for hanging processes

**Shellcheck warnings:**
- Not fatal (continues on error)
- Address warnings for code quality
- Common: quote variables, check command existence

## Security

**Secrets handling:**
- Never commit API keys or secrets
- Use GitHub Secrets for sensitive data
- Security check job scans for common patterns
- Seccomp profiles validated for production use

**Protected branches:**
- Require CI to pass before merge
- Require review for main branch
- Prevent force pushes to main

## Performance

**Typical run times:**
- Test suite: 2-5 minutes (automated tests only)
- Lint: < 1 minute
- Version check: < 1 minute
- JSON validation: < 1 minute
- Security checks: < 1 minute

**Total: ~3-7 minutes per workflow run**

## Future Enhancements

Potential improvements:
- Docker image building and testing
- Performance benchmarks (Category 13)
- Integration test scenarios
- Release automation
- Codecov integration
- Dependency scanning
