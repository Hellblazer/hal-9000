# HAL-9000 Cheat Sheet

Quick reference for aod, tmux, tmux-cli, and terminal tools.

## aod (Army of Darkness)

### Setup & Launch

```bash
# Create configuration file
cat > aod.conf <<EOF
feature/auth:python:Add OAuth2 authentication
feature/api:node:Build REST API endpoints
bugfix/validation:python:Fix input validation
EOF

# Launch all sessions
aod aod.conf          # Uses aod.conf in current directory
aod my-tasks.conf     # Use custom config file
```

### Managing Sessions

```bash
# List all active aod sessions
aod-list

# Attach to specific session
aod-attach aod-feature-auth

# Send command to specific session (without attaching)
aod-send aod-feature-auth "git status"

# Send command to all sessions
aod-broadcast "git fetch"

# Stop single session (keeps worktree)
aod-stop aod-feature-auth

# Cleanup everything (sessions + worktrees)
aod-cleanup
```

### Inside aod Session

```bash
# Detach from session
Ctrl+b, then d

# Check which session you're in
echo $TMUX

# Commit work
git add . && git commit -m "Progress on feature"

# Push to remote
git push -u origin feature/auth
```

### Common Workflows

```bash
# Launch sessions, work on first one
aod aod.conf
aod-attach aod-feature-auth
# ... work on auth ...
# Ctrl+b, d to detach

# Switch to another session
aod-attach aod-feature-api
# ... work on API ...
# Ctrl+b, d to detach

# Check status of all sessions
aod-list

# Done for the day
aod-cleanup
```

## tmux Essentials

### Session Management

```bash
# List all tmux sessions
tmux ls

# Attach to session by name
tmux attach -t aod-feature-auth

# Kill specific session
tmux kill-session -t aod-feature-auth

# Kill all sessions
tmux kill-server
```

### Key Bindings (Prefix = Ctrl+b)

```
# Session Navigation
Ctrl+b d          Detach from session
Ctrl+b (          Previous session
Ctrl+b )          Next session
Ctrl+b s          List and switch sessions

# Window Management (within session)
Ctrl+b c          Create new window
Ctrl+b n          Next window
Ctrl+b p          Previous window
Ctrl+b 0-9        Switch to window by number
Ctrl+b ,          Rename current window
Ctrl+b &          Kill current window

# Pane Management
Ctrl+b %          Split pane vertically
Ctrl+b "          Split pane horizontally
Ctrl+b o          Switch to next pane
Ctrl+b Arrow      Switch to pane in direction
Ctrl+b x          Kill current pane
Ctrl+b z          Zoom/unzoom pane (fullscreen)

# Other
Ctrl+b ?          Show all key bindings
Ctrl+b :          Command prompt
```

### Useful Commands (from shell or Ctrl+b :)

```bash
# List all panes in session with IDs
tmux list-panes -t aod-feature-auth -F '#{pane_id}'

# Send keys to specific pane
tmux send-keys -t %3 "git status" Enter

# Capture pane output
tmux capture-pane -t %3 -p

# Show pane info
tmux display-message -t %3 -p '#{pane_current_command}'
```

## tmux-cli (Remote Control)

### Basic Usage

```bash
# Show current status
tmux-cli status

# Launch application in new pane
tmux-cli launch "zsh"              # Returns pane ID
tmux-cli launch "python3"

# Send command to pane
tmux-cli send "git status" --pane=2
tmux-cli send "ls -la" --pane=%3

# Capture output
tmux-cli capture --pane=2

# Wait for command to finish (avoid polling)
tmux-cli wait_idle --pane=2 --idle-time=3.0

# Send Ctrl+C
tmux-cli interrupt --pane=2

# Send Escape key
tmux-cli escape --pane=2

# Kill pane
tmux-cli kill --pane=2

# Show help
tmux-cli --help
```

### Using with aod Sessions

**Use built-in commands (simpler):**
```bash
# Send to specific session
aod-send aod-feature-auth "git status"

# Send to all sessions
aod-broadcast "git fetch"
```

**Advanced tmux-cli usage:**
```bash
# Capture output from session
SESSION="aod-feature-auth"
PANE=$(tmux list-panes -t $SESSION -F '#{pane_id}' | head -1)
tmux-cli capture --pane=$PANE

# Run tests and wait for completion
SESSION="aod-feature-api"
PANE=$(tmux list-panes -t $SESSION -F '#{pane_id}' | head -1)
tmux-cli send "./mvnw test" --pane=$PANE
tmux-cli wait_idle --pane=$PANE --idle-time=3.0
tmux-cli capture --pane=$PANE

# Monitor long-running build
SESSION="aod-bugfix-validation"
PANE=$(tmux list-panes -t $SESSION -F '#{pane_id}' | head -1)
tmux-cli send "./mvnw clean install" --pane=$PANE
watch -n 5 "tmux-cli capture --pane=$PANE | tail -20"
```

