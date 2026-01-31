# HAL-9000 Docker Images & Orchestration

Pre-built Docker images for containerized Claude with parent-worker orchestration, TMUX socket-based communication, and development tools.

## Orchestration Architecture

### TMUX Socket-Based Parent-Worker Model

Workers run independent TMUX servers communicating with parent coordinator via Unix domain sockets:

```
Parent Container                Worker Containers
┌─────────────────────┐        ┌──────────────────┐
│ Coordinator         │◄──────►│ TMUX Socket      │
│ ChromaDB (8000)     │        │ Claude CLI       │
│ (parent.sock)       │        │ Session: worker1 │
└─────────────────────┘        └──────────────────┘
         │
         │                      ┌──────────────────┐
         ├─────────────────────►│ TMUX Socket      │
         │                      │ Claude CLI       │
         │                      │ Session: worker2 │
         │                      └──────────────────┘
         │
         │                      ┌──────────────────┐
         └─────────────────────►│ TMUX Socket      │
                                │ Claude CLI       │
                                │ Session: worker3 │
                                └──────────────────┘

Shared Volumes:
├── hal9000-tmux-sockets/       Socket IPC endpoints
├── hal9000-coordinator-state/  Worker registry, health
├── hal9000-claude-home/        Plugins, credentials
└── hal9000-memory-bank/        Cross-session state
```

**Key Features:**
- ✅ Independent TMUX servers (each worker isolated)
- ✅ Socket-based IPC (no TTY, no namespace sharing)
- ✅ Network isolation (bridge networking, not shared namespace)
- ✅ Session persistence (TMUX handles state)
- ✅ Coordinator monitoring (worker lifecycle, socket health)
- ✅ Easy worker management (attach, send commands, monitor)

### Worker Management Commands

```bash
# Monitor all workers
show-workers.sh              # Status table with socket health
show-workers.sh -w           # Live monitoring (2s refresh)

# Attach to worker
attach-worker.sh worker-abc  # Interactive TMUX attach
attach-worker.sh -s          # Interactive worker selection

# Send commands
tmux-send.sh worker-abc "command" -c  # Send + capture output

# Discovery
tmux-list-sessions.sh        # List all sessions
```

[Detailed TMUX Architecture Guide →](../docs/TMUX_ARCHITECTURE.md)

## ghcr.io/hellblazer/hal-9000 Profile Images

Optimized container images with pre-installed Claude CLI and tools for instant startup. Available in multiple language profiles.

**Published to GitHub Container Registry**

### Available Images

| Image | Profile | Includes |
|-------|---------|----------|
| `ghcr.io/hellblazer/hal-9000:latest` | **Base** | Claude CLI, claude-code-tools, git, tmux, uv |
| `ghcr.io/hellblazer/hal-9000:python` | **Python** | Base + Python 3.11, pip, venv |
| `ghcr.io/hellblazer/hal-9000:node` | **Node.js** | Base + Node 20 LTS, npm, yarn, pnpm |
| `ghcr.io/hellblazer/hal-9000:java` | **Java** | Base + Java 21 LTS, Maven, Gradle |

### Features

- ✅ **Claude CLI pre-installed** - No per-container Claude installation
- ✅ **Zero download time** - All tools pre-installed
- ✅ **Language profiles** - Python, Node.js, Java ready to use
- ✅ **Docker layer caching** - Efficient builds
- ✅ **claude-code-tools** - tmux-cli, vault, env-safe, aichat (all images)
- ✅ **Public & free** - No rate limits, no authentication required

### Quick Start

Pull the published image:
```bash
docker pull ghcr.io/hellblazer/hal-9000:latest
```

aod automatically uses this image - no configuration needed.

### Build Profiles (Optional)

**Build all profiles:**
```bash
cd /path/to/hal-9000/plugins/hal-9000/docker
./build-profiles.sh
```

**Build specific profiles:**
```bash
./build-profiles.sh python node  # Only Python and Node.js
```

