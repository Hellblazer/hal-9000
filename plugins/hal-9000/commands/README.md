# Slash Commands

Custom slash commands for Claude Code session management.

## Available Commands

### /check <session-name> <task description>
Save current context and task for later resumption.

**Saves:**
- Current working directory
- Git status and recent changes
- Continuation prompt

**Example:**
```
/check fix-auth-bug Fix authentication timeout issue in UserService
```

Creates session files in `~/.claude/sessions/<session-name>/`

---

### /load <session-name>
Load a previously saved session.

**Shows:**
- Saved context
- Task description
- Git status at time of save
- Continuation context for Claude

**Example:**
```
/load fix-auth-bug
```

---

### /sessions
List all saved sessions with metadata.

**Displays:**
- Session names
- Task descriptions
- Save timestamps
- Working directories

**Example:**
```
/sessions
```

**Output:**
```
Found 3 session(s):

**fix-auth-bug**
  Task: Fix authentication timeout issue in UserService
  Saved: 2025-12-10 14:30:22 (3 days ago)
  Directory: /Users/hal/git/my-project

...
```

---

### /session-delete <session-name>
Delete a saved session.

**Example:**
```
/session-delete fix-auth-bug
```

---

## Installation

Copy command files to your Claude Code commands directory:

```bash
cp *.md ~/.claude/commands/
```

Restart Claude Code or use `/help` to see new commands.

## Usage Workflow

1. Start working on a task
2. When pausing: `/check my-session Task description here`
3. Later, in new conversation: `/load my-session`
4. Continue working
5. When done: `/session-delete my-session`

## Session Naming

- Use descriptive names: `fix-login-bug`, `add-oauth`, `refactor-api`
- Avoid spaces (use hyphens or underscores)
- Keep names short but meaningful

## Best Practices

- Save sessions at logical stopping points
- Include specific task descriptions in `/check`
- Review `/sessions` periodically and clean up old ones

## File Locations

**Sessions**: `~/.claude/sessions/<session-name>/`
- `context.txt` - Full context snapshot
- `intent.txt` - Task description

**Commands**: `~/.claude/commands/`
- `*.md` - Slash command definitions

## Requirements

- Claude Code
- Bash shell
- git (for git-related context capture)

## Troubleshooting

### Command not found

Ensure files are in `~/.claude/commands/` and restart Claude Code.

### Session files not created

Check permissions on `~/.claude/sessions/`:
```bash
mkdir -p ~/.claude/sessions
chmod 755 ~/.claude/sessions
```

### Git status not showing

Ensure you're in a git repository:
```bash
git rev-parse --git-dir
```
