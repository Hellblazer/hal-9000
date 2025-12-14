# Claude Code Tools Plugin

Comprehensive toolkit for enhancing Claude Code with terminal automation, session management, security hooks, and developer productivity tools.

## What's Included

This plugin installs and configures [claude-code-tools](https://github.com/pchalasani/claude-code-tools), a collection of powerful utilities:

### 🎮 tmux-cli - Terminal Automation
**"Playwright for terminals"** - Give Claude Code programmatic control over interactive CLI applications.

**Use Cases:**
- Debug with pdb, gdb, or any interactive debugger
- Launch and coordinate multiple Claude Code instances
- Test interactive scripts that require user input
- Run web servers and test with browser automation MCPs
- Control any CLI application that needs interactive input

**Key Features:**
- Launch programs in tmux panes
- Send input and capture output programmatically
- Wait for processes to complete
- Works with both local and remote sessions
- Automatic shell preservation (pane stays alive on errors)

### 🔍 Session Search Tools
Find and resume Claude Code/Codex sessions across projects.

**find-session** - Unified search across all agents
- Search both Claude Code and Codex sessions simultaneously
- Filter by keywords, project, or agent
- Interactive selection with rich table display
- Smart resume with correct CLI tool

**find-claude-session** - Claude Code specific
- Search and resume Claude sessions by keywords
- Cross-project search capabilities
- Shows git branch, date, and message preview
- Persistent directory changes when resuming

**find-codex-session** - Codex specific
- Similar functionality for Codex sessions

### 🔐 vault - Encrypted .env Backup
Centralized encrypted backup for .env files using SOPS.

- Store all .env files in `~/Git/dotenvs/`
- GPG encryption for security
- Smart sync direction detection
- Timestamped backups

**Commands:**
```bash
vault sync      # Auto-detect and sync
vault encrypt   # Backup to vault
vault decrypt   # Restore from vault
vault list      # Show all backups
vault status    # Check current project status
```

### 🔍 env-safe - Safe .env Inspection
Inspect .env files without exposing secret values.

**Why?** Claude Code is blocked from reading .env files to prevent accidental API key exposure. `env-safe` provides the only approved way to inspect environment configuration.

**Commands:**
```bash
env-safe list              # List all keys
env-safe list --status     # Show defined/empty status
env-safe check API_KEY     # Check if key exists
env-safe count             # Count variables
env-safe validate          # Check syntax
```

### 🛡️ Safety Hooks
Comprehensive protection hooks for Claude Code.

**File Deletion Protection**
- Blocks `rm` commands
- Enforces TRASH directory pattern

**Git Safety**
- Hard blocks: `git add .`, `git add ../`, `git add *`, `git add -A`
- Speed bumps for directory staging (shows files first)
- Commit warnings on first attempt
- Prevents unsafe checkouts

**Environment Security**
- Blocks all .env file operations
- Suggests `env-safe` for inspection

**Context Management**
- Blocks reading files >500 lines (prevents context bloat)

**Command Enhancement**
- Enforces ripgrep (`rg`) over grep

### 🚀 lmsh - Natural Language Shell (Optional)
Rust-based shell that translates natural language to commands.

```bash
lmsh "show me all python files modified today"
# → find . -name "*.py" -mtime 0

lmsh
lmsh> show recent docker containers
# → docker ps -n 5
```

**Features:**
- Instant startup (<1ms)
- Editable commands before execution
- Preserves shell environment
- Requires: Rust/Cargo and Claude Code CLI

## Installation

### From hal-9000 Marketplace

1. Add hal-9000 marketplace to Claude Code
2. Install claude-code-tools plugin
3. Run installation script:
   ```bash
   cd ~/.claude/marketplace/hal-9000/plugins/claude-code-tools
   ./install.sh
   ```

### What the Installer Does

**Dependency Checks:**
- Python 3.11+ (required)
- uv (required for installation)
- tmux (required for tmux-cli)
- SOPS (optional, for vault)
- jq (optional, for auto-config merge)
- Rust/Cargo (optional, for lmsh)

**Installation Methods:**
- **Preferred:** Homebrew (macOS/Linux)
- **Fallback:** curl for uv, rustup for Rust
- **APT/DNF:** Linux package managers

**Installation Process:**
- Installs claude-code-tools from PyPI via `uv tool install`
- Downloads safety hooks from GitHub to `~/.claude/hooks/claude-code-tools/`
- Merges hooks configuration into Claude settings (with backup)
- Adds tmux-cli documentation to global CLAUDE.md
- Optionally installs lmsh via cargo (if Rust available)
- Provides shell function snippets for .bashrc/.zshrc

**No Git Clone Required** - Everything installed via package managers!

## Requirements

### Required
- Python 3.11+
- uv (package installer)
- tmux (for tmux-cli)

### Optional
- SOPS (for vault functionality)
- jq (for automatic config merging)
- Rust/Cargo (for lmsh)
- Git (for repository cloning)

## Post-Installation

### 1. Add Shell Functions

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Unified session search
fs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-session --help
        return
    fi
    eval "$(find-session --shell "$@" | sed '/^$/d')"
}