**Build and push to registry:**
```bash
./build-profiles.sh --push
```

**Build single profile manually:**
```bash
docker build -f docker/Dockerfile.python -t ghcr.io/hellblazer/hal-9000:python .
```

### Use with aod

**aod.sh is pre-configured** to use `ghcr.io/hellblazer/hal-9000:latest` automatically. No additional configuration needed - just use aod normally:

```bash
# Configuration file already uses optimized image
aod aod.conf
```

**Alternative: Direct docker run**
```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -v "$HOME/.claude:/root/.claude" \
  -v "hal9000-claude-home:/root/.claude/marketplace" \
  ghcr.io/hellblazer/hal-9000:latest
```

### Verification

Test that tools are available:

```bash
docker run --rm ghcr.io/hellblazer/hal-9000:latest tmux-cli --version
docker run --rm ghcr.io/hellblazer/hal-9000:latest which tmux-cli
```

### Performance Comparison

**Without pre-installed tools:**
- First container: ~30 seconds (download + install)
- 5 containers: ~150 seconds total

**With ghcr.io/hellblazer/hal-9000 image:**
- First container: ~5 seconds (instant)
- 5 containers: ~25 seconds total
- **Savings: 125 seconds + bandwidth**

### Language-Specific Images

Create extended images for specific languages:

**Python:**
```dockerfile
FROM ghcr.io/hellblazer/hal-9000:latest

RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    && rm -rf /var/lib/apt/lists/*
```

**Node.js:**
```dockerfile
FROM ghcr.io/hellblazer/hal-9000:latest

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*
```

### Updating

When new tools are released:

```bash
# Pull latest version from GitHub Container Registry
docker pull ghcr.io/hellblazer/hal-9000:latest

# Or rebuild locally with latest tools
docker build -f docker/Dockerfile.hal9000 -t ghcr.io/hellblazer/hal-9000:latest --no-cache .
```

### Publishing

**Status:** Published to GitHub Container Registry
- `ghcr.io/hellblazer/hal-9000:latest`
- `ghcr.io/hellblazer/hal-9000:1.3.0`

**Prerequisites:**
1. Create GitHub Personal Access Token with `write:packages` scope at https://github.com/settings/tokens
2. Authenticate: `echo $GITHUB_TOKEN | docker login ghcr.io -u hellblazer --password-stdin`

**To publish updates:**

```bash
# Build new version
docker build -f docker/Dockerfile.hal9000 -t ghcr.io/hellblazer/hal-9000:latest .

# Tag with version
docker tag ghcr.io/hellblazer/hal-9000:latest ghcr.io/hellblazer/hal-9000:1.3.0

# Push both tags
docker push ghcr.io/hellblazer/hal-9000:latest
docker push ghcr.io/hellblazer/hal-9000:1.3.0
```

**Make image public:**
1. Go to https://github.com/users/Hellblazer/packages/container/hal-9000/settings
2. Change visibility to "Public"
3. Link to repository: Select `Hellblazer/hal-9000`

## Multi-Stage Builds

For production use, create multi-stage builds to minimize image size:

```dockerfile
# Builder stage
FROM debian:bookworm-slim AS builder
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN /root/.cargo/bin/uv tool install claude-code-tools

# Runtime stage
FROM debian:bookworm-slim
COPY --from=builder /root/.local /root/.local
ENV PATH="/root/.local/bin:${PATH}"
```

## Troubleshooting

### Tools not found in container

```bash
# Check PATH
docker run --rm ghcr.io/hellblazer/hal-9000:latest bash -c 'echo $PATH'

# Verify installation
docker run --rm ghcr.io/hellblazer/hal-9000:latest ls -la /root/.local/bin/
```

### Image too large

Check layer sizes:
```bash
docker history ghcr.io/hellblazer/hal-9000:latest
```

Use multi-stage builds to reduce size.

### Need different Python version

Modify Dockerfile to install specific Python version:
```dockerfile
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.12
```
