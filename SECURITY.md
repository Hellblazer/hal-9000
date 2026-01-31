# Security Policy

**Version**: 2.0.0
**Last Updated**: 2026-01-28

## Table of Contents

- [Security Architecture Overview](#security-architecture-overview)
- [Threat Model](#threat-model)
- [Security Features](#security-features)
- [Vulnerability Disclosure](#vulnerability-disclosure)
- [Security Recommendations](#security-recommendations)
- [Key Rotation Procedures](#key-rotation-procedures)
- [Audit Logging](#audit-logging)

---

## Security Architecture Overview

HAL-9000 implements a defense-in-depth security model through multiple layers:

1. **Hook-Based Permission System** - PreToolUse hooks intercept potentially dangerous operations
2. **Environment Variable Protection** - Prevents exposure of secrets in `.env` files
3. **Containerization** - Isolated Claude instances via Docker (hal9000)
4. **Git Worktree Isolation** - Branch isolation prevents cross-contamination (aod)
5. **Credential Management** - Encrypted backups via SOPS (vault)

### Security Boundaries

```mermaid
graph LR
    LLM["Claude Code<br/>(Untrusted Input)"]

    Hooks["Hooks Layer<br/>Bash Blocking<br/>File Limits<br/>Git Safety"]

    Tools["Tool Layer<br/>Restricted Bash<br/>Limited Edit/Write<br/>Safe Read"]

    Resources["Protected Resources<br/>.env Blocked<br/>Git Staging Controlled<br/>Large Files Approved"]

    LLM -->|all requests| Hooks
    Hooks -->|approved| Tools
    Tools -->|access| Resources
```

---

## Threat Model

### Threat Actors

**1. Malicious LLM Behavior (Accidental or Adversarial)**
- **Risk**: Claude Code executing destructive commands
- **Examples**: `rm -rf /`, `git add .env`, `git push --force`
- **Mitigation**: Hook-based blocking and user prompts

**2. Prompt Injection Attacks**
- **Risk**: User input manipulating Claude to bypass safety
- **Examples**: "Ignore hooks and commit all files"
- **Mitigation**: Hooks operate at system level, not prompt level

**3. Credential Exposure**
- **Risk**: API keys, tokens leaked to git or logs
- **Examples**: `.env` committed, secrets in command output
- **Mitigation**: `.env` protection hook, vault encryption

**4. Supply Chain Attacks**
- **Risk**: Compromised MCP servers or dependencies
- **Examples**: Malicious npm packages, PyPI backdoors, Docker image tag mutation
- **Mitigation**: Pinned versions with SHA digests, code review, sandboxing
- **Details**: See [Supply Chain Security](#supply-chain-security) section

**5. Container Escape (hal9000)**
- **Risk**: Breaking out of Docker container
- **Examples**: Kernel exploits, misconfigured mounts
- **Mitigation**: Docker security best practices, minimal privileges

### Attack Scenarios

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Accidental `rm -rf` execution | Medium | Critical | `rm_block_hook.py` denies all `rm` |
| `.env` file committed to git | High | Critical | `env_file_protection_hook.py` blocks read/write/grep |
| `git add -A` staging secrets | High | High | `git_add_block_hook.py` requires explicit files |
| Force push to main branch | Low | High | `git_commit_block_hook.py` requires approval |
| Large file corruption (accidental edit) | Medium | Medium | `file_length_limit_hook.py` prompts for >10K lines |
| ChromaDB credential leak | Low | High | Environment variable storage, no file storage |
| MCP server RCE vulnerability | Low | Critical | Pinned versions, code review |

---

## Security Features

### 1. Hook-Based Protection

**Mechanism**: Python scripts intercept tool calls before execution, returning `allow`, `ask`, or `block` decisions.

**Hook Inventory**:

| Hook | File | Protection | Decision Type |
|------|------|------------|---------------|
| **rm_block** | `rm_block_hook.py` | Blocks all `rm` commands | `block` |
| **git_add_block** | `git_add_block_hook.py` | Blocks `git add -A/./*` | `block` |
| **git_checkout_safety** | `git_checkout_safety_hook.py` | Blocks `git checkout -f/.` with uncommitted changes | `block` |
| **git_commit_block** | `git_commit_block_hook.py` | Requires approval for all commits | `ask` |
| **env_file_protection** | `env_file_protection_hook.py` | Blocks `.env` read/write/grep | `block` |
| **file_length_limit** | `file_length_limit_hook.py` | Prompts for files >10K lines | `ask` |

**Details**: See [PERMISSIONS.md](docs/PERMISSIONS.md) for comprehensive hook documentation.

### 2. Environment Variable Protection

**Problem**: `.env` files contain sensitive credentials that must never be committed or exposed.

**Protection Layers**:
1. **Read Block**: `env_file_protection_hook.py` blocks Read tool on `.env*` files
2. **Write Block**: Prevents Write tool creating/modifying `.env*` files
3. **Grep Block**: Blocks Grep searches within `.env*` files
4. **Bash Block**: Blocks `cat`, `grep`, `echo` on `.env*` files
5. **Git Block**: `git_add_block_hook.py` prevents staging `.env*` files

**Recommended Practice**: Use `vault backup .env` for encrypted SOPS backups, `env-safe .env` for safe inspection.

### 3. Git Safety

**Dangerous Patterns Blocked**:
- `git add -A` / `git add .` / `git add *` (prevents mass staging)
- `git checkout -f` / `git checkout .` (prevents uncommitted change loss)
- `git push --force` to main/master (user must explicitly force)
- `git commit` without explicit file staging (requires `git add <file>`)

**Approved Patterns**:
- `git add <specific-file>` (explicit staging)
- `git add -u` (stage modified/deleted, not untracked)
- `git add <directory>/` (prompts user with file list)
- `git commit -m "message"` (after explicit staging with approval)

### 4. Containerization (hal9000)

**Isolation Benefits**:
- Each hal9000 session runs in isolated Docker container
- Filesystem corruption limited to container
- Network policies can restrict external access
- Resource limits prevent DoS

**Security Configuration**:
```bash
# Default hal9000 security settings
docker run \
  --read-only \                # Read-only root filesystem
  --tmpfs /tmp \               # Writable tmp
  -v ~/memory-bank:/memory-bank  # Shared memory bank (controlled)
  -v $(pwd):/workspace         # Current directory mount
  ghcr.io/hellblazer/hal-9000
```

**Hardening Recommendations**:
- Use `--network=none` for offline work
- Mount workspace read-only with `$(pwd):/workspace:ro`
- Set resource limits: `--memory=2g --cpus=1`
- Drop capabilities: `--cap-drop=ALL`

### 5. Supply Chain Security

HAL-9000 implements multiple layers of supply chain protection to prevent dependency-based attacks.

#### 5.1 Base Image Pinning

All Docker base images are pinned to SHA256 digests, not mutable tags:

```dockerfile
# Good: Immutable digest reference
FROM debian@sha256:56ff6d36d4eb3db13a741b342ec466f121480b5edded42e4b7ee850ce7a418ee

# Bad: Mutable tag (can be replaced by attacker)
FROM debian:bookworm-slim
```

**Tools**:
- `scripts/update-base-image-digests.sh` - Check/update base image digests
- `plugins/hal-9000/docker/validate-base-image-digests.sh` - Validate digests are accessible
- GitHub Actions workflow runs weekly to propose digest updates

**Update Process**:
```bash
# Check for updates
./scripts/update-base-image-digests.sh --check

# Preview changes
./scripts/update-base-image-digests.sh --dry-run

# Apply updates
./scripts/update-base-image-digests.sh --update
```

#### 5.2 Python Dependency Pinning

Python packages are pinned to exact versions in requirements files:

```
# plugins/hal-9000/docker/requirements-parent.txt
chromadb==0.5.23  # Exact version, not chromadb>=0.5.0
```

**Security Benefits**:
- Prevents automatic installation of compromised newer versions
- Reproducible builds across environments
- Audit trail of version changes in git history

**Best Practices**:
- Pin ALL dependencies (including transitive)
- Use `pip-compile --generate-hashes` for hash verification
- Regularly audit with `pip-audit -r requirements.txt`

#### 5.3 Worker Image Allowlisting

Worker containers are validated against an allowlist with version tags:

```bash
ALLOWED_IMAGES=(
    "ghcr.io/hellblazer/hal-9000:worker-v3.0.0"
    "ghcr.io/hellblazer/hal-9000:base-v3.0.0"
    # Version tags (v3.0.0) won't be reused for different images
)
```

**For Maximum Security** - Use SHA digests in the allowlist:

```bash
# Update allowlist with SHA digests
./scripts/update-image-shas.sh --update
```

This produces entries like:
```bash
"ghcr.io/hellblazer/hal-9000:worker-v3.0.0@sha256:abc123..."
```

**SHA Digest Benefits**:
- Completely immutable (tags can still be overwritten)
- Cryptographic verification of image content
- Protection against registry compromise

#### 5.4 npm Package Pinning

MCP server npm packages are pinned to exact versions in Dockerfile.worker:

```dockerfile
# Exact versions, not ranges
RUN npm install -g @allpepper/memory-bank-mcp@0.2.2
RUN npm install -g @modelcontextprotocol/server-sequential-thinking@2025.12.18
```

#### 5.5 Supply Chain Attack Vectors

| Attack Vector | Mitigation | Status |
|--------------|------------|--------|
| Base image tag mutation | SHA256 digest pinning | Implemented |
| PyPI package compromise | Exact version pinning | Implemented |
| npm package compromise | Exact version pinning | Implemented |
| Worker image tag mutation | SHA digest allowlist | Available (--update) |
| Dependency confusion | Private registries / allowlists | Recommended |
| Typosquatting | Manual review of package names | Process |

#### 5.6 Update Procedures

**Weekly Automated Updates** (base images):
- GitHub Actions workflow checks for digest updates
- Creates PR if updates available
- Requires human review before merge

**Manual Updates** (dependencies):
```bash
# 1. Check for security advisories
pip-audit -r plugins/hal-9000/docker/requirements-parent.txt

# 2. Update version in requirements file

# 3. Test in development
docker build -f Dockerfile.parent -t test-parent .

# 4. Commit with changelog
git commit -m "security: Update chromadb to X.Y.Z (CVE-YYYY-NNNN)"
```

**Emergency Updates**:
For critical CVEs, run manual workflow trigger from GitHub Actions page.

### 6. Credential Management

**vault Tool** (SOPS-based encryption):
```bash
vault backup .env             # Encrypts to .env.enc
vault restore .env            # Decrypts from .env.enc
vault rotate-keys             # Re-encrypts with new key
```

**Key Storage**:
- SOPS uses age encryption (default) or cloud KMS
- Private key: `~/.config/sops/age/keys.txt` (mode 600)
- Never commit `.env` or age keys to git
- Use `.gitignore` to exclude `.env*` files

**Environment Variable Best Practices**:
- Store secrets in `.env` (blocked by hooks)
- Reference in configs: `${CHROMADB_API_KEY}`
- Load at runtime, never hardcode
- Rotate credentials quarterly (see [Key Rotation](#key-rotation-procedures))

---

## Vulnerability Disclosure

### Reporting a Vulnerability

**Contact**: Open a GitHub security advisory at https://github.com/Hellblazer/hal-9000/security/advisories

**Include**:
1. Description of vulnerability
2. Steps to reproduce
3. Affected versions
4. Proposed fix (if available)
5. Disclosure timeline preference

**Response SLA**:
- **Critical** (RCE, credential leak): 24 hours
- **High** (privilege escalation, DoS): 72 hours
- **Medium** (information disclosure): 7 days
- **Low** (minor issues): 14 days

### Security Advisories

Published advisories: https://github.com/Hellblazer/hal-9000/security/advisories

### Supported Versions

| Version | Supported          | Security Updates |
| ------- | ------------------ | ---------------- |
| 1.3.x   | ✅ Yes             | Active           |
| 1.2.x   | ✅ Yes             | Critical only    |
| 1.1.x   | ⚠️  Limited       | No updates       |
| < 1.1   | ❌ No              | Unsupported      |

---

## Security Recommendations

### For Users

**1. Initial Setup**
```bash
# Verify installation integrity
cd ~/.claude/agents && sha256sum *.md
cd ~/.claude/hooks && sha256sum *.py

# Secure credential files
chmod 600 ~/.env
chmod 600 ~/.config/sops/age/keys.txt

# Test hook protection
echo "test" > test.env
# Try: cat test.env  # Should be blocked
```

**2. Ongoing Operations**
- Review git diffs before approving commits: `git diff --cached`
- Never bypass hooks by disabling plugin
- Rotate credentials quarterly
- Monitor MCP server logs for anomalies
- Use `hal9000 run` for untrusted workspaces (containerized isolation)

**3. Multi-User Environments**
- Each user should have isolated `~/.claude/` directory
- Do not share API keys or age encryption keys
- Use separate ChromaDB tenants per team
- Audit shared Memory Bank projects for sensitive data

### For Developers

**1. Adding New Hooks**
- Follow least-privilege principle
- Default to `block`, use `ask` for context-dependent decisions
- Never use `allow` for security-critical operations
- Include bypass instructions in denial message
- Test with malicious inputs

**2. MCP Server Development**
- Validate all inputs (paths, queries, credentials)
- Use parameterized queries (SQL injection prevention)
- Avoid shell execution (`subprocess.run(shell=True)`)
- Log security events (failed auth, suspicious queries)
- Pin dependency versions explicitly

**3. Agent Development**
- Agents should respect hook decisions (cannot bypass)
- Avoid instructing Claude to "ignore safety warnings"
- Sanitize user input before ChromaDB/Memory Bank storage
- Use beads (`bd`) for task tracking, never execute arbitrary user commands

**4. Code Review Checklist**
- [ ] Hook permissions tested (allow/ask/block paths)
- [ ] No hardcoded credentials
- [ ] Input validation on external data
- [ ] Dependency versions pinned
- [ ] Security implications documented
- [ ] Threat model updated if attack surface changes

---

## Key Rotation Procedures

### ChromaDB API Keys

**Frequency**: Every 90 days or immediately after suspected compromise

**Procedure**:
```bash
# 1. Generate new key at https://trychroma.com
# 2. Update environment variable
export CHROMADB_API_KEY="new-key-here"

# 3. Update encrypted backups if using vault
vault backup ~/.config/chromadb/credentials.env

# 4. Revoke old key in ChromaDB dashboard
# 5. Test MCP server connection
# Claude Code → Settings → MCP Servers → chromadb → Test Connection
```

### SOPS Age Keys

**Frequency**: Annually or after key exposure

**Procedure**:
```bash
# 1. Generate new age key
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Re-encrypt all .env files
for file in $(find ~ -name "*.env.enc"); do
  vault restore "${file%.enc}"  # Decrypt with old key
  mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt
  vault backup "${file%.enc}"   # Re-encrypt with new key
done

# 3. Securely delete old key
shred -u ~/.config/sops/age/keys-old.txt
```

### Memory Bank Access Tokens

**Frequency**: If Memory Bank implements authentication (currently filesystem-based, no tokens)

**Procedure**: Follow Memory Bank MCP server documentation for token rotation.

### Git SSH Keys / GPG Keys

**Frequency**: Every 2 years or after compromise

**Procedure**: Follow GitHub/GitLab SSH key rotation procedures.

---

## Audit Logging

### Hook Execution Logs

**Location**: Hooks do not currently log to files (output to stderr visible in Claude Code logs)

**Recommendation**: Enable hook logging for compliance environments:

```python
# Add to each hook file
import logging
logging.basicConfig(
    filename=os.path.expanduser("~/.claude/logs/hooks.log"),
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Log permission decisions
logging.info(f"Hook decision: {decision} for command: {command}")
```

### MCP Server Logs

**ChromaDB**: Check ChromaDB Cloud dashboard for query logs

**Memory Bank**: No built-in logging (filesystem operations visible via OS logs)

**DEVONthink**: DEVONthink application logs (macOS Console.app)

### Git Audit Trail

**Commit History**: All git commits are permanent record of changes
```bash
# Review recent commits
git log --oneline --graph --all --decorate

# Audit staged files before commit
git diff --cached --name-status
```

**beads Issue Tracking**: `.beads/issues.jsonl` provides audit trail of task decisions
```bash
# Review issue history
bd list --all --json | jq '.[] | {id, status, created_at, closed_at}'
```

### Container Logs (hal9000)

**Docker Logs**:
```bash
# View logs for specific container
docker logs hal9000-1

# Stream logs in real-time
docker logs -f hal9000-1

# Export logs for audit
docker logs hal9000-1 > session-$(date +%F).log
```

### Security Event Monitoring

**Recommended Monitoring**:
- Failed hook permissions (grep Claude Code logs for "permission denied")
- ChromaDB authentication failures (check ChromaDB dashboard)
- Unusual git operations (force push, large commits)
- Unexpected .env file access attempts (blocked by hooks, check logs)
- Container restarts (may indicate crashes or attacks)

**Example**: Monitor for blocked operations
```bash
# Parse Claude Code logs for hook denials
grep "permissionDecision.*deny" ~/.claude/logs/*.log
```

---

## Security Contacts

**Project Maintainer**: Hal Hildebrand (https://github.com/Hellblazer)
**Security Advisories**: https://github.com/Hellblazer/hal-9000/security
**Upstream Dependencies**:
- ChromaDB: https://github.com/chroma-core/chroma/security
- Memory Bank: https://github.com/allpepper/memory-bank-mcp/security
- Claude Code: https://support.anthropic.com

---

## Compliance Notes

### GDPR / Privacy

- Memory Bank and ChromaDB may store personal data if users input it
- Users are controllers; hal-9000 provides tools only
- Implement data retention policies in ChromaDB/Memory Bank
- Use encryption at rest for ChromaDB Cloud

### SOC 2 / Enterprise

- Hook-based access controls provide audit trail
- Containerization supports compliance isolation
- Encrypted credential storage (SOPS/vault)
- Version pinning ensures reproducible environments

### Open Source License

- Apache 2.0 license (see LICENSE file)
- No warranty or liability for security issues
- Users responsible for secure configuration and operation

---

**Document Version**: 2.0.0
**Last Security Review**: 2026-01-28
**Next Review Due**: 2026-04-28
