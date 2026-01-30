# HAL-9000 Security Documentation

This document describes the security model, known risks, and mitigations for the hal-9000 containerized Claude infrastructure.

## Security Architecture

### Non-Root Container Execution

Worker containers run as the `claude` user (UID 1000) rather than root:

```dockerfile
USER claude
```

**Benefits:**
- Limits damage from container escape vulnerabilities
- Follows principle of least privilege
- Volume permissions align with typical host user (UID 1000)

**Affected paths:**
- `/home/claude/.claude` - Claude configuration
- `/home/claude/memory-bank` - Memory Bank data
- `/workspace` - Project files

### Image Allowlisting

Worker images are validated against an allowlist to prevent supply chain attacks:

```bash
ALLOWED_IMAGES=(
    "ghcr.io/hellblazer/hal-9000:worker"
    "ghcr.io/hellblazer/hal-9000:base"
    "ghcr.io/hellblazer/hal-9000:python"
    "ghcr.io/hellblazer/hal-9000:node"
    "ghcr.io/hellblazer/hal-9000:java"
)
```

**Rationale:** Prevents arbitrary image execution that could contain malicious code.

### Input Validation

All user-controllable inputs are validated:

| Input | Validation | Location |
|-------|------------|----------|
| Branch names | `^[a-zA-Z0-9/_.-]+$` | aod.sh |
| Profile names | `^[a-zA-Z0-9-]+$` + allowlist | hal9000.sh |
| Project paths | No `..`, blocked system dirs | spawn-worker.sh |
| Worktree paths | Must be under `~/.aod/worktrees/` | aod.sh |

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

**Current:** Containers use `--network host` for simplicity.

**Risk:** Host network mode:
- Exposes all host network interfaces to container
- No network isolation between container and host services
- Container can bind to host ports

**Mitigations:**
1. Containers run as non-root (cannot bind to privileged ports)
2. Workers share parent's network namespace (not host's)

**Recommendation:** For production deployments, consider bridge networking:

```bash
# Create isolated network
docker network create hal9000-net

# Run with bridge network
docker run --network hal9000-net ...
```

**Trade-offs:**
- Bridge: Better isolation, requires explicit port mapping
- Host: Simpler localhost access to services like ChromaDB

### Credential Management (Risk: MEDIUM)

**Risk:** API keys passed via environment variables are visible in `docker inspect`.

**Current state:**
- `ANTHROPIC_API_KEY` - Required for Claude CLI
- `CHROMADB_API_KEY` - Optional for ChromaDB cloud

**Mitigations:**
1. Security warnings logged when env vars used
2. Credential files supported as alternative (`~/.claude/.credentials.json`)

**Recommendation:** Use credential files instead of environment variables:

```bash
# Store credentials in file (not visible in docker inspect)
echo '{"anthropic_api_key": "sk-..."}' > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
```

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

### Recommendations

1. **Awareness:** Hooks provide defense-in-depth, not complete protection
2. **Code Review:** Review Claude-generated code before execution
3. **Directory Restrictions:** Use project-level `.claude/` settings to restrict file access
4. **Future Enhancement:** Hook system could be extended to cover file operations

## Security Checklist

Before deploying hal-9000:

- [ ] Review and customize image allowlist for your environment
- [ ] Use credential files instead of environment variables
- [ ] Consider bridge networking for production
- [ ] Set appropriate resource limits
- [ ] Run parent container only in trusted environments
- [ ] Keep Docker and hal-9000 images updated
- [ ] Monitor container logs for security warnings

## Reporting Security Issues

If you discover a security vulnerability, please report it via GitHub Security Advisories rather than public issues.
