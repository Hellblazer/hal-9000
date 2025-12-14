# Claude Squad Plugin

Terminal UI for managing multiple Claude Code, Codex, Gemini, or Aider instances in parallel with isolated git worktrees and background task completion.

## What is Claude Squad?

Claude Squad is a terminal application that lets you run multiple AI coding assistants simultaneously, each working on different tasks in isolated workspaces. Think of it as a "multi-agent orchestrator" for AI-powered development.

### Key Features

- **Multi-Instance Management**: Run multiple Claude Code/Codex/Gemini/Aider instances in parallel
- **Isolated Git Worktrees**: Each task gets its own branch and workspace - no conflicts
- **Background Execution**: Tasks complete in the background while you work on other things
- **Auto-Accept Mode**: Experimental "yolo" mode for fully autonomous task completion
- **TUI Interface**: Clean terminal UI for managing all instances
- **Review Before Apply**: Review changes before committing them
- **GitHub Integration**: Commit and push branches directly from the UI

## How It Works

Claude Squad uses three key technologies:

1. **tmux** - Creates isolated terminal sessions for each agent
2. **git worktrees** - Isolates codebases so each session works on its own branch
3. **TUI** - Simple, keyboard-driven interface for navigation and management

## Installation

### From hal-9000 Marketplace

1. Add hal-9000 marketplace to Claude Code
2. Install claude-squad plugin
3. Run installation script:
   ```bash
   cd ~/.claude/marketplace/hal-9000/plugins/claude-squad
   ./install.sh
   ```

### Installation Methods

The installer offers two methods:

**1. Homebrew (Recommended)**
- Installs via `brew install claude-squad`
- Creates `cs` symlink automatically
- Manages dependencies (tmux, gh)

**2. Official Installer Script**
- Downloads from GitHub releases
- Auto-detects platform and architecture
- Installs to `~/.local/bin/cs`
- Auto-installs tmux and gh if missing
- Updates PATH automatically

### What the Installer Does

**Preflight Checks:**
- Checks for tmux (required)
- Checks for GitHub CLI / gh (required)
- Reports any missing dependencies

**Installation Process:**
- Installs missing dependencies automatically
- Downloads latest claude-squad release
- Installs as `cs` command
- Updates shell PATH if needed
- Verifies installation

**Remediation:**
- Automatically installs tmux via package manager
- Automatically installs gh via package manager
- Shows clear error messages with instructions if manual intervention needed

## Requirements

### Required
- **tmux**: Terminal multiplexer (auto-installed by installer)
- **gh**: GitHub CLI (auto-installed by installer)
- **git**: Version control (usually pre-installed)

### Optional
- **Claude Code**: Primary AI assistant (default)
- **Codex**: OpenAI's Codex CLI
- **Gemini**: Google's Gemini CLI
- **Aider**: Open-source AI coding assistant

## Usage

### Basic Commands

```bash
# Launch Claude Squad with default (claude)
cs

# Launch with specific AI assistant
cs -p "aider"
cs -p "codex"
cs -p "gemini"

# Launch with custom Aider configuration
cs -p "aider --model ollama_chat/gemma3:1b"

# Auto-accept mode (experimental)
cs -y
```

### Keyboard Shortcuts

#### Session Management
- `n` - Create new session
- `N` - Create new session with initial prompt
- `D` - Kill (delete) selected session
- `↑/j`, `↓/k` - Navigate between sessions

#### Actions
- `↵/o` - Attach to selected session to interact/reprompt
- `ctrl-q` - Detach from session (session continues in background)
- `s` - Commit changes and push branch to GitHub
- `c` - Checkout - Commits changes and pauses the session
- `r` - Resume a paused session
- `?` - Show help menu

#### Navigation
- `tab` - Switch between preview tab and diff tab
- `q` - Quit the application
- `shift-↓/↑` - Scroll in diff view

### Configuration

```bash
# Show configuration paths
cs debug

# Reset all stored instances
cs reset

# View version
cs version
```

Configuration file is auto-generated at first run. Use `cs debug` to find the location.

**Example config.yaml:**
```yaml
# Default program to run
program: claude

# Auto-accept prompts (experimental)
autoyes: false
```

## Workflows

### Multi-Task Development

```bash
# Launch Claude Squad
cs

# Inside the UI:
# Press 'n' to create new session
# Task: "Add user authentication"
# Session starts in background

# Press 'n' again for another task
# Task: "Write tests for UserService"

# Press 'tab' to view diffs
# Review changes in real-time

# Press 's' to commit and push when ready
```

### Code Review Workflow

```bash
# Create session for implementing feature
Press 'n': "Implement OAuth login"

# Create session for reviewing code
Press 'n': "Review OAuth implementation for security issues"

# Compare both in diff view
Press 'tab' to switch views

# Checkout one, resume the other
Press 'c' on review session
Press 'r' on implementation session
```

