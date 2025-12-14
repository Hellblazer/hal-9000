# aod (Army of Darkness) - Multi-Branch Development

You have access to aod for parallel multi-branch development. Each aod session runs in an isolated environment (git worktree, tmux session, ClaudeBox container).

## Available Commands

**Session Management:**
- `aod-list` - Show all active aod sessions
- `aod-attach SESSION` - Attach to specific session (switches context)

**Remote Control (without switching sessions):**
- `aod-send SESSION "command"` - Send command to specific session
- `aod-broadcast "command"` - Send command to ALL aod sessions

**Examples:**
```bash
# Check what's happening in other sessions
aod-list

# Send command to specific session
aod-send aod-feature-api "git status"
aod-send aod-bugfix-validation "./mvnw test"

# Run command in all sessions
aod-broadcast "git fetch"
aod-broadcast "./mvnw clean install"
```

## Detecting Current Session

Check which aod session you're in:
```bash
# Show current tmux session name
tmux display-message -p '#S'

# Or check environment
echo $TMUX
```

Session names follow pattern: `aod-{branch-with-slashes-replaced}`
- `feature/auth` → `aod-feature-auth`
- `bugfix/validation` → `aod-bugfix-validation`

## Common Workflows

**Sync all branches with upstream:**
```bash
aod-broadcast "git fetch origin"
```

**Run tests across all branches:**
```bash
aod-broadcast "./mvnw test"
# Check results in each session later with aod-list
```

**Check status of specific feature:**
```bash
aod-send aod-feature-auth "git status"
```

**Coordinate changes across sessions:**
- Use aod-send to push changes to specific branches
- Use aod-broadcast for operations affecting all branches
- Each session is fully isolated - changes don't affect others until committed/pushed

## Important Notes

- Each aod session has its own git worktree in `~/.aod/worktrees/`
- Sessions share the same git repository (.git directory)
- Commits in one session are visible to others after committing
- Each session runs in isolated ClaudeBox container
- Use aod commands to coordinate without switching context

## When to Use aod Commands

**Use aod-send when:**
- You need to run something in another specific branch without switching
- Checking status of parallel work
- Running tests in background session

**Use aod-broadcast when:**
- Syncing all branches (git fetch, pull)
- Running same operation across all parallel work
- Cleanup operations (clearing builds, etc.)

**Attach to session when:**
- You need to work interactively in that branch
- Debugging issues specific to that branch
- Committing changes in that branch