### Important Tips

```bash
# ALWAYS launch shell first (prevents losing output on errors)
tmux-cli launch "zsh"                    # Do this first
tmux-cli send "your-command" --pane=2    # Then run commands

# Delay before Enter (compatibility with slow CLIs)
tmux-cli send "slow command" --pane=2 --delay-enter=1.0

# Send without Enter
tmux-cli send "partial input" --pane=2 --enter=False
```

## Terminal Tools

### vault - Encrypted .env Backup

```bash
# Backup .env file (encrypted with SOPS)
vault backup .env

# Restore .env file
vault restore .env

# View encrypted backup
cat .env.backup
```

**Requires:** SOPS installed and configured

### env-safe - Safe .env Inspection

```bash
# View .env without exposing secrets in shell history
env-safe .env

# Check specific variable
env-safe .env | grep DATABASE_URL
```

### find-session - Search Across Sessions

```bash
# Search for text across all Claude Code sessions
find-session "authentication"
find-session "bug fix"

# Search in specific directory
find-session "API" ~/sessions/
```

## Session Management Commands

### /check - Save Session Context

```
/check
```

Saves current conversation context for later resumption.

### /load - Resume Session

```
/load
```

Lists saved sessions and prompts for which to resume.

### /sessions - List All Sessions

```
/sessions
```

Shows all saved session metadata.

### /session-delete - Delete Session

```
/session-delete
```

Prompts for session to delete.

## Quick Reference Card

### aod Lifecycle

```
1. aod aod.conf          → Launch sessions
2. aod-list              → See what's running
3. aod-attach <name>     → Work on session
4. Ctrl+b d              → Detach when done
5. aod-cleanup           → Stop everything
```

### tmux Session Switching

```
1. Ctrl+b d              → Detach
2. tmux attach -t <name> → Reattach
   OR
   aod-attach <name>     → For aod sessions
```

### tmux-cli Control Pattern

```bash
# Get pane ID
PANE=$(tmux list-panes -t SESSION -F '#{pane_id}' | head -1)

# Send command
tmux-cli send "command" --pane=$PANE

# Wait for completion
tmux-cli wait_idle --pane=$PANE

# Get results
tmux-cli capture --pane=$PANE
```

## Configuration Files

### aod.conf Format

```
branch:profile:description
```

**Examples:**
```
feature/quick-fix::                           # Branch only
feature/api:node:                             # Branch + profile
feature/auth:python:Add OAuth2 authentication # Full specification
feature/fullstack:python,node:Full-stack      # Multiple profiles
```

**Profiles:** python, node, rust, go (comma-separated for multiple)

### ~/.tmux.conf Enhancements

```bash
# Show session name in status bar
set -g status-right "#[fg=cyan]#S #[fg=white]| %H:%M"

# Session persistence (with tmux-resurrect)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
run '~/.tmux/plugins/tpm/tpm'
```

**Resurrect commands:**
- `Ctrl+b Ctrl-s` - Save sessions
- `Ctrl+b Ctrl-r` - Restore sessions

## Claude Code Status Line

**ccstatusline** - Real-time metrics in Claude Code CLI (auto-configured by install.sh)

### Customize

```bash
bunx ccstatusline@latest    # Interactive TUI (Bun)
npx ccstatusline@latest     # Interactive TUI (npm)
```

### Key Widgets

- **Session:** Model, Clock, Cost, Block Timer
- **Git:** Branch, Changes, Worktree
- **Tokens:** Input, Output, Cached, Total, Context %
- **Custom:** Text, Commands

### Example Status Line

Default with Powerline:
```
Ctx: 51.3% ▶ Session: 22hr 5m ▶ Block: 1hr 39m ▶ _/main ▶ 🏠 main
```

Widgets:
- `Ctx: 51.3%` = Context usage (when to `/check`)
- `Session: 22hr 5m` = Total session time
- `Block: 1hr 39m` = Current 5-hour block time
- `_/main` = Git branch
- `🏠 main` = Worktree/directory

**TUI Navigation:** Press `(a)dd` then `←→` to cycle widget types

### Quick Tips

- Settings: `~/.config/ccstatusline/settings.json`
- Each aod session = independent status line
- Press `(a)dd` then `←→` to cycle widget types
- Powerline style requires Nerd Font

