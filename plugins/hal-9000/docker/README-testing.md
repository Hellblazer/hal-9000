# HAL-9000 Testing Infrastructure

Two test environments are available:

## Quick Tests (CI - Alpine/DinD)

Used by GitHub Actions for fast validation of the test infrastructure.

```bash
# Build
docker build -f docker/Dockerfile.test -t hal9000-test .

# Run quick tests (validates DinD, prerequisites, tmux)
docker run --privileged --rm hal9000-test /hal-9000/test/run-tests.sh --quick

# Interactive mode
docker run --privileged -it hal9000-test
```

**What it tests:**
- Docker-in-Docker works
- Prerequisites installed (bash, curl, git, python3, node, npm, tmux, jq)
- tmux available

## Full Tests (Local - Ubuntu)

For thorough testing of complete hal-9000 installation. NOT used by CI.

```bash
# Build
docker build -f docker/Dockerfile.test-full -t hal9000-test-full .

# Run full tests (installs everything, takes several minutes)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    hal9000-test-full /hal-9000/test/run-full-tests.sh

# Interactive mode
docker run -it -v /var/run/docker.sock:/var/run/docker.sock \
    hal9000-test-full

# Skip installation (test pre-installed components)
docker run --rm hal9000-test-full /hal-9000/test/run-full-tests.sh --skip-install
```

**What it tests:**
- All prerequisites
- Full hal-9000 installation (MCP servers, hooks, agents, commands)
- Safety hooks deployment
- Custom agents installation
- Session commands installation
- tmux-cli installation
- Container tests (pulls from ghcr.io)

**Requirements:**
- Sufficient disk space (~5GB for dependencies)
- Docker socket mounted for container tests
- Network access for pip/npm installs

## Test Flags

| Flag | Quick Tests | Full Tests | Description |
|------|-------------|------------|-------------|
| `--quick` | Default in CI | N/A | Skip installation-dependent tests |
| `--verbose` | ✓ | ✓ | Show detailed output |
| `--skip-install` | N/A | ✓ | Skip installation phase |

## Files

- `Dockerfile.test` - Alpine DinD for quick CI tests
- `Dockerfile.test-full` - Ubuntu for thorough local tests
- `test-harness.sh` - Quick test script
- `test-harness-full.sh` - Full test script
- `entrypoint-test.sh` - DinD entrypoint (starts dockerd)
- `entrypoint-test-full.sh` - Ubuntu entrypoint
