# ClaudeBox Plugin

Docker-based development environment for Claude Code with containerized isolation, pre-configured language profiles, and multi-instance support.

## What is ClaudeBox?

ClaudeBox runs Claude Code inside Docker containers, providing:

- **Complete Isolation**: Each project runs in its own container
- **Reproducible Environments**: Pre-configured dev stacks (Python, Rust, Go, C/C++, etc.)
- **Multi-Instance Support**: Work on multiple projects simultaneously
- **Squad Mode**: Launch multiple Claude instances in parallel (multi-agent workflows)
- **Persistent State**: Auth, history, and configs preserved between sessions
- **Security**: Network isolation with project-specific firewall allowlists

## Features

### Development Profiles

Pre-configured language stacks ready to use:

- **Python**: Python 3.11+ with uv, pytest, black
- **Rust**: Latest Rust toolchain with cargo
- **Go**: Go 1.21+ with common tools
- **C/C++**: GCC/Clang, CMake, Make
- **Node.js**: Node 20+ with npm/yarn
- **Java**: JDK 21+ with Maven/Gradle
- **All**: Full polyglot environment

### Project Isolation

Each project gets its own:
- Docker image and container
- Claude authentication state
- Shell history
- Tool configurations
- Network allowlist (firewall)

### Squad Mode

Launch multiple Claude instances for parallel work:
- Define agents in configuration file
- Each agent works on specific task
- Tmux-based session management
- Easy attach/detach/monitor
- Centralized cleanup

### Developer Tools

Included in all profiles:
- GitHub CLI (`gh`)
- Delta (enhanced diff)
- fzf (fuzzy finder)
- zsh with oh-my-zsh + powerline
- Syntax highlighting
- Auto-suggestions

## Installation

### From hal-9000 Marketplace

1. Add hal-9000 marketplace to Claude Code
2. Install claudebox plugin
3. Run installation script:
   ```bash
   cd ~/.claude/marketplace/hal-9000/plugins/claudebox
   ./install.sh
   ```

### Installation Methods

The installer offers three methods:

**1. Homebrew (Recommended)**
- Installs via `brew install claudebox`
- Automatic dependency management
- Easy updates with `brew upgrade claudebox`

**2. Self-Extracting Installer**
- Downloads latest `.run` file from GitHub releases
- Single-file installation
- Extracts to `~/.claudebox/source/`
- Creates symlink in `~/.local/bin/`

**3. Archive Installation**
- Downloads `.tar.gz` from GitHub releases
- Manual extraction to custom location
- Full control over installation directory

### What the Installer Does

**Dependency Checks:**
- Docker (required) - Offers to install Docker Desktop via Homebrew
- tmux (required for squad mode)
- bash (required)

**Installation Process:**
- Checks Docker daemon is running
- Installs claudebox via chosen method
- Creates symlinks for all commands
- Verifies installation
- Shows next steps

**No Git Clone Required** - Everything via package managers or GitHub releases!

## Requirements

### Required
- **Docker**: Docker Desktop (macOS) or Docker Engine (Linux)
- **bash**: Shell interpreter
- **Linux or macOS**: Native Linux, macOS, or WSL2 on Windows

### Optional
- **tmux**: Required for squad mode
- **gh**: GitHub CLI for PR management

## Usage

### Basic Commands

```bash
# Start ClaudeBox
claudebox run

# Start with specific profile
claudebox run --profile python

# List running containers
claudebox list

# Stop all containers
claudebox stop

# List available profiles
claudebox profiles

# Clean up Docker resources
claudebox clean
```

### Project Profiles

Available development profiles:

```bash
# Python development
claudebox run --profile python

# Rust development
claudebox run --profile rust

# Go development
claudebox run --profile go

# C/C++ development
claudebox run --profile c

# Node.js development
claudebox run --profile node

# Java development
claudebox run --profile java

# Full polyglot environment
claudebox run --profile all
```

### Squad Mode (Multi-Agent)

Create a configuration file defining your agents:

```bash
# Copy example config
cp ~/.claudebox/squad.conf.example ~/my-squad.conf

# Edit configuration
vim ~/my-squad.conf
```

Example `squad.conf`:

```ini
# Project settings
PROJECT_NAME="my-app"
BASE_PROFILE="python"

# Define agents
AGENTS=(
    "backend:Backend API development"
    "frontend:React frontend"
    "tests:Integration testing"
    "docs:Documentation updates"
)
```

Launch and manage squad:

```bash
# Launch squad
claudebox-squad ~/my-squad.conf

# List active sessions
cs-list

# Attach to specific agent
cs-attach squad-my-app-backend

# Stop specific session
cs-stop squad-my-app-backend

# Cleanup all squad sessions
cs-cleanup
```

### Network Allowlist

Manage per-project network access:

