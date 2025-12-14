# ClaudeBox Squad

Multi-branch parallel development using ClaudeBox containers with git worktrees and tmux sessions.

## Overview

ClaudeBox Squad orchestrates multiple isolated development environments simultaneously. Each environment consists of a git worktree, tmux session, and ClaudeBox container. This enables working on different branches in parallel without switching contexts or losing state.

The integration bridges ClaudeBox containerized development with claude-squad's multi-session workflow. Each branch runs in complete isolation with its own container, filesystem state, and terminal session.

## Architecture

```
claudebox-squad (Orchestrator)
    │
    ├── Branch: feature/auth
    │   └── Worktree → tmux session → ClaudeBox (Python, Slot 1)
    │
    ├── Branch: feature/api
    │   └── Worktree → tmux session → ClaudeBox (Node, Slot 2)
    │
    ├── Branch: bugfix/validation
    │   └── Worktree → tmux session → ClaudeBox (Python, Slot 3)
    │
    └── Branch: feature/frontend
        └── Worktree → tmux session → ClaudeBox (Node, Slot 4)
```

**Components:**
- **Git Worktrees** - Independent checkouts sharing one .git directory
- **Tmux Sessions** - Persistent terminals that survive disconnections
- **ClaudeBox Containers** - Isolated Docker environments with language profiles
- **Slot System** - Auto-assigned unique identifiers preventing port conflicts

## Prerequisites

- ClaudeBox installed and working (`claudebox run` succeeds)
- git (version control)
- tmux (terminal multiplexer)
- docker (container runtime)

The hal-9000 installer adds ClaudeBox Squad scripts to PATH automatically.

## Quick Start

### 1. Create Configuration

Create a `squad.conf` file defining branches and tasks:

```conf
# Format: branch:profile:description
feature/auth:python:Add OAuth2 authentication
feature/api:node:Build REST API endpoints
bugfix/validation:python:Fix input validation
```

Copy the example to start:
```bash
cp squad.conf.example squad.conf
```

### 2. Launch Sessions

```bash
claudebox-squad squad.conf
```

This creates:
- Git worktrees in `~/.claudebox-squad/worktrees/`
- Tmux sessions named `squad-{branch}`
- ClaudeBox containers with unique slot numbers
- Session metadata in `~/.claudebox-squad/sessions.log`

### 3. Work with Sessions

**List active sessions:**
```bash
cs-list
```

**Attach to specific session:**
```bash
cs-attach squad-feature-auth
```

Detach with `Ctrl+B` then `D`.

**Stop single session:**
```bash
cs-stop squad-feature-auth
```

**Cleanup everything:**
```bash
cs-cleanup
```

Cleanup removes all sessions, containers, worktrees, and state.

## Configuration Format

`squad.conf` uses colon-separated fields:

```
branch:profile:description
```

| Field | Required | Description |
|-------|----------|-------------|
| `branch` | Yes | Git branch name (created from HEAD if missing) |
| `profile` | No | ClaudeBox profile(s), comma-separated |
| `description` | No | Task description for reference |

### Examples

```conf
# Branch only (uses default profile)
feature/quick-fix::

# Branch with profile
feature/api:node:

# Full specification
feature/auth:python:Add OAuth2 authentication system

# Multiple profiles
feature/fullstack:python,node:Full-stack feature

# Comments and blank lines ignored
```

## How It Works

### Git Worktrees

Git worktrees allow multiple branches checked out simultaneously. Each worktree is an independent working directory sharing the `.git` database.

Location: `~/.claudebox-squad/worktrees/`

```
~/.claudebox-squad/worktrees/
├── myproject-feature-auth/      # feature/auth branch
├── myproject-feature-api/       # feature/api branch
└── myproject-bugfix-validation/ # bugfix/validation branch
```

Changes in one worktree don't affect others. Each has its own uncommitted changes, build artifacts, and file state.

### Tmux Sessions

Each worktree runs in a tmux session for persistent access.