**Docs:** https://github.com/sirmalloc/ccstatusline

## Troubleshooting

### aod Issues

```bash
# Worktree already exists
git worktree list                        # Check existing
git worktree remove <path> --force       # Remove
# OR
aod-cleanup                              # Nuclear option

# Session already exists
tmux ls                                  # Check sessions
tmux kill-session -t aod-feature-auth    # Kill specific
# OR
aod-cleanup

# Container port conflict
docker ps --filter "name=claudebox"      # List containers
docker rm -f <container-name>            # Force remove
# OR
aod-cleanup
```

### tmux Issues

```bash
# Can't attach to session
tmux ls                                  # Verify session exists
tmux kill-session -t <name>              # Kill and retry

# Pane commands not working
tmux list-panes -a -F '#{pane_id}'       # List all panes
# Use correct pane ID format: %0, %1, etc.

# Server crashed
tmux kill-server                         # Nuclear option
rm -rf /tmp/tmux-*                       # Clean socket files
```

### tmux-cli Issues

```bash
# "No target pane specified"
tmux-cli status                          # Check available panes
tmux-cli list_panes                      # Get pane IDs

# Pane ID not found
tmux list-panes -a                       # Verify pane exists
# Use pane index (2) or full ID (%3)

# Commands not reaching pane
tmux-cli send "echo test" --pane=2       # Test basic send
tmux-cli capture --pane=2                # Verify output
```

## Common Patterns

### Multi-Branch Development

```bash
# Start work on 3 features
cat > sprint.conf <<EOF
feature/user-auth:python:Authentication system
feature/payment:node:Payment processing
feature/notifications:python:Push notifications
EOF

aod sprint.conf

# Work on each throughout the day
aod-attach aod-feature-user-auth    # Morning: auth
# Ctrl+b d
aod-attach aod-feature-payment      # Afternoon: payment
# Ctrl+b d
aod-attach aod-feature-notifications # Evening: notifications
# Ctrl+b d

# End of day
aod-cleanup
```

### Code Review Multiple PRs

```bash
cat > reviews.conf <<EOF
review/pr-123:python:Auth PR review
review/pr-124:node:API changes review
review/pr-125:python:DB migration review
EOF

aod reviews.conf

# Review each PR in isolated environment
aod-attach aod-review-pr-123
# ... review, test, comment ...
# Ctrl+b d

aod-attach aod-review-pr-124
# ... review, test, comment ...
```

### Batch Operations Across Sessions

```bash
# Git fetch in all aod sessions
aod-broadcast "git fetch"

# Run tests in all sessions
aod-broadcast "./mvnw test"

# Pull latest from all branches
aod-broadcast "git pull --rebase"

# Capture output from all sessions (advanced)
for session in $(tmux ls | grep "^aod-" | cut -d: -f1); do
    pane=$(tmux list-panes -t $session -F '#{pane_id}' | head -1)
    echo "=== $session ==="
    tmux-cli capture --pane=$pane | tail -10
done
```

### Experiment with Different Approaches

```bash
cat > experiments.conf <<EOF
experiment/approach-a:python:Try SQLAlchemy ORM
experiment/approach-b:python:Try raw SQL
experiment/approach-c:python:Try async driver
EOF

aod experiments.conf

# Implement each approach in parallel
# Compare results without destroying previous work
```

## Resource Management

```bash
# Check container resource usage
docker stats --filter "name=claudebox"

# Check disk space in worktrees
du -sh ~/.aod/worktrees/*

# Kill idle containers
docker ps --filter "name=claudebox" -q | xargs docker kill

# Prune stale worktrees
git worktree prune
```

## Tips & Tricks

1. **Use descriptive branch names** - They become session names
2. **Commit frequently** - Each worktree is independent
3. **Monitor resources** - 3-4 concurrent sessions comfortable on most machines
4. **Use tmux-cli for automation** - Batch operations without context switching
5. **Status bar is your friend** - Always know which session you're in
6. **aod-list before aod-cleanup** - Verify what you're killing
7. **Launch shell first with tmux-cli** - Prevents losing output on errors
8. **Use wait_idle** - Avoid polling loops
9. **Tab completion** - `aod-attach aod-<TAB>` shows options
10. **Keep aod.conf in version control** - Document your workflow

## Related Documentation

- aod Full Documentation: `plugins/hal-9000/aod/README.md`
- tmux-cli Documentation: Run `tmux-cli --help`
- Session Commands: `plugins/hal-9000/commands/*.md`