```bash
# View current allowlist
claudebox allowlist

# Edit allowlist
claudebox allowlist --edit

# Example allowlist file
echo "github.com" >> .claudebox/allowlist
echo "pypi.org" >> .claudebox/allowlist
```

### Per-Project Configuration

Create `.claudebox/` directory in your project:

```bash
# Project-specific config
mkdir .claudebox

# Allowlist for this project
echo "api.example.com" > .claudebox/allowlist

# Custom Dockerfile
cp ~/.claudebox/templates/python.Dockerfile .claudebox/Dockerfile
# Edit as needed
```

## Advanced Features

### Persistent Data

Each project maintains:
- `~/.claudebox/<project>/auth/` - Claude authentication state
- `~/.claudebox/<project>/history/` - Shell command history
- `~/.claudebox/<project>/config/` - Tool configurations

### Custom Dockerfiles

Extend or customize profiles:

```bash
# Copy base template
claudebox template python > .claudebox/Dockerfile

# Add custom packages
echo "RUN pip install my-package" >> .claudebox/Dockerfile

# Run with custom Dockerfile
claudebox run
```

### Python Virtual Environments

Automatic venv creation for Python projects:

```bash
cd ~/my-python-project
claudebox run --profile python

# Inside container, venv is auto-activated
# .venv/ directory synced with host
```

### Tmux Socket Mounting

ClaudeBox mounts tmux socket for seamless multi-pane workflows:

```bash
# Launch claudebox
claudebox run

# Inside container, tmux works across host/container boundary
tmux ls  # Shows host tmux sessions
```

## Troubleshooting

### Docker not running

```bash
# macOS
open -a Docker

# Linux (systemd)
sudo systemctl start docker

# Check status
docker ps
```

### Permission denied (Docker)

```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER

# Log out and back in for group to take effect
```

### ClaudeBox command not found

```bash
# Check installation
which claudebox

# If not found, add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Container won't start

```bash
# Check Docker logs
docker logs claudebox-<project>

# Clean up and retry
claudebox clean
claudebox run
```

### Squad mode issues

```bash
# Ensure tmux is installed
which tmux

# Install if missing (macOS)
brew install tmux

# Linux
sudo apt-get install tmux
```

## Configuration Files

### Global Config

Located in `~/.claudebox/`:
- `config.yml` - Global ClaudeBox settings
- `templates/` - Dockerfile templates for each profile

### Project Config

Located in `.claudebox/` (project root):
- `Dockerfile` - Custom project Dockerfile
- `allowlist` - Network allowlist for this project
- `config.yml` - Project-specific settings

## Updating

### Homebrew Installation

```bash
brew upgrade claudebox
```

### Self-Extracting/Archive Installation

```bash
# Re-run installer to get latest version
cd ~/.claude/marketplace/hal-9000/plugins/claudebox
./install.sh
```

### Manual Update

```bash
# Download latest release
wget https://github.com/Hellblazer/claudebox/releases/latest/download/claudebox.run
chmod +x claudebox.run
./claudebox.run
```

## Uninstalling

### Homebrew

```bash
brew uninstall claudebox

# Remove project data
rm -rf ~/.claudebox
rm -rf ~/.claudebox-squad
```

### Self-Extracting/Archive

```bash
# Remove symlinks
rm ~/.local/bin/claudebox
rm ~/.local/bin/claudebox-squad
rm ~/.local/bin/cs-*

# Remove installation
rm -rf ~/.claudebox/source

# Remove project data
rm -rf ~/.claudebox
rm -rf ~/.claudebox-squad
```

### Clean Docker Resources

```bash
# Remove ClaudeBox containers
docker ps -a | grep claudebox | awk '{print $1}' | xargs docker rm -f

# Remove ClaudeBox images
docker images | grep claudebox | awk '{print $3}' | xargs docker rmi -f
```

## Use Cases

### Isolated Development

Work on projects with conflicting dependencies:

```bash
# Project A uses Python 3.9
cd ~/project-a
claudebox run --profile python

# Project B uses Python 3.11
cd ~/project-b
claudebox run --profile python

# Each gets its own container with correct version
```

### Multi-Agent Workflows

Parallel development with squad mode:

```bash
# Define 4 agents: backend, frontend, tests, docs
claudebox-squad ~/my-squad.conf

# Each agent works independently
# Monitor progress in separate tmux panes
```

### Reproducible Builds

Share exact environment with team:

```bash
# Commit .claudebox/Dockerfile to git
git add .claudebox/
git commit -m "Add ClaudeBox config"

# Team members run same environment
claudebox run
```

### Secure Isolation

Restricted network access:

```bash
# Only allow specific domains
echo "github.com" > .claudebox/allowlist
echo "pypi.org" >> .claudebox/allowlist

claudebox run
# Container can only access listed domains
```

## Credits

Original project: [Hellblazer/claudebox](https://github.com/Hellblazer/claudebox)

Based on work by [RchGrav/claudebox](https://github.com/RchGrav/claudebox)

License: MIT
