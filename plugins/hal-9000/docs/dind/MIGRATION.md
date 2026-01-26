# Migration Guide

## Overview

This guide covers migrating from claudy v0.5.x (single-container mode) to v0.6.x (DinD mode).

## What Changes

### Before (v0.5.x)
- Single container per session
- Each container runs its own services
- Data stored in host directories

### After (v0.6.x)
- Parent container manages workers
- Shared ChromaDB server
- Data stored in Docker volumes

## Migration Methods

### Method 1: Automatic Migration (Recommended)

```bash
# Dry run first (see what would happen)
./scripts/migrate-to-dind.sh --dry-run

# Run migration
./scripts/migrate-to-dind.sh
```

The migration script will:
1. Back up existing data (ChromaDB, Memory Bank, plugins)
2. Create named Docker volumes
3. Copy data into volumes
4. Start the DinD daemon
5. Verify the migration

### Method 2: Manual Migration

```bash
# 1. Stop any running claudy containers
docker ps --filter "name=claudy-" --format "{{.Names}}" | xargs docker stop

# 2. Create backup
BACKUP_DIR="$HOME/.hal9000-backup-$(date +%Y%m%d)"
cp -r ~/.hal9000 "$BACKUP_DIR"

# 3. Create Docker volumes
docker volume create hal9000-chromadb
docker volume create hal9000-memorybank
docker volume create hal9000-plugins

# 4. Copy data to volumes
docker run --rm \
    -v ~/.hal9000/chromadb:/source:ro \
    -v hal9000-chromadb:/dest \
    alpine cp -r /source/. /dest/

docker run --rm \
    -v ~/.hal9000/membank:/source:ro \
    -v hal9000-memorybank:/dest \
    alpine cp -r /source/. /dest/

# 5. Start DinD daemon
claudy daemon start

# 6. Verify
claudy daemon status
```

### Method 3: Fresh Start

If you don't need to preserve existing data:

```bash
# Remove old data
rm -rf ~/.hal9000/chromadb ~/.hal9000/membank

# Create fresh volumes
docker volume create hal9000-chromadb
docker volume create hal9000-memorybank
docker volume create hal9000-plugins

# Start daemon
claudy daemon start
```

## Using Legacy Mode

If you need to temporarily use the old single-container mode:

```bash
# Run in legacy mode
claudy --legacy /path/to/project
```

**Note**: `--legacy` mode is deprecated and will be removed in v1.0.

## Rollback

If migration fails, you can rollback:

```bash
# List available backups
./scripts/rollback-dind.sh --list-backups

# Rollback to v0.5.x mode
./scripts/rollback-dind.sh

# Keep volume data while rolling back
./scripts/rollback-dind.sh --keep-volumes
```

### Manual Rollback

```bash
# 1. Stop DinD daemon
claudy daemon stop

# 2. Restore backup
BACKUP_DIR="$HOME/.hal9000-backup-YYYYMMDD"  # Use your backup date
rm -rf ~/.hal9000
cp -r "$BACKUP_DIR" ~/.hal9000

# 3. Use legacy mode
claudy --legacy /path/to/project
```

## Data Migration Details

### ChromaDB Data

**v0.5.x Location**: `~/.hal9000/chromadb/`
**v0.6.x Location**: `hal9000-chromadb` Docker volume

The migration copies all ChromaDB collections and embeddings.

### Memory Bank Data

**v0.5.x Location**: `~/.hal9000/membank/`
**v0.6.x Location**: `hal9000-memorybank` Docker volume

All Memory Bank files are preserved.

### Session Data

**v0.5.x Location**: `~/.hal9000/sessions/`
**v0.6.x Location**: `~/.hal9000/sessions/` (unchanged)

Session metadata remains in the same location.

## Verification

After migration, verify everything works:

```bash
# 1. Check daemon status
claudy daemon status
# Should show: Container: running, ChromaDB: healthy

# 2. Test worker spawn
claudy --via-parent /tmp/test-project
# Should spawn worker successfully

# 3. Verify ChromaDB data
# Inside worker:
curl http://localhost:8000/api/v2/collections
# Should list your collections
```

## Troubleshooting Migration

### Migration Script Fails

```bash
# Check the migration log
cat ~/.hal9000/logs/migration.log

# Common issues:
# - Insufficient disk space
# - Docker daemon not running
# - Permission issues
```

### Data Not Visible After Migration

```bash
# Check volume contents
docker run --rm -v hal9000-chromadb:/data alpine ls -la /data

# If empty, re-run data copy
docker run --rm \
    -v ~/.hal9000-backup-YYYYMMDD/chromadb:/source:ro \
    -v hal9000-chromadb:/dest \
    alpine cp -r /source/. /dest/
```

### ChromaDB Won't Start

```bash
# Check logs
docker logs hal9000-parent 2>&1 | grep chromadb

# Common issues:
# - Corrupted data (restore from backup)
# - Port conflict (change CHROMADB_PORT)
# - Volume permissions
```

## Post-Migration Cleanup

After verifying the migration:

```bash
# Remove backup (optional, after confirming migration works)
rm -rf ~/.hal9000-backup-*

# Remove old data directories (optional)
rm -rf ~/.hal9000/chromadb ~/.hal9000/membank
```

## Migration FAQ

### Q: Can I use both modes simultaneously?
A: No, but you can switch between them by stopping the daemon and using `--legacy`.

### Q: Is the migration reversible?
A: Yes, if you keep the backup. Use the rollback script.

### Q: Will I lose any data?
A: No, the migration creates a backup first. Your original data is preserved.

### Q: How long does migration take?
A: Depends on data size. Typically 1-5 minutes for normal workloads.

### Q: Can I migrate individual sessions?
A: The migration is all-or-nothing for shared data (ChromaDB, Memory Bank).
