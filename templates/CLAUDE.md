# hal-9000 Claude Code Configuration

Quick reference for hal-9000 tools. See [CHEATSHEET.md](CHEATSHEET.md) for full details.

## tmux-cli

Control CLI apps in tmux panes. Run `tmux-cli --help` for full docs.

```bash
tmux-cli launch "zsh"           # Always launch shell first (prevents losing output)
tmux-cli send "command" --pane=2
tmux-cli wait_idle --pane=2     # Wait for completion (avoid polling)
tmux-cli capture --pane=2       # Get output
tmux-cli kill --pane=2
```

**Use for:** Interactive debugging, spawning Claude instances, long-running processes
**Don't use for:** Simple commands (use Bash), file ops (use Read/Write/Edit)

## beads (bd)

Issue tracking. Use `bd` for ALL task tracking - not markdown TODO lists.

```bash
bd ready                          # Show unblocked work
bd create "Title" -t feature -p 1 # Types: bug/feature/task/epic/chore
bd update <id> --status in_progress
bd close <id> --reason "Done"
bd dep add <id> <blocker-id>      # Add dependency
```

Always commit `.beads/issues.jsonl` with code changes. Run `bd onboard` for full guide.

## Agents

Spawn parallel agents to conserve context. Use plan-auditor to validate plans.

- **Development**: java-developer, java-architect-planner, java-debugger
- **Review**: code-review-expert, plan-auditor, deep-analyst, codebase-deep-analyzer
- **Research**: deep-research-synthesizer, devonthink-researcher
- **Organization**: knowledge-tidier, pdf-chromadb-processor, project-management-setup

## MCP Servers

- **ChromaDB**: `mcp__chromadb__search_similar`, `mcp__chromadb__create_document` (metadata: scalars only)
- **Memory Bank**: `mcp__allPepper-memory-bank__memory_bank_read/write` (storage: `~/memory-bank/`)
- **Sequential Thinking**: `mcp__sequential-thinking__sequentialthinking` (debugging, analysis)
- **DEVONthink**: `mcp__devonthink__search`, `mcp__devonthink__research` (macOS only)

## Session Commands

`/check` save | `/load` resume | `/sessions` list | `/session-delete` remove

## hal9000 & aod

**hal9000** - Containerized Claude sessions:
```bash
hal9000 run [--profile python]    # Single container
hal9000 squad --sessions 3        # Multiple sessions
hal9000-list | hal9000-attach | hal9000-send | hal9000-broadcast | hal9000-cleanup
```

**aod** - Multi-branch development with git worktrees:
```bash
aod aod.yml                       # Launch from config
aod-list | aod-attach | aod-send | aod-broadcast | aod-cleanup
```

## Terminal Tools

- `vault backup/restore .env` - Encrypted .env backup (SOPS)
- `env-safe .env` - Inspect .env without exposing secrets
- `find-session "term"` - Search across Claude sessions

## Safety Hooks

Git, file, and environment hooks protect against accidental secret commits and sensitive file access.

---

**Full documentation:** [CHEATSHEET.md](CHEATSHEET.md) | Add project-specific guidelines below.
