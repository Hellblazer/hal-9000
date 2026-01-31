# HAL-9000 Security Documentation

This document describes the security model, known risks, and mitigations for the hal-9000 containerized Claude infrastructure.

## Security Architecture

### Non-Root Container Execution

Worker containers run as the `claude` user (UID 1001) rather than root:

```dockerfile
USER claude
```

**Benefits:**
- Limits damage from container escape vulnerabilities
- Follows principle of least privilege
- Volume permissions align with typical host user (UID 1001)

**Affected paths:**
- `/home/claude/.claude` - Claude configuration
- `/home/claude/memory-bank` - Memory Bank data
- `/workspace` - Project files

### Volume Permission Handling

Worker containers run as UID 1001 (claude user). If your host user has a different UID:

**Option 1: Build Custom Image with Matching UID**
```dockerfile
# Dockerfile.worker-custom
FROM ghcr.io/hellblazer/hal-9000:worker

ARG HOST_UID=501
USER root
RUN usermod -u ${HOST_UID} claude && \
    chown -R claude:claude /home/claude
USER claude
```

```bash
# Build with your host UID
docker build --build-arg HOST_UID=$(id -u) -f Dockerfile.worker-custom -t hal9000-custom:worker .
```

**Option 2: Docker User Namespace Remapping** (Linux only)
```bash
# Configure Docker daemon to remap container UID to host UID
# /etc/docker/daemon.json:
{
  "userns-remap": "default"
}

# Restart Docker
sudo systemctl restart docker
```

**Check your UID:** Run `id -u` on the host to see your user ID.
- Linux typically uses UID 1000 (close to container UID 1001 - may not need custom image)
- macOS typically uses UID 501-503 (requires custom image)
- Enterprise environments may use UID ranges 10000+ (requires custom image)

### Image Allowlisting

Worker images are validated against an allowlist to prevent supply chain attacks:

```bash
ALLOWED_IMAGES=(
    "ghcr.io/hellblazer/hal-9000:worker-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    # Versioned tags for supply chain security
)
```

**Rationale:** Prevents arbitrary image execution that could contain malicious code.

**Security Levels:**
1. **Version tags** (current): Tags like `:worker-v3.0.0` won't be reused, providing good protection
2. **SHA digests** (maximum): Add `@sha256:...` suffix for cryptographic verification

**Upgrading to SHA Digests:**
```bash
# Update allowlist with SHA digests for maximum security
./scripts/update-image-shas.sh --update
```

This produces entries like:
```bash
"ghcr.io/hellblazer/hal-9000:worker-v3.0.0@sha256:abc123..."
```

### Python Dependency Pinning

The parent container pins Python dependencies to exact versions:

```
# plugins/hal-9000/docker/requirements-parent.txt
chromadb==0.5.23  # Exact version pinned
```

**Benefits:**
- Prevents silent upgrades to compromised versions
- Reproducible builds
- Audit trail in git history

**Maintenance:**
```bash
# Audit for vulnerabilities
pip-audit -r requirements-parent.txt

# Update and test before committing
```

### Input Validation

All user-controllable inputs are validated using allowlist approach (fail closed):

| Input | Validation | Approach | Location |
|-------|------------|----------|----------|
| Branch names | `^[a-zA-Z0-9/_.-]+$` | Allowlist regex | aod.sh |
| Profile names | `^[a-zA-Z0-9-]+$` + explicit list | Allowlist | hal9000.sh |
| Project paths | `/home`, `/Users`, `/workspace`, `/tmp` prefixes | Allowlist | spawn-worker.sh |
| Worktree paths | Must be under `~/.aod/worktrees/` | Allowlist | aod.sh |

**Security principle:** All validations fail closed - if canonicalization fails or path doesn't match allowlist, the operation is rejected.

## Known Risks and Mitigations

### Docker Socket Access (Risk: HIGH)

**Risk:** The parent container has access to the Docker socket (`/var/run/docker.sock`), which provides host-level privileges.

**Impact:** A compromised parent container can:
- Create privileged containers
- Mount host filesystems
- Execute commands on the host

