# aod Session Context

Multi-branch development via git worktrees + tmux + containers.

## Commands

```bash
aod-list                          # List sessions
aod-attach SESSION                # Attach (switches context)
aod-send SESSION "cmd"            # Send without switching
aod-broadcast "cmd"               # Send to all sessions
```

## Session Detection

Session name pattern: `aod-{branch}` (slashes → dashes)
```bash
tmux display-message -p '#S'      # Current session name
```

## Key Facts

- Worktrees: `~/.aod/worktrees/`
- Sessions share git repo, isolated working trees
- Commits visible to other sessions after commit
- Each session in ClaudeBox container

## beads (bd)

```bash
bd ready                          # Unblocked work
bd update <id> --status in_progress
bd close <id> --reason "Done"
```

Issues in `.beads/issues.jsonl` - commit with code changes.
