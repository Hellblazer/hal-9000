# DinD Development Guide

## Development Setup

### Prerequisites
- Docker 20.10+
- Bash 4.0+
- Git
- Make (optional)

### Clone and Build

```bash
# Clone repository
git clone https://github.com/Hellblazer/hal-9000.git
cd hal-9000

# Build images locally
make build-base

# Or build specific images
docker build -f plugins/hal-9000/docker/Dockerfile.parent \
    -t ghcr.io/hellblazer/hal-9000:parent \
    plugins/hal-9000/docker/

docker build -f plugins/hal-9000/docker/Dockerfile.worker-minimal \
    -t ghcr.io/hellblazer/hal-9000:worker \
    plugins/hal-9000/docker/
```

## Project Structure

```
plugins/hal-9000/docker/
├── Dockerfile.parent           # Parent container image
├── Dockerfile.worker           # Standard worker image
├── Dockerfile.worker-minimal   # Worker with git
├── Dockerfile.worker-ultramin  # Worker without git
├── parent-entrypoint.sh        # Parent startup script
├── spawn-worker.sh             # Worker spawning script
├── pool-manager.sh             # Warm worker pool manager
├── coordinator.sh              # Worker management
├── README-dind.md              # Architecture documentation
└── ...

scripts/build/
├── test-pool-manager.sh        # Pool manager tests
├── test-resource-limits.sh     # Resource limit tests
├── benchmark-dind.sh           # Performance benchmarks
└── ...
```

## Running Tests

### Unit Tests

```bash
# All DinD tests
make test-dind

# Individual test suites
./scripts/build/test-pool-manager.sh all
./scripts/build/test-resource-limits.sh all
```

### Integration Tests

```bash
# Phase integration tests
./plugins/hal-9000/docker/test-phase1-integration.sh
./plugins/hal-9000/docker/test-phase2-integration.sh
./plugins/hal-9000/docker/test-phase3-integration.sh
./plugins/hal-9000/docker/test-phase4-integration.sh
```

### Performance Benchmarks

```bash
# Run all benchmarks
make benchmark-dind

# Or directly
./scripts/build/benchmark-dind.sh all

# Specific benchmarks
./scripts/build/benchmark-dind.sh cold warm
```

## Development Workflow

### Making Changes

1. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes to scripts/Dockerfiles**

3. **Test locally**
   ```bash
   # Rebuild affected images
   docker build -f plugins/hal-9000/docker/Dockerfile.parent \
       -t ghcr.io/hellblazer/hal-9000:parent \
       plugins/hal-9000/docker/

   # Test changes
   claudy daemon stop
   claudy daemon start
   claudy --via-parent /tmp/test
   ```

4. **Run tests**
   ```bash
   make test-dind
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin feature/my-feature
   ```

### Debugging

#### Parent Container

```bash
# View logs
docker logs hal9000-parent -f

# Shell into parent
docker exec -it hal9000-parent bash

# Check ChromaDB
curl http://localhost:8000/api/v2/heartbeat
```

#### Worker Container

```bash
# List workers
docker ps --filter "name=hal9000-worker"

# Shell into worker
docker exec -it <worker-name> bash

# Check connectivity to ChromaDB
docker exec <worker-name> curl http://localhost:8000/api/v2/heartbeat
```

#### Pool Manager

```bash
# Check pool status
claudy pool status

# View pool manager logs
cat ~/.hal9000/logs/pool-manager.log

# Manual pool operations
./plugins/hal-9000/docker/pool-manager.sh status
./plugins/hal-9000/docker/pool-manager.sh warm
```

## Adding New Features

### Adding a New Environment Variable

1. **Update parent-entrypoint.sh**
   ```bash
   MY_VAR="${MY_VAR:-default_value}"
   ```

2. **Update Dockerfile.parent (if needed)**
   ```dockerfile
   ENV MY_VAR=default_value
   ```

3. **Update documentation**
   - `docs/dind/CONFIGURATION.md`
   - `README-dind.md`

4. **Add tests**

### Adding a New Script

1. **Create script in `plugins/hal-9000/docker/`**

2. **Make executable**
   ```bash
   chmod +x plugins/hal-9000/docker/my-script.sh
   ```

3. **Copy in Dockerfile**
   ```dockerfile
   COPY my-script.sh /scripts/my-script.sh
   RUN chmod +x /scripts/my-script.sh
   ```

4. **Add tests in `scripts/build/test-my-script.sh`**

### Adding a New Claudy Subcommand

1. **Add handler function in `claudy`**
   ```bash
   handle_my_command() {
       # Implementation
   }
   ```

2. **Add to main dispatch**
   ```bash
   if [[ "${1:-}" == "mycommand" ]]; then
       shift
       handle_my_command "$@"
       exit 0
   fi
   ```

3. **Update help text**

4. **Add tests**

## Code Style

### Bash Scripts

- Use `set -euo pipefail`
- Quote all variables: `"$var"`
- Use `local` for function variables
- Add descriptive comments for non-obvious code
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output

### Dockerfiles

- Use multi-line RUN with `&&` for related commands
- Clean up apt lists: `rm -rf /var/lib/apt/lists/*`
- Use `--no-install-recommends`
- Add labels for metadata
- Document with comments

## Testing Guidelines

### Test Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# Setup
setup_test_environment() {
    TEST_DIR=$(mktemp -d)
    # ...
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
    # ...
}
trap cleanup EXIT

# Tests
test_feature_works() {
    log_test "Feature works correctly"
    # Test implementation
    if [[ condition ]]; then
        log_pass "Feature works"
    else
        log_fail "Feature failed"
    fi
}

# Main
main() {
    setup_test_environment
    test_feature_works
    # ...
}

main "$@"
```

### Test Categories

- **Unit Tests**: Test individual functions
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test full workflows
- **Benchmarks**: Measure performance

## Releasing

### Version Bump

1. Update version in relevant files:
   - `claudy` (VERSION variable)
   - `Dockerfile.*` labels
   - Documentation

2. Update CHANGELOG.md

3. Tag release
   ```bash
   git tag -a v0.6.1 -m "Release v0.6.1"
   git push origin v0.6.1
   ```

### Building Release Images

```bash
# Build all images
make build

# Tag for release
docker tag ghcr.io/hellblazer/hal-9000:parent ghcr.io/hellblazer/hal-9000:parent-v0.6.1
docker tag ghcr.io/hellblazer/hal-9000:worker ghcr.io/hellblazer/hal-9000:worker-v0.6.1

# Push to registry
docker push ghcr.io/hellblazer/hal-9000:parent-v0.6.1
docker push ghcr.io/hellblazer/hal-9000:worker-v0.6.1
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit pull request

See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for detailed guidelines.

---

**Navigation**: [Overview](README.md) | [Installation](INSTALLATION.md) | [Configuration](CONFIGURATION.md) | [Architecture](ARCHITECTURE.md) | [Migration](MIGRATION.md) | [Troubleshooting](TROUBLESHOOTING.md) | [Development](DEVELOPMENT.md)

**Quick Links**: [Development Setup](#development-setup) | [Running Tests](#running-tests) | [Development Workflow](#development-workflow) | [Contributing](#contributing)
