# Release Notes - v2.1.0

**Release Date:** February 1, 2026

## Overview

HAL-9000 v2.1.0 is a security-focused release implementing comprehensive defense-in-depth measures. This release hardens authentication, adds syscall filtering, introduces security audit logging, and strengthens supply chain protections.

## Breaking Changes

### ⚠️ Environment Variable API Keys Rejected

**What Changed:** API keys passed via environment variables (e.g., `ANTHROPIC_API_KEY`) are now **rejected** for security reasons.

**Why:** Environment variables are visible in `docker inspect` output and process listings, creating credential exposure risk.

**Migration Path:**

1. **Subscription Login (Recommended):**
   ```bash
   hal-9000 /login
   ```

2. **File-based Secrets:**
   ```bash
   mkdir -p ~/.hal9000/secrets
   echo "sk-ant-api03-..." > ~/.hal9000/secrets/anthropic_api_key
   chmod 600 ~/.hal9000/secrets/anthropic_api_key
   ```

3. **Docker Secrets (Production):**
   ```bash
   echo "sk-ant-api03-..." | docker secret create anthropic_api_key -
   ```

## New Features

### Phase 1: Authentication & Secrets

- **File-based secrets management** - Secure storage in `~/.hal9000/secrets/`
- **Docker secrets integration** - First-class support for Docker secret injection
- **Extended hook coverage** - Added protection for Grep, NotebookEdit, file_access operations
- **Symlink bypass protection** - All security hooks now resolve symlinks before validation

### Phase 2: Defense in Depth

- **Seccomp syscall filtering** - Blocks dangerous syscalls:
  - mount/umount (filesystem manipulation)
  - ptrace (process tracing/debugging)
  - kernel module loading (init_module, finit_module)
  - namespace manipulation (setns, unshare)
  - See [seccomp/README.md](plugins/hal-9000/seccomp/README.md) for full list

- **Per-user Docker volume isolation** - Prevents cross-user data access
- **Security audit logging** - Structured JSON logs for security events
- **API key hashing** - Credentials never appear in plaintext logs

### Phase 3: Supply Chain Hardening

- **SHA256 digest pinning** - All Docker base images pinned to specific digests
- **Signature verification** - Critical scripts verified before execution
- **Dependency integrity checks** - Hash validation for all dependencies
- **Provenance tracking** - Build artifact tracking for audit purposes

## Testing

- **139 integration tests** passing across 5 phases
- **CI runs on every push** to main branch
- **Security scanning** integrated into pipeline
- **Docker image build verification** in CI

## Documentation Updates

- Updated main README with v2.1.0 security features
- Updated SECURITY.md with credential management changes
- Added CHANGELOG entry for v2.1.0
- New seccomp profile documentation
- New security monitoring guide
- New base image digest documentation

## Upgrade Guide

1. **Update hal-9000:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Hellblazer/hal-9000/main/install-hal-9000.sh | bash
   ```

2. **Migrate from environment variable API keys:**
   ```bash
   # If you were using ANTHROPIC_API_KEY env var:
   mkdir -p ~/.hal9000/secrets
   echo "$ANTHROPIC_API_KEY" > ~/.hal9000/secrets/anthropic_api_key
   chmod 600 ~/.hal9000/secrets/anthropic_api_key
   unset ANTHROPIC_API_KEY
   ```

3. **Verify version:**
   ```bash
   hal-9000 --version
   # Should show: hal-9000 version 2.1.0
   ```

## Docker Images

All images available at `ghcr.io/hellblazer/hal-9000`:

| Profile | Tags | Description |
|---------|------|-------------|
| Base | `:latest`, `:2.1.0` | Claude CLI + MCP servers |
| Python | `:python`, `:python-2.1.0` | + Python 3.11, uv, pip |
| Node | `:node`, `:node-2.1.0` | + Node.js 20, npm, yarn, pnpm |
| Java | `:java`, `:java-2.1.0` | + GraalVM 25 LTS, Maven, Gradle |

## Full Changelog

See [CHANGELOG.md](plugins/hal-9000/CHANGELOG.md) for complete change history.

## Reporting Security Issues

Please report security vulnerabilities to the maintainers privately rather than opening public issues.
