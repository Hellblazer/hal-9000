# P0-4: Worker Image Size Validation Spike

**Bead**: hal-9000-f6t.7.4
**Date**: 2026-01-25
**Status**: COMPLETE
**Result**: GO (with conditions)

## Executive Summary

The 500MB worker image target is **achievable** but requires trade-offs. A worker image without git is 469MB (under target). With git support, the minimum is 588MB (17.6% over target).

## Image Size Comparison

| Image | Size | Status |
|-------|------|--------|
| hal9000-worker-ultramin (no git) | **469MB** | UNDER TARGET |
| hal9000-worker-minimal (with git) | **588MB** | +88MB over |
| hal9000-full-test (current) | **2.85GB** | Baseline |
| debian:bookworm-slim (base) | ~74MB | Foundation |

## Dockerfile Used (with git)

```dockerfile
# Dockerfile.worker-minimal
FROM debian:bookworm-slim

LABEL maintainer="hal-9000"
LABEL description="Minimal worker image - Claude CLI only (validation spike)"
LABEL version="0.1.0-spike"

# Minimal dependencies only - no build tools, no dev packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

# Set locale for proper UTF-8 support (required by Claude CLI)
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Add Claude CLI location to PATH (install.sh puts it in ~/.local/bin)
ENV PATH="/root/.local/bin:${PATH}"

# Install Claude CLI (native binary)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create minimal workspace
RUN mkdir -p /workspace

WORKDIR /workspace

# Verify Claude CLI installation
RUN claude --version

# Default command
CMD ["bash"]
```

## Build Output

```
Successfully built hal9000-worker-minimal
Image Size: 588MB
Claude CLI Version: 2.1.19
```

## Layer Breakdown (with git - 588MB)

| Component | Size | Notes |
|-----------|------|-------|
| Claude CLI binary | 206MB | Single binary at /root/.local/share/claude/versions/2.1.19 |
| /usr (system libs) | 213MB | Includes git, perl, core utilities |
| /var (apt cache remnants) | 7.3MB | Minimal after cleanup |
| /etc (config) | 1.4MB | Standard config files |

### Key Package Sizes (with git)

| Package | Size (KB) | Notes |
|---------|-----------|-------|
| git | 45,520 | Requires perl |
| libperl5.36 | 30,617 | Git dependency |
| libc6 | 23,130 | Core library |
| coreutils | 20,272 | Essential commands |
| perl-modules | 17,817 | Git dependency |
| locales | 15,846 | UTF-8 support |

## Layer Breakdown (without git - 469MB)

| Component | Size | Notes |
|-----------|------|-------|
| Claude CLI binary | 206MB | Unchanged |
| /usr (system libs) | 126MB | 87MB saved without git/perl |
| /var | 6.7MB | Slightly smaller |
| /etc | 1.3MB | Minimal |

### Key Package Sizes (without git)

| Package | Size (KB) | Notes |
|---------|-----------|-------|
| libc6 | 23,130 | Core library |
| coreutils | 20,272 | Essential commands |
| locales | 15,846 | UTF-8 support |
| util-linux | 7,910 | Core utilities |
| perl-base | 7,844 | Minimal perl (not full) |
| bash | 7,295 | Shell |
| libssl3 | 5,982 | TLS support |

## Comparison to Targets

| Original Plan | Revised Target | Actual (with git) | Actual (no git) |
|---------------|----------------|-------------------|-----------------|
| <300MB | <500MB | 588MB | **469MB** |

- **With git**: 588MB is 17.6% over the 500MB revised target
- **Without git**: 469MB is 6.2% UNDER the 500MB revised target

## Optimization Opportunities Identified

### 1. Remove Git (saves ~119MB) - RECOMMENDED
- Workers can mount git repos from host via Docker volumes
- Git operations happen on coordinator or host
- Result: 469MB image (under target)

### 2. Alpine Linux Base (potential -50MB)
- Alpine uses musl libc instead of glibc
- Risk: Compatibility issues with Claude CLI binary
- **Not tested** - would require validation

### 3. Remove Locales (saves ~16MB) - NOT RECOMMENDED
- Claude CLI requires proper UTF-8 support
- Risk: CLI failures with encoding issues

### 4. Multi-stage Build (marginal improvement)
- Already removing apt lists
- Not much more to optimize

### 5. UPX Compression on Claude Binary
- Claude CLI is a native binary (206MB)
- UPX could reduce by 50-70%
- Risk: Performance impact, Anthropic support issues
- **Not recommended**

## GO/NO-GO Recommendation

### **GO - With Conditions**

The 500MB target is achievable under these conditions:

1. **Recommended Configuration**: No git in worker image (469MB)
   - Git repos mounted from host via `-v`
   - Coordinator handles git operations
   - Workers are stateless execution units

2. **Alternative Configuration**: Accept 588MB for git-enabled workers
   - Revise target to 600MB
   - Trade-off: Simplicity vs size

### Reasoning

1. **Claude CLI is non-negotiable** at 206MB
2. **Core system libs** (libc, coreutils, curl) add ~100MB minimum
3. **Git + Perl dependency** adds ~120MB
4. **Without git**: 469MB is well under 500MB target
5. **With git**: 588MB is reasonable for full functionality

### Implementation Path

For Phase 1 implementation, recommend:

```dockerfile
# Production worker image (no git)
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV PATH="/root/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash
WORKDIR /workspace
CMD ["bash"]
```

## Files Created

1. `/Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/Dockerfile.worker-minimal` - With git (588MB)
2. `/Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker/Dockerfile.worker-ultramin` - Without git (469MB)

## Success Criteria Checklist

- [x] Minimal Dockerfile created
- [x] Image built successfully
- [x] Size measured and documented (469MB / 588MB)
- [x] Comparison to 500MB target (469MB under, 588MB over)
- [x] Clear GO/NO-GO recommendation (**GO with no-git configuration**)

## Appendix: Build Commands

```bash
# Build minimal (with git)
cd /Users/hal.hildebrand/git/hal-9000/plugins/hal-9000/docker
docker build -f Dockerfile.worker-minimal -t hal9000-worker-minimal .

# Build ultra-minimal (no git)
docker build -f Dockerfile.worker-ultramin -t hal9000-worker-ultramin .

# Compare sizes
docker images --format "table {{.Repository}}\t{{.Size}}" | grep hal9000

# Inspect layer breakdown
docker run --rm hal9000-worker-minimal du -sh /usr /var /root /etc
```