# Claude session search
fcs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        find-claude-session --help
        return
    fi
    eval "$(find-claude-session --shell "$@" | sed '/^$/d')"
}
```

Then: `source ~/.bashrc` or `source ~/.zshrc`

### 2. Restart Claude Code

Restart to load the safety hooks.

### 3. Verify Installation

```bash
tmux-cli --help
find-session --help
vault --help
env-safe --help
```

## Usage Examples

### tmux-cli: Interactive Debugging

Tell Claude Code:
```
Use tmux-cli to debug this Python script with pdb.
Step through the authenticate() function and show me the variable values.
```

Claude Code will:
1. Launch a tmux pane with pdb
2. Set breakpoints
3. Step through code
4. Examine variables
5. Report findings

### tmux-cli: Spawn Claude Instances

Tell Claude Code:
```
Launch another Claude Code instance in tmux to review the UserService class
for potential security issues.
```

### Session Search

```bash
# Find all sessions about authentication
fs "auth,login"

# Show all recent sessions
fs -g

# Find Claude sessions in current project
fcs "bug,fix"
```

### Vault: .env Backup

```bash
# First time: encrypt current .env
cd ~/my-project
vault encrypt

# On another machine: restore .env
cd ~/my-project
vault decrypt

# Keep in sync
vault sync  # Auto-detects direction
```

### env-safe: Safe Inspection

```bash
# List all environment keys
env-safe list

# Check if specific key exists
env-safe check DATABASE_URL

# See which are defined
env-safe list --status
```

## Safety Hook Behavior

### When Claude Code Tries to:

**Read a large file:**
```
❌ Blocked: file.py is 1500 lines
💡 Suggestion: Read specific sections or use Grep tool
```

**Delete files:**
```
❌ Blocked: rm command not allowed
💡 Suggestion: Move to TRASH/ directory instead
```

**Stage everything with git:**
```
❌ Blocked: git add . is dangerous
💡 Use: git add <specific-files>
```

**Read .env file:**
```
❌ Blocked: Direct .env access not allowed
💡 Use: env-safe list --status
```

## Troubleshooting

### tmux-cli not found after install
```bash
# Ensure uv tools are in PATH
export PATH="$HOME/.local/bin:$PATH"

# Or reinstall
uv tool install --force claude-code-tools
```

### Hooks not working
1. Check Claude settings contain hooks configuration
2. Verify paths in settings point to actual repository location
3. Restart Claude Code
4. Check hook scripts are executable: `ls -la ~/git/claude-code-tools/hooks/`

### vault requires SOPS
```bash
# macOS
brew install sops

# Linux
# See: https://github.com/mozilla/sops
```

### lmsh not available
Requires Rust/Cargo:
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install lmsh
cargo install lmsh
```

## Configuration

### Hooks Location

Installed to: `~/.claude/hooks/claude-code-tools/`

Configuration in: `~/.claude/settings.json`

### Customize Hooks

Edit hooks in `~/.claude/hooks/claude-code-tools/`:
- `bash_hook.py` - Bash command safety
- `env_file_protection_hook.py` - .env protection
- `file_size_conditional_hook.py` - Large file blocking
- `git_*.py` - Git safety hooks

See [hooks/README.md](https://github.com/pchalasani/claude-code-tools/tree/main/hooks) for details.

### Session Search Config

Optional: `~/.config/find-session/config.json`

```json
{
  "agents": [
    {
      "name": "claude",
      "display_name": "Claude",
      "home_dir": "~/.claude",
      "enabled": true
    }
  ]
}
```

## Documentation

- [tmux-cli detailed guide](https://github.com/pchalasani/claude-code-tools/blob/main/docs/tmux-cli-instructions.md)
- [vault documentation](https://github.com/pchalasani/claude-code-tools/blob/main/docs/vault-documentation.md)
- [find-claude-session guide](https://github.com/pchalasani/claude-code-tools/blob/main/docs/find-claude-session.md)
- [Hooks README](https://github.com/pchalasani/claude-code-tools/tree/main/hooks)

## Updating

```bash
# Update tools from PyPI
uv tool install --upgrade claude-code-tools

# Update hooks
cd ~/.claude/marketplace/hal-9000/plugins/claude-code-tools
./install.sh  # Re-run to update hooks from GitHub
```

## Uninstalling

```bash
# Remove tools
uv tool uninstall claude-code-tools

# Remove hooks from Claude settings
# Edit ~/.claude/settings.json and remove "hooks" section

# Remove downloaded hooks
rm -rf ~/.claude/hooks/claude-code-tools

# Remove shell functions from ~/.bashrc or ~/.zshrc
```

## Credits

Original project: [pchalasani/claude-code-tools](https://github.com/pchalasani/claude-code-tools)

License: MIT