Session naming: `squad-{branch-name-with-slashes-replaced}`

```bash
tmux list-sessions
# squad-feature-auth: 1 windows
# squad-feature-api: 1 windows
# squad-bugfix-validation: 1 windows
```

Sessions persist across terminal disconnections. Attach and detach freely without losing state.

### ClaudeBox Containers

Each session runs a ClaudeBox container with:
- Auto-assigned slot number (prevents port conflicts)
- Specified language profile (python, node, etc.)
- Isolated filesystem and network
- Unique container name

```bash
docker ps
# claudebox-myproject-abc123-slot1  # feature/auth
# claudebox-myproject-def456-slot2  # feature/api
# claudebox-myproject-ghi789-slot3  # bugfix/validation
```

Containers share the host's `~/.claudebox/hal-9000` directory for MCP servers and agents.

### State Tracking

Session metadata stored as JSON in `~/.claudebox-squad/sessions.log`:

```json
{
  "session": "squad-feature-auth",
  "branch": "feature/auth",
  "worktree": "/home/user/.claudebox-squad/worktrees/myproject-feature-auth",
  "slot": 1,
  "profile": "python",
  "created": "2025-12-13T10:30:00-0800"
}
```

Used by cs-list and cs-cleanup to track active sessions.

## Command Reference

### claudebox-squad

Launch sessions from configuration file.

```bash
claudebox-squad [config_file]

# Uses squad.conf by default
claudebox-squad

# Custom config file
claudebox-squad my-tasks.conf
```

Creates worktrees, tmux sessions, and containers. Skips existing sessions.

### cs-list

List all active squad sessions and containers.

```bash
cs-list
```

Output shows:
- Tmux sessions and status
- Running containers
- Available commands

### cs-attach

Attach to specific session.

```bash
cs-attach <session-name>

# Example
cs-attach squad-feature-auth
```

Enters the tmux session. Detach with `Ctrl+B` then `D`.

### cs-stop

Stop specific session, keep worktree.

```bash
cs-stop <session-name>

# Example
cs-stop squad-feature-auth
```

Kills tmux session and container. Worktree remains for manual inspection or later use.

### cs-cleanup

Stop all sessions and remove all worktrees.

```bash
cs-cleanup
```

Prompts for confirmation before:
- Killing all squad tmux sessions
- Removing all ClaudeBox containers
- Removing all git worktrees
- Cleaning state directory

Destructive operation. Use cs-stop for selective cleanup.

## Use Cases

### Parallel Feature Development

```conf
feature/user-auth:python:Implement user authentication
feature/payment:node:Add payment processing
feature/notifications:python:Build notification system
```

Work on multiple features simultaneously. Each in isolated environment with appropriate tooling.

### Code Review

```conf
review/pr-123:python:Review authentication PR
review/pr-124:node:Review API changes PR
review/pr-125:python:Review database migration PR
```

Launch multiple PRs for review. Switch between them without losing context or checkout state.

### Bug Triage

```conf
P0/crash-on-login:python:Critical login crash
P0/data-corruption:python:Critical data loss bug
P1/slow-query:python:Performance issue
P1/ui-glitch:node:UI rendering problem
```

Investigate multiple bugs in parallel. Prioritize by switching sessions rather than branches.

### Experimentation

```conf
experiment/approach-a:python:Try SQLAlchemy ORM
experiment/approach-b:python:Try raw SQL queries
experiment/approach-c:python:Try async DB driver
```

Test different approaches simultaneously. Compare results without destroying previous work.

### Refactoring

```conf
refactor/models:python:Refactor database models
refactor/views:python:Refactor API views
refactor/tests:python:Update test suite
refactor/docs::Update documentation
```

Large refactoring split into parallel tracks. Each progresses independently.

## Best Practices

### Descriptive Branch Names

Use clear, hierarchical branch names:

```conf
# Good
feature/oauth2-authentication:python:Add OAuth2 support
bugfix/null-pointer-login:python:Fix NPE in login handler

# Avoid
feat1::
fix::
temp::
```

Branch names become session names and container identifiers.

### Match Profiles to Tasks

```conf
# Backend work
api/endpoints:python:

# Frontend work
ui/components:node:

# Full-stack
feature/end-to-end:python,node:

# No profile needed for docs
docs/api-reference::
```

Profiles install language tooling. Omit when not needed.

### Session Management

Check status frequently:
```bash
cs-list
```

Stop unused sessions to free resources:
```bash
cs-stop squad-feature-name
```

Full cleanup when switching contexts:
```bash
cs-cleanup
```

### Commit Frequently

Each worktree is independent. Commit often to avoid losing work:

```bash
# In each tmux session
git add .
git commit -m "WIP: incremental progress"
```

Commits are shared across worktrees (same repository). Pushes update all worktrees on fetch.

### Resource Management

Monitor container resource usage:

```bash
docker stats --filter "name=claudebox"
```

Reasonable limits (16GB RAM machine):
- 3-4 concurrent sessions for active development
- More possible if sessions idle
- Adjust based on container profile complexity

## Troubleshooting

### Worktree Already Exists

**Error:** "fatal: 'path' already exists"

**Cause:** Previous session not cleaned up, or manual worktree creation.

**Solution:**
```bash
# List existing worktrees
git worktree list

# Remove specific worktree
git worktree remove ~/.claudebox-squad/worktrees/myproject-feature-auth --force

# Or cleanup everything
cs-cleanup
```

### Session Already Exists

**Error:** "duplicate session: squad-feature-auth"

**Cause:** Tmux session wasn't terminated properly.

**Solution:**
```bash
# List sessions
tmux ls

# Kill specific session
tmux kill-session -t squad-feature-auth

# Or cleanup everything
cs-cleanup
```

### Slot Number Conflict

**Error:** Container port conflict or slot already assigned.

**Cause:** ClaudeBox container from previous session still running.

**Solution:**
```bash
# List containers
docker ps --filter "name=claudebox"

# Force remove container
docker rm -f <container-name>

# Or cleanup everything
cs-cleanup
```

### Branch Doesn't Exist

**Behavior:** Script creates branch from current HEAD.

**To create from different base:**
```bash
# Create branch manually first
git branch feature/my-feature origin/develop

# Then launch squad
claudebox-squad
```

### Worktree Won't Remove

**Error:** "fatal: 'path' contains modified or untracked files"

**Solution:**
```bash
# Prune stale worktree references
git worktree prune

# Force remove directory
rm -rf ~/.claudebox-squad/worktrees/myproject-feature-auth

# Cleanup git's worktree tracking
git worktree prune
```

### Containers Not Stopping

**Problem:** ClaudeBox containers persist after killing tmux session.

**Solution:**
```bash
# Force remove all ClaudeBox containers
docker ps -a --filter "name=claudebox" -q | xargs docker rm -f

# Or use cleanup script
cs-cleanup
```

### Lock File Error

**Error:** "Another instance is already running"

**Cause:** Previous claudebox-squad execution crashed without cleanup.

**Solution:**
```bash
# Remove lock directory
rmdir ~/.claudebox-squad/.lock

# Or full cleanup
cs-cleanup
```

## Advanced Usage

### Tmux Navigation

Switch between sessions without cs-attach:

```bash
# List sessions
tmux ls

# Attach to session
tmux attach -t squad-feature-auth

# Switch sessions while attached
# Ctrl+B then (    # Previous session
# Ctrl+B then )    # Next session

# Detach
# Ctrl+B then D
```

### Container Inspection

Access container directly:

```bash
# List containers
docker ps --filter "name=claudebox"

# Execute command in container
docker exec -it <container-name> bash

# View container logs
docker logs <container-name>

# Check resource usage
docker stats <container-name>
```

### Manual Worktree Management

Create worktrees outside squad:

