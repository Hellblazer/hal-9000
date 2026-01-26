# HAL-9000 Docker-in-Docker (DinD) Reference

This directory contains Dockerfiles and scripts for the Docker-in-Docker parent/worker architecture.

> **For complete DinD documentation and user guide**, see [`plugins/hal-9000/docs/dind/`](../docs/dind/) - the authoritative documentation source.
> This file is a technical reference for developers and operators working with the Docker files and scripts.

## Quick Start

The easiest way to use DinD is through the `claudy` CLI (v0.6.0+):

```bash
# Start the daemon (parent container with ChromaDB)
claudy daemon start

# Spawn a worker for your project
claudy --via-parent /path/to/project

# Check status
claudy daemon status
```

For more detailed instructions, see the [installation guide](../docs/dind/INSTALLATION.md).

## Architecture

This implementation provides:
- **Isolation**: Each Claude session runs in its own container
- **Resource Control**: CPU, memory, and process limits per worker
- **Scalability**: Warm worker pool for instant session startup
- **Shared Services**: ChromaDB runs in parent, accessible to all workers

See [ARCHITECTURE.md](../docs/dind/ARCHITECTURE.md) for technical design details.

## Files in This Directory

| File | Purpose |
|------|---------|
| `Dockerfile.parent` | Parent/coordinator container (~264MB) |
| `Dockerfile.worker-minimal` | Worker with git (~588MB) |
| `Dockerfile.worker-ultramin` | Worker without git (~469MB) |
| `parent-entrypoint.sh` | Parent container initialization |
| `spawn-worker.sh` | Worker spawning script |
| `coordinator.sh` | Worker management commands |
| `pool-manager.sh` | Warm worker pool manager |
| `init-volumes.sh` | Volume initialization |
| `setup-dashboard.sh` | tmux dashboard setup |
| `tmux-dashboard.conf` | tmux configuration |
| `test-phase1-integration.sh` | Integration tests |

## Full Documentation

Complete documentation is in the `docs/dind/` directory:

| Document | Description |
|----------|-------------|
| [README.md](../docs/dind/README.md) | Overview and quick start |
| [INSTALLATION.md](../docs/dind/INSTALLATION.md) | Setup and prerequisites |
| [CONFIGURATION.md](../docs/dind/CONFIGURATION.md) | Environment variables and options |
| [ARCHITECTURE.md](../docs/dind/ARCHITECTURE.md) | Technical design and components |
| [MIGRATION.md](../docs/dind/MIGRATION.md) | Upgrading from v0.5.x |
| [TROUBLESHOOTING.md](../docs/dind/TROUBLESHOOTING.md) | Common errors and recovery |
| [DEVELOPMENT.md](../docs/dind/DEVELOPMENT.md) | Contributing and extending |

## Manual Setup (Advanced)

To build and manage containers directly:

```bash
# Build parent image
docker build -f Dockerfile.parent -t ghcr.io/hellblazer/hal-9000:parent .

# Build worker image (choose one)
docker build -f Dockerfile.worker-minimal -t ghcr.io/hellblazer/hal-9000:worker .

# Initialize volumes
./init-volumes.sh

# Start parent container
docker run -d --name hal9000-parent \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.hal9000:/root/.hal9000 \
    ghcr.io/hellblazer/hal-9000:parent

# Spawn a worker
docker exec hal9000-parent /scripts/spawn-worker.sh /path/to/project
```

For detailed manual instructions, see [INSTALLATION.md](../docs/dind/INSTALLATION.md).

## Development

To make changes to the DinD system:

1. See [DEVELOPMENT.md](../docs/dind/DEVELOPMENT.md) for setup and testing
2. Run tests: `make test-dind`
3. Run benchmarks: `./scripts/build/benchmark-dind.sh all`

## Need Help?

- **Setup issues**: See [INSTALLATION.md](../docs/dind/INSTALLATION.md)
- **Configuration**: See [CONFIGURATION.md](../docs/dind/CONFIGURATION.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](../docs/dind/TROUBLESHOOTING.md)
- **Architecture questions**: See [ARCHITECTURE.md](../docs/dind/ARCHITECTURE.md)
- **Migrating from v0.5.x**: See [MIGRATION.md](../docs/dind/MIGRATION.md)
