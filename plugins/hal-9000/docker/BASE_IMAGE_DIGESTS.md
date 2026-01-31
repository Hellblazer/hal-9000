# Base Image Digest Pinning

## Overview

All external base images in HAL-9000 Dockerfiles use digest pinning for security and reproducibility. This prevents supply chain attacks where upstream images are modified without notice.

## Current Pinned Images

| Image | Tag | Digest | Pinned Date | Used In |
|-------|-----|--------|-------------|---------|
| debian | bookworm-slim | sha256:56ff6d36... | 2026-01-31 | parent, hal9000, worker-minimal, worker-ultramin |
| node | 20-bookworm-slim | sha256:6c51af7d... | 2026-01-31 | worker |
| ubuntu | 24.04 | sha256:cd1dba65... | 2026-01-31 | test-full |
| docker | 27-dind | sha256:aa3df78e... | 2026-01-31 | test |

## Updating Digests

When you need to update to a newer base image:

### 1. Pull the new image by tag

```bash
docker pull debian:bookworm-slim
docker pull node:20-bookworm-slim
docker pull ubuntu:24.04
docker pull docker:27-dind
```

### 2. Get the digest

```bash
# For debian
docker inspect debian:bookworm-slim --format='{{index .RepoDigests 0}}'
# Output: debian@sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee

# For node
docker inspect node:20-bookworm-slim --format='{{index .RepoDigests 0}}'

# For ubuntu
docker inspect ubuntu:24.04 --format='{{index .RepoDigests 0}}'

# For docker
docker inspect docker:27-dind --format='{{index .RepoDigests 0}}'
```

### 3. Update Dockerfile

Replace the FROM statement:

**Before:**
```dockerfile
FROM debian:bookworm-slim
```

**After:**
```dockerfile
# debian:bookworm-slim (pinned 2026-01-31)
FROM debian@sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee
```

Format:
- Line 1: Comment with original tag and pin date
- Line 2: FROM with image@digest

### 4. Validate digests

Run the validation script:

```bash
cd plugins/hal-9000/docker
./validate-base-image-digests.sh
```

This pulls each digest to verify it's accessible and valid.

### 5. Test builds

Build and test affected images:

```bash
# Parent image
docker build -f Dockerfile.parent -t ghcr.io/hellblazer/hal-9000:parent .

# Worker image
docker build -f Dockerfile.worker -t ghcr.io/hellblazer/hal-9000:worker .

# Test functionality
docker run --rm ghcr.io/hellblazer/hal-9000:worker claude --version
```

## Why Digest Pinning?

**Security Benefits:**
- **Immutability**: Digest references are cryptographically immutable
- **Supply Chain Protection**: Prevents upstream tag overwrites
- **Reproducible Builds**: Same digest always produces same image
- **Audit Trail**: Explicit tracking of when base images were updated

**Trade-offs:**
- Manual updates required (no automatic security patches)
- Slightly less readable than tags
- Need process to monitor upstream security updates

## Monitoring Upstream Updates

Base images should be updated:
- On security advisories for Debian, Node.js, Ubuntu, or Docker
- Monthly review of upstream releases
- When new features/fixes are needed from base image

## Automation (Future)

The `hal-9000-h4i` bead tracks creating digest update automation:
- Scheduled checks for new upstream releases
- Security vulnerability scanning
- Automated PR creation for digest updates
- CI validation before merge

## References

- [Docker Image Manifest Specification](https://docs.docker.com/registry/spec/manifest-v2-2/)
- [HAL-9000 Security Policy](../SECURITY.md)
- Related: `hal-9000-dot` (Pin base image digests)
- Related: `hal-9000-h4i` (Create digest update automation)
