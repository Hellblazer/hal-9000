## Base Image Digest Update Automation

Automated system for keeping Docker base image digests up to date.

## Overview

HAL-9000 pins all base images to specific SHA256 digests for security and reproducibility. This automation:
- Checks for newer versions of base images weekly
- Creates PRs with updated digests automatically
- Validates all changes before proposing updates

## Components

### 1. Update Script (`update-base-image-digests.sh`)

**Purpose**: Check and apply base image digest updates

**Usage**:
```bash
# Check if updates are available
./scripts/update-base-image-digests.sh --check

# See what would be updated (no changes)
./scripts/update-base-image-digests.sh --dry-run

# Apply updates to Dockerfiles
./scripts/update-base-image-digests.sh --update
```

**What it does**:
1. Pulls latest versions of all base images (debian, node, ubuntu, docker)
2. Extracts current digests from Dockerfiles
3. Compares current vs latest digests
4. Reports or applies updates

**Exit codes**:
- `0` - No updates or update successful
- `1` - Error occurred
- `2` - Updates available (check mode)

### 2. GitHub Actions Workflow (`.github/workflows/update-base-image-digests.yml`)

**Schedule**: Every Monday at 9:00 AM UTC

**Process**:
```
1. Checkout code
2. Check for digest updates (--check)
3. If updates available:
   a. Apply updates (--update)
   b. Validate new digests
   c. Create PR with changes
4. If no updates:
   a. Log success and exit
```

**PR Contents**:
- Changed Dockerfiles
- Digest before/after comparison
- Validation results
- Review checklist

**Labels**: `dependencies`, `security`, `automated`

### 3. Validation Script (`validate-base-image-digests.sh`)

**Purpose**: Verify all pinned digests are accessible

**Usage**:
```bash
cd plugins/hal-9000/docker
./validate-base-image-digests.sh
```

**What it does**:
1. Pulls each pinned digest by hash
2. Verifies image is accessible
3. Reports validation status

**Used by**:
- GitHub Actions workflow (automated validation)
- Manual updates (pre-commit validation)
- CI/CD pipeline (build verification)

## Workflow

### Automated Weekly Update

Every Monday:
1. GitHub Actions runs workflow
2. Script checks for updates
3. If updates found:
   - Updates Dockerfiles
   - Validates digests
   - Creates PR
4. Team reviews and merges PR

### Manual Update

When you need to update immediately:

```bash
# 1. Check for updates
scripts/update-base-image-digests.sh --check

# 2. Preview changes
scripts/update-base-image-digests.sh --dry-run

# 3. Apply updates
scripts/update-base-image-digests.sh --update

# 4. Validate
cd plugins/hal-9000/docker
./validate-base-image-digests.sh

# 5. Review changes
git diff plugins/hal-9000/docker/Dockerfile*

# 6. Commit
git add -A
git commit -m "chore: Update base image digests"
```

### Manual Workflow Trigger

From GitHub web interface:

1. Navigate to **Actions** tab
2. Select **Update Base Image Digests** workflow
3. Click **Run workflow**
4. Select branch (usually `main`)
5. Click **Run workflow** button

This creates a PR if updates are available.

## Monitored Images

| Image | Tag | Registry | Update Frequency |
|-------|-----|----------|------------------|
| debian | bookworm-slim | Docker Hub | Weekly automated |
| node | 20-bookworm-slim | Docker Hub | Weekly automated |
| ubuntu | 24.04 | Docker Hub | Weekly automated |
| docker | 27-dind | Docker Hub | Weekly automated |

## Security Considerations

### Digest Pinning Benefits

- **Immutability**: Digest references can't be changed
- **Supply Chain Protection**: Prevents tag overwrites
- **Reproducible Builds**: Same digest = same image
- **Audit Trail**: Clear history of when images were updated

### Update Review Process

Before merging automated PRs:

1. **Review diff**: Check which digests changed
2. **Check upstream**: Review base image release notes
3. **Breaking changes**: Look for incompatibilities
4. **Security**: Check if update addresses CVEs
5. **Test builds**: Verify images build successfully
6. **Test functionality**: Ensure Claude CLI still works

### Emergency Updates

For critical security vulnerabilities:

1. **Immediate**: Run manual trigger from GitHub Actions
2. **Expedited review**: Fast-track PR review
3. **Deploy**: Rebuild and push images immediately
4. **Notify**: Alert users of security update

## Troubleshooting

### Updates Not Detected

**Symptom**: Workflow says "No updates available" but you know there are

**Solutions**:
- Image may not be published to registry yet
- Digest may be cached locally
- Clear Docker cache: `docker system prune -a`
- Manually pull: `docker pull debian:bookworm-slim --platform linux/amd64`

### PR Creation Failed

**Symptom**: Workflow succeeds but no PR created

**Solutions**:
- Check GitHub token permissions (needs `pull-requests: write`)
- Verify peter-evans/create-pull-request action version
- Check for existing PR with same branch name
- Review workflow logs for errors

### Validation Failures

**Symptom**: `validate-base-image-digests.sh` fails

**Solutions**:
- Check network connectivity
- Verify Docker daemon is running
- Check if digest was revoked by upstream
- Try pulling manually: `docker pull IMAGE@DIGEST`

## Maintenance

### Adding New Base Images

1. Update `update-base-image-digests.sh`:
   ```bash
   check_base_image "new-image" "tag"
   ```

2. Update `validate-base-image-digests.sh`:
   ```bash
   test_digest "new-image" "sha256:xxx..." "new-image:tag"
   ```

3. Update `BASE_IMAGE_DIGESTS.md` table

### Changing Update Schedule

Edit `.github/workflows/update-base-image-digests.yml`:

```yaml
schedule:
  # Change from weekly to daily
  - cron: '0 9 * * *'  # Daily at 9 AM UTC
```

## References

- [Docker Image Manifest Spec](https://docs.docker.com/registry/spec/manifest-v2-2/)
- [GitHub Actions Scheduled Events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
- [Supply Chain Security Best Practices](https://slsa.dev/)
- Related: `hal-9000-dot` (Pin base image digests)
- Related: `hal-9000-h4i` (Create digest update automation)