### Background Processing

```bash
# Start task in background
cs -y  # Auto-accept mode

# Create multiple tasks
Each completes autonomously

# Check progress later
All changes visible in diff view

# Review and commit when ready
```

### Multi-Agent Collaboration

```bash
# Launch with Claude for backend
cs -p "claude"
Session 1: "Implement REST API endpoints"

# In another terminal, launch with Aider for frontend
cs -p "aider"
Session 1: "Create React components for API"

# Switch between terminals to manage both
# Each works in isolated git worktrees
# No conflicts, merge when ready
```

## Advanced Features

### Git Worktree Isolation

Each session automatically gets:
- Separate git worktree
- Own branch (squad-session-<id>)
- Isolated working directory
- No conflicts with other sessions

```bash
# Example directory structure
my-project/
├── .git/
├── squad-session-1/  # First task
├── squad-session-2/  # Second task
└── squad-session-3/  # Third task
```

### GitHub Integration

```bash
# Commit and push from UI
Press 's' on any session

# Creates PR-ready branch
# Pushes to origin
# Shows confirmation
```

### Session Persistence

Sessions persist between cs restarts:
- Resume interrupted work
- Check status of background tasks
- Continue where you left off

## Troubleshooting

### Failed to start new session

**Problem:** `failed to start new session: timed out waiting for tmux session`

**Solution:**
```bash
# Update Claude Code to latest version
claude --version

# Or update the AI assistant you're using
aider --version
```

### tmux not found

**Problem:** `tmux: command not found`

**Solution:**
```bash
# macOS
brew install tmux

# Linux (Debian/Ubuntu)
sudo apt-get install tmux

# Linux (Fedora)
sudo dnf install tmux
```

### GitHub CLI not found

**Problem:** `gh: command not found`

**Solution:**
```bash
# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install gh
```

### PATH not updated

**Problem:** `cs: command not found` after installation

**Solution:**
```bash
# Check if installed
ls ~/.local/bin/cs

# If exists, add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or for zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Session won't attach

**Problem:** Can't attach to session

**Solution:**
```bash
# Check tmux sessions
tmux ls

# Force kill if stuck
tmux kill-session -t squad-session-<id>

# Reset all instances
cs reset
```

## Configuration Examples

### Custom Aider Setup

```bash
# Use specific model
cs -p "aider --model gpt-4"

# Use local model via Ollama
cs -p "aider --model ollama_chat/codellama"

# With additional flags
cs -p "aider --model gpt-4 --no-auto-commits"
```

### Codex Setup

```bash
# Set API key
export OPENAI_API_KEY=your-key-here

# Launch Codex
cs -p "codex"
```

### Make Default Program

Edit config file (find location with `cs debug`):

```yaml
# Set default to Aider
program: aider --model gpt-4

# Or Codex
program: codex

# Or Gemini
program: gemini
```

## Use Cases

### Parallel Feature Development

```
Session 1: Implement user authentication
Session 2: Add database migrations
Session 3: Write API documentation
Session 4: Create integration tests

All work simultaneously in isolated branches
```

### Code Review & Refactoring

```
Session 1: Review codebase for security issues
Session 2: Refactor identified problems
Session 3: Add tests for refactored code

Compare sessions side-by-side in diff view
```

### Multi-Framework Development

```
Session 1 (Claude): Backend API in Python
Session 2 (Aider): Frontend in React
Session 3 (Codex): Mobile app in React Native

Each AI assistant works on its specialty
```

### Background Task Queue

```
Launch with auto-accept mode:
  cs -y

Create multiple tasks:
  n: "Fix all lint errors"
  n: "Update dependencies"
  n: "Add docstrings to public API"

All complete in background
Review and merge when done
```

## Updating

### Homebrew

```bash
brew upgrade claude-squad
```

### Manual

```bash
# Re-run installer for latest version
curl -fsSL https://raw.githubusercontent.com/smtg-ai/claude-squad/main/install.sh | bash
```

## Uninstalling

### Homebrew

```bash
brew uninstall claude-squad

# Remove symlink if it exists
rm -f $(brew --prefix)/bin/cs
```

### Manual

```bash
# Remove binary
rm -f ~/.local/bin/cs
rm -f ~/.local/bin/claude-squad

# Remove config
rm -rf ~/.config/claude-squad

# Remove git worktrees (optional)
# Navigate to your project and run:
git worktree prune
```

## Credits

Original project: [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad)

Forked by: [Hellblazer/claude-squad](https://github.com/Hellblazer/claude-squad)

License: AGPL-3.0

## See Also

- [Claude Code](https://github.com/anthropics/claude-code) - AI coding assistant
- [Codex](https://github.com/openai/codex) - OpenAI's code generator
- [Aider](https://github.com/Aider-AI/aider) - Open-source AI coding tool
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [GitHub CLI](https://cli.github.com/) - GitHub command line tool
