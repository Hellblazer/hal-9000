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

## Knowledge Management

### ChromaDB
- Store memories, relate knowledge, track complex concepts for long-running projects
- ChromaDB metadata: scalars only (str/int/float/bool/None), no arrays/dicts - use comma-separated strings
- Search reference: "chromadb-metadata-constraints" for detailed constraints

### Memory Bank
- Coordinate parallel work across agents
- Persistent storage across sessions in ~/memory-bank
- Organize by project for easy retrieval

### Session Management
- Use `/check` to save current session context
- Use `/load` to resume saved sessions
- Use `/sessions` to list all available sessions
- Use `/session-delete` to remove old sessions

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

---

**Note**: This is the hal-9000 marketplace template. Add your personal preferences and project-specific guidelines below this line.
