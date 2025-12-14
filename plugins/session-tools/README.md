# Session Tools Plugin

Session management commands for Claude Code workflows.

## What's Included

### `/check` - Save Session
Save your current context for later resumption.

**Usage**: `/check <session-name> <task description>`

**Example**:
```
/check fix-auth-bug Fix authentication timeout issue in UserService
```

Creates a snapshot including:
- Current working directory
- Git status and recent changes
- Beads task status (if available)
- Task description

### `/load` - Load Session
Resume a previously saved session.

**Usage**: `/load <session-name>`

**Example**:
```
/load fix-auth-bug
```

Displays the saved context so you can continue where you left off.

### `/sessions` - List Sessions
View all saved sessions with metadata.

**Usage**: `/sessions`

Shows:
- Session names
- Task descriptions
- When saved
- Working directories

### `/session-delete` - Delete Session
Remove a session that's no longer needed.

**Usage**: `/session-delete <session-name>`

## Installation

This plugin will be installed automatically through the hal-9000 marketplace.

Session files are stored in `~/.claude/sessions/`

## Workflow Example

```bash
# Start working on a feature
cd /path/to/project
# ...make some changes...

# Need to pause? Save your session
/check oauth-implementation Add OAuth2 authentication flow

# Later, in a new conversation
/load oauth-implementation
# Continue working...

# When done
/session-delete oauth-implementation
```

## Session Files

Sessions are stored as:
```
~/.claude/sessions/<session-name>/
├── context.txt    # Full context snapshot
└── intent.txt     # Task description
```

These are plain text files you can view or edit manually if needed.

## Tips

- Use descriptive session names
- Save sessions at logical stopping points
- Review `/sessions` periodically and clean up old ones
- Include specific task descriptions in `/check` for better context

## Requirements

- Bash shell
- git (optional, for git status capture)
- beads (optional, for beads status capture)
