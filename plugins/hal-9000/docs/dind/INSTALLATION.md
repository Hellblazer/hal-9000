# DinD Installation Guide

## Prerequisites

### System Requirements
- **OS**: Linux, macOS, or Windows with WSL2
- **Docker**: 20.10 or later
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 10GB free space for images

### Docker Configuration
Ensure Docker daemon is running:
```bash
docker ps
# Should show running containers (or empty list)
```

## Installation Methods

### Method 1: Using hal-9000 (Recommended)

If you already have hal-9000 installed:

```bash
# Update hal-9000 to v0.7.0+
./install-hal-9000.sh

# Verify version
hal-9000 --version
# Should show 0.7.0 or later
```

### Method 2: Building Images Locally

```bash
# Clone the repository
git clone https://github.com/Hellblazer/hal-9000.git
cd hal-9000

# Build parent image
docker build -f plugins/hal-9000/docker/Dockerfile.parent \
    -t ghcr.io/hellblazer/hal-9000:parent \
    plugins/hal-9000/docker/

# Build worker image (choose one)
# Minimal (with git, 588MB):
docker build -f plugins/hal-9000/docker/Dockerfile.worker-minimal \
    -t ghcr.io/hellblazer/hal-9000:worker \
    plugins/hal-9000/docker/

# Ultra-minimal (no git, 469MB):
docker build -f plugins/hal-9000/docker/Dockerfile.worker-ultramin \
    -t ghcr.io/hellblazer/hal-9000:worker \
    plugins/hal-9000/docker/
```

### Method 3: Pulling Pre-built Images

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/hellblazer/hal-9000:parent
docker pull ghcr.io/hellblazer/hal-9000:worker
```

## Initial Setup

### 1. Create Persistent Volumes

```bash
# Create volumes for shared data
docker volume create hal9000-chromadb
docker volume create hal9000-memorybank
docker volume create hal9000-plugins
```

### 2. Start the Daemon

```bash
# Using hal-9000
hal-9000 daemon start

# Or manually
docker run -d --name hal9000-parent \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.hal9000:/root/.hal9000 \
    -v hal9000-chromadb:/data/chromadb \
    ghcr.io/hellblazer/hal-9000:parent
```

### 3. Verify Installation

```bash
# Check daemon status
hal-9000 daemon status

# Expected output:
# HAL-9000 Daemon Status
# =====================
# Container: hal9000-parent
# Status: running
# ChromaDB: healthy (port 8000)
```

## Post-Installation

### Configure Anthropic API Key

```bash
# Set API key for all workers
export ANTHROPIC_API_KEY="sk-ant-..."

# Or add to ~/.bashrc or ~/.zshrc
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
```

### Enable Warm Worker Pool (Optional)

For faster session startup:

```bash
# Start daemon with pool manager
hal-9000 daemon stop
ENABLE_POOL_MANAGER=true hal-9000 daemon start

# Or restart with pool
hal-9000 pool start
```

## Uninstallation

```bash
# Stop daemon
hal-9000 daemon stop

# Remove containers
docker rm -f hal9000-parent
docker ps -a --filter "name=hal9000-" --format "{{.Names}}" | xargs docker rm -f

# Remove volumes (optional - this deletes all data)
docker volume rm hal9000-chromadb hal9000-memorybank hal9000-plugins

# Remove images (optional)
docker rmi ghcr.io/hellblazer/hal-9000:parent
docker rmi ghcr.io/hellblazer/hal-9000:worker
```

## Platform-Specific Notes

### Linux
- Docker socket at `/var/run/docker.sock` (default)
- No additional configuration needed

### macOS
- Requires Docker Desktop
- Docker socket forwarded automatically
- Ensure Docker Desktop is running

### Windows (WSL2)
- Requires Docker Desktop with WSL2 backend
- Run hal-9000 from within WSL2 terminal
- Ensure Docker integration enabled in WSL2 settings

## Next Steps

- [Configuration Guide](CONFIGURATION.md) - Customize settings
- [Migration Guide](MIGRATION.md) - Upgrade from v0.5.x
- [Architecture](ARCHITECTURE.md) - Understand the system

---

**Navigation**: [Overview](README.md) | [Installation](INSTALLATION.md) | [Configuration](CONFIGURATION.md) | [Architecture](ARCHITECTURE.md) | [Migration](MIGRATION.md) | [Troubleshooting](TROUBLESHOOTING.md) | [Development](DEVELOPMENT.md)

**Quick Links**: [Quick Start](#quick-start) | [Prerequisites](#prerequisites) | [Uninstallation](#uninstallation)