**Mitigations:**
1. Parent container is trusted infrastructure, not exposed to untrusted code
2. Workers spawned by parent are sandboxed (no socket access)
3. Image allowlist prevents arbitrary container creation
4. Input validation prevents command injection

**Recommendation:** Only run the parent container in trusted environments. Consider using Docker rootless mode for defense in depth.

### Network Namespace (Risk: MEDIUM)

**Network configuration depends on launcher:**

| Launcher | Network Mode | Description |
|----------|--------------|-------------|
| `aod.sh` | `--network host` | Direct host network access |
| `spawn-worker.sh` | `--network container:$PARENT` | Shares parent's network namespace |

**aod.sh (host network):**
- Container shares all host network interfaces
- Can access all host services on localhost
- No network isolation from host

**spawn-worker.sh (container network):**
- Worker shares parent container's network namespace
- Access to parent's services (e.g., ChromaDB on localhost:8000)
- Isolated from host network if parent uses bridge/custom network

**Mitigations:**
1. Containers run as non-root (cannot bind to privileged ports)
2. spawn-worker.sh workers inherit parent's network isolation

**Recommendation for production:** Configure parent with bridge networking:

```bash
# Create isolated network for parent
docker network create hal9000-net

# Launch parent with bridge network
docker run --network hal9000-net -p 8000:8000 ghcr.io/hellblazer/hal-9000:parent

# Workers automatically use parent's network namespace (isolated)
```

### Credential Management (Risk: MEDIUM)

**Risk:** API keys passed via environment variables are visible in `docker inspect`.

**Current state:**
- `ANTHROPIC_API_KEY` - Required for Claude CLI
- `CHROMADB_API_KEY` - Optional for ChromaDB cloud

**Mitigations:**
1. Security warnings logged when env vars used
2. Claude CLI supports authentication via `claude /login` command

**Recommendation:** Use Claude CLI's built-in authentication instead of environment variables:

```bash
# Inside container, authenticate interactively
claude /login

# Credentials stored in ~/.claude/ (mounted volume persists across sessions)
```

**Note:** The credential file approach (`~/.claude/.credentials.json`) is a Claude CLI feature. Check Claude CLI documentation for current authentication methods.

### Resource Exhaustion (Risk: LOW)

**Mitigations:**
- Memory limits: `--memory 4g`
- CPU limits: `--cpus 2`
- Process limits: `--pids-limit 100`

These can be adjusted via environment variables or disabled with `--no-limits`.

## Hook System Limitations

### Current Coverage

The hook system (`hooks.json`) provides guardrails for Bash commands but has limitations:

**Protected:**
- Bash tool - hooks can intercept and block commands

**Not Protected:**
- Read tool - file reading bypasses hooks
- Write tool - file writing bypasses hooks
- Edit tool - file editing bypasses hooks

**Impact:** Malicious or accidental operations via Read/Write/Edit tools cannot be intercepted.

### Hook Execution Context

Hooks run inside the Claude CLI process. In the hal-9000 architecture:
- **Parent container:** Hooks run if Claude CLI is used in parent
- **Worker containers:** Hooks run if hooks.json is included in worker image or mounted

To ensure hooks are active in workers, verify the worker image includes `/home/claude/.claude/hooks.json` or mount it via volume.

### Recommendations

1. **Awareness:** Hooks provide defense-in-depth, not complete protection
2. **Code Review:** Review Claude-generated code before execution
3. **Directory Restrictions:** Use project-level `.claude/` settings to restrict file access
4. **Future Enhancement:** Hook system could be extended to cover file operations

## Security Checklist

Before deploying hal-9000:

- [ ] Review and customize image allowlist for your environment
- [ ] Use Claude CLI authentication (`/login`) instead of environment variables
- [ ] Consider bridge networking for production deployments
- [ ] Set appropriate resource limits
- [ ] Run parent container only in trusted environments
- [ ] Keep Docker and hal-9000 images updated
- [ ] Monitor container logs for security warnings
- [ ] Verify your host UID matches container (1001) or build custom image

## Reporting Security Issues

If you discover a security vulnerability, please report it via GitHub Security Advisories rather than public issues.