```bash
# Create worktree manually
git worktree add -b feature/manual ~/.claudebox-squad/worktrees/manual-feature

# List all worktrees
git worktree list

# Remove worktree
git worktree remove ~/.claudebox-squad/worktrees/manual-feature
```

### Multiple Profiles

Comma-separated profiles install multiple language environments:

```conf
# Both Python and Node available
feature/fullstack:python,node:Full-stack development

# All available profiles
feature/polyglot:python,node,rust,go:Multi-language feature
```

Container includes tooling for all specified profiles.

## Workflow Example

Complete workflow from start to finish:

```bash
# 1. Define tasks
cat > squad.conf <<EOF
feature/auth:python:Add authentication
feature/api:node:Build REST API
bugfix/validation:python:Fix validation
EOF

# 2. Launch all sessions
claudebox-squad squad.conf

# 3. Verify sessions created
cs-list

# 4. Work on authentication
cs-attach squad-feature-auth
# ... implement auth ...
git add . && git commit -m "Add OAuth2 flow"
# Ctrl+B, D to detach

# 5. Switch to API work
cs-attach squad-feature-api
# ... implement endpoints ...
git add . && git commit -m "Add user endpoints"
# Ctrl+B, D to detach

# 6. Check validation bug
cs-attach squad-bugfix-validation
# ... fix bug ...
git add . && git commit -m "Fix null validation"
# Ctrl+B, D to detach

# 7. Review status
cs-list

# 8. Stop sessions when done
cs-stop squad-feature-auth
cs-stop squad-feature-api
cs-stop squad-bugfix-validation

# Or cleanup everything
cs-cleanup
```

## Integration Points

### With ClaudeBox

ClaudeBox Squad uses ClaudeBox's slot system for isolation. Each session gets unique slot preventing port conflicts.

Containers mount `~/.claudebox/hal-9000` for MCP servers and agents. All sessions share these components.

### With Claude Squad

Inspired by claude-squad's multi-agent workflow. ClaudeBox Squad provides similar functionality without requiring Go or the full claude-squad installation.

Differences:
- ClaudeBox Squad uses tmux instead of Go TUI
- Each session runs ClaudeBox container instead of bare Claude Code
- Simpler implementation, fewer dependencies

### With Git

Git worktrees share the repository's `.git` directory:
- Commits available across all worktrees
- Fetches update all worktrees
- Each worktree can be on different branch
- Disk usage lower than multiple clones

## Files and Directories

```
~/.claudebox-squad/
├── worktrees/              # Git worktrees
│   ├── myproject-branch1/
│   ├── myproject-branch2/
│   └── myproject-branch3/
├── sessions.log           # Session metadata (JSON lines)
└── .lock/                 # Concurrent execution lock
```

**squadconf** - Configuration file (default: squad.conf in current directory)
- Format: branch:profile:description
- Comments start with #
- Blank lines ignored

## Security Considerations

ClaudeBox containers provide isolation but share:
- Host network (for development convenience)
- Docker socket access (if ClaudeBox configured)
- Mounted hal-9000 directory

Don't run untrusted code in squad sessions without additional sandboxing.

## Performance

**Startup time:** 5-10 seconds per session
- Git worktree creation: 1-2s
- Tmux session: <1s
- ClaudeBox container: 3-7s

**Resource usage per session:**
- Disk: ~500MB (worktree copy-on-write)
- RAM: 1-2GB (depends on profile and workload)
- CPU: Minimal when idle

**Scaling:**
- 1-4 sessions: Comfortable on most machines
- 5-8 sessions: May require resource monitoring
- 9+ sessions: Consider cleanup of idle sessions

## Credits

Inspired by:
- [claude-squad](https://github.com/smtg-ai/claude-squad) - Multi-agent TUI
- [ClaudeBox](https://github.com/RchGrav/claudebox) - Containerized development
- [git worktrees](https://git-scm.com/docs/git-worktree) - Multiple checkouts
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
