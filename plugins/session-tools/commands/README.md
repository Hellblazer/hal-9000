# Slash Commands

Custom slash commands for Claude Code workflows.

## Available Commands

### Session Management

Session commands help you save and resume work across Claude Code sessions. Perfect for long-running tasks that span multiple conversations.

#### `/check <session-name> <task description>`
Save your current context and task for later resumption.

**What it does:**
- Saves current working directory
- Captures git status and recent changes
- Records beads task status (if using beads)
- Creates a continuation prompt for easy resumption

**Example:**
```
/check fix-auth-bug Fix authentication timeout issue in UserService
```

**Output:** Creates session files in `~/.claude/sessions/<session-name>/`

---

#### `/load <session-name>`
Load a previously saved session to continue where you left off.

**What it does:**
- Displays the saved context
- Shows task description
- Lists git status at time of save
- Provides continuation context for Claude

**Example:**
```
/load fix-auth-bug
```

---

#### `/sessions`
List all saved sessions with metadata.

**What it does:**
- Shows all session names
- Displays task descriptions
- Shows when each session was saved
- Lists working directory for each session

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

#### `/session-delete <session-name>`
Delete a saved session that's no longer needed.

**What it does:**
- Removes session directory and all files
- Confirms deletion

**Example:**
```
/session-delete fix-auth-bug
```

---

## Installation

Copy these command files to your Claude Code commands directory:

```bash
cp *.md ~/.claude/commands/
```

Then restart Claude Code or use `/help` to see the new commands.

## Usage Tips

### Session Workflow

1. Start working on a task
2. When you need to pause: `/check my-session Task description here`
3. Later, in a new conversation: `/load my-session`
4. Continue working
5. When done: `/session-delete my-session`

### Session Naming

- Use descriptive names: `fix-login-bug`, `add-oauth`, `refactor-api`
- Avoid spaces (use hyphens or underscores)
- Keep names short but meaningful

### Best Practices

- Save sessions at logical stopping points
- Include specific task descriptions in `/check`
- Review `/sessions` periodically and clean up old ones
- Use beads task tracking for more structured workflows

## File Locations

- **Sessions**: `~/.claude/sessions/<session-name>/`
  - `context.txt` - Full context snapshot
  - `intent.txt` - Task description

- **Commands**: `~/.claude/commands/`
  - `*.md` - Slash command definitions

## Requirements

- Claude Code installed
- Bash shell
- git (for git-related context capture)
- beads (optional, for beads status capture)

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
