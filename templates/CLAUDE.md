# hal-9000 Claude Code Configuration

This file provides Claude Code with guidance on using hal-9000 tools and best practices.

## tmux-cli: Interactive CLI Control

`tmux-cli` enables Claude Code to control CLI applications in separate tmux panes.
Run `tmux-cli --help` for full documentation.

### Core Commands
- `tmux-cli launch "command"` - Launch application in new pane (returns pane ID)
- `tmux-cli send "text" --pane=ID` - Send input to pane
- `tmux-cli capture --pane=ID` - Get output from pane
- `tmux-cli wait_idle --pane=ID` - Wait for command to finish (avoid polling)
- `tmux-cli kill --pane=ID` - Terminate pane
- `tmux-cli status` - Show all panes and current state

### Critical Pattern: Always Launch Shell First
```bash
tmux-cli launch "zsh"           # Returns pane ID (e.g., 2)
tmux-cli send "python script.py" --pane=2
tmux-cli wait_idle --pane=2
tmux-cli capture --pane=2
```
**Why?** If you launch a command directly and it errors, the pane closes immediately
and you lose all output. Shell keeps pane alive.

### When to Use tmux-cli
- **Interactive debugging**: Python pdb, gdb, interactive REPLs
- **Spawn Claude Code instances**: Parallel analysis/review/debugging
- **Long-running processes**: Monitor output, send signals (Ctrl+C via `interrupt`)
- **Web app testing**: Launch servers, coordinate with browser automation MCPs
- **Scripts waiting for input**: Interactive installers, configuration wizards

### When NOT to Use tmux-cli
- Simple one-shot commands → Use regular `Bash` tool
- Background tasks without interaction → Use `Bash` with `run_in_background`
- File operations → Use dedicated tools (Read, Write, Edit, Grep, Glob)

### For Complex Workflows
Use the `cli-controller` skill for guided workflows:
- Python debugging with pdb
- Spawning and coordinating Claude Code instances
- Multi-step interactive testing scenarios

## beads (bd) - Issue Tracking

Use `bd` for ALL task and issue tracking. Do NOT use markdown TODO lists.

### Quick Reference
```bash
bd ready                          # Show work ready to do (no blockers)
bd create "Title" -t type -p prio # Create issue (types: bug/feature/task/epic/chore)
bd update <id> --status in_progress
bd close <id> --reason "Done"
bd list                           # All issues
bd show <id>                      # Issue details
bd dep add <id> <blocker-id>      # Add dependency
bd dep tree <id>                  # View dependency tree
```

### Issue Types
- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priority Levels
- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### AI Workflow
1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress --json`
3. **Work on it**: Implement, test, document
4. **Discover new work?**: `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Commit together**: Always commit `.beads/issues.jsonl` with code changes

### Project Setup
```bash
cd your-project
bd init                           # Initialize beads
bd onboard                        # Get full integration guide
```

## Workflow & Architecture Best Practices

### Agent Usage
- Spawn parallel tasks/agents whenever applicable to conserve context and leverage MCP servers
- Spawn at top level - don't do subtask work directly, delegate to agents
- Use beads for all planning, hypothesis-based testing, exploration, debugging, analysis, design
- Always use plan-auditor agent to audit plans/designs for completeness, redundancy, issues, blockers
- Test-first approach - advance only on well-tested, validated code foundation

### Available Agents
- **Java Development**: java-developer, java-architect-planner, java-debugger
- **Review & Analysis**: code-review-expert, plan-auditor, deep-analyst, codebase-deep-analyzer
- **Research**: deep-research-synthesizer, devonthink-researcher
- **Organization**: knowledge-tidier, pdf-chromadb-processor, project-management-setup

## MCP Servers

### ChromaDB
Vector database for semantic search and long-term memory.
```
Store memories, relate knowledge, track complex concepts
Search: mcp__chromadb__search_similar, mcp__chromadb__hybrid_search
Create: mcp__chromadb__create_document
```
- Metadata: scalars only (str/int/float/bool/None), no arrays/dicts - use comma-separated strings

### Memory Bank
Persistent project memory across sessions.
```
mcp__allPepper-memory-bank__list_projects
mcp__allPepper-memory-bank__memory_bank_read
mcp__allPepper-memory-bank__memory_bank_write
```
- Storage: `~/memory-bank/{project-name}/`
- Coordinate parallel work across agents

### Sequential Thinking
Step-by-step reasoning for complex problems.
```
mcp__sequential-thinking__sequentialthinking
```
- Use for: debugging, analysis, multi-step problem solving
- Allows revision of previous thoughts, branching, hypothesis verification

### DEVONthink (macOS)
Document research and import from DEVONthink databases.
```
mcp__devonthink__search - Search across databases
mcp__devonthink__document - Get document content
mcp__devonthink__research - Research topics
mcp__devonthink__import - Import from URLs (arXiv, etc.)
```

## Session Management
- `/check` - Save current session context
- `/load` - Resume saved sessions
- `/sessions` - List all available sessions
- `/session-delete` - Remove old sessions

## aod (Army of Darkness)

For parallel multi-branch development:
- `aod aod.conf` - Launch parallel sessions from config
- `aod-list` - Show all active sessions
- `aod-attach [session]` - Attach to specific session
- `aod-send [session] "cmd"` - Send command to session
- `aod-broadcast "cmd"` - Send to all sessions
- `aod-cleanup` - Remove all sessions and worktrees

Each aod session runs in:
- Isolated git worktree
- Dedicated tmux session
- Optional ClaudeBox container

## hal9000 (Containerized Claude)

For isolated Claude sessions in Docker containers:
```bash
hal9000 run                       # Single container in current directory
hal9000 run --profile python      # With language profile
hal9000 squad --sessions 3        # Multiple parallel sessions
hal9000-list                      # List active sessions
hal9000-attach SESSION            # Attach to session
hal9000-send SESSION "cmd"        # Send command to session
hal9000-broadcast "cmd"           # Send to all sessions
hal9000-cleanup                   # Stop all sessions
```

Each hal9000 session:
- Runs in isolated Docker container
- Has full hal-9000 stack (MCP servers, tools, agents)
- Shares memory-bank with host (`~/memory-bank`)

## Terminal Tools

### vault
Encrypted .env backup with SOPS:
```bash
vault backup .env                 # Encrypt and backup
vault restore .env                # Restore from backup
vault list                        # List backups
```

### env-safe
Safe .env inspection without exposing secrets:
```bash
env-safe .env                     # Show keys only (no values)
env-safe .env --check             # Validate format
```

### find-session
Search across Claude Code sessions:
```bash
find-session "search term"        # Search all sessions
find-session --recent             # Recent sessions
```

## Safety Hooks

Installed hooks protect against common mistakes:
- **git hooks**: Block accidental commits of secrets, large files
- **file hooks**: Protect sensitive files (.env, credentials)
- **environment hooks**: Warn about production environment access

---

**Note**: This is the hal-9000 marketplace template. Add your personal preferences and project-specific guidelines below this line.
