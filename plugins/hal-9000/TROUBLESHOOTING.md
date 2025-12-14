# HAL-9000 Installation Troubleshooting Guide

This guide addresses common installation issues and provides solutions for different environments.

## Table of Contents
- [PEP 668 Externally-Managed Environment](#pep-668-externally-managed-environment)
- [Python Package Installation Issues](#python-package-installation-issues)
- [Path Configuration](#path-configuration)
- [Platform-Specific Issues](#platform-specific-issues)
- [Testing Installation](#testing-installation)

---

## PEP 668 Externally-Managed Environment

### Problem
Installation fails on modern Debian/Ubuntu systems with:
```
error: externally-managed-environment
× This environment is externally managed
```

### Cause
Python 3.11+ on Debian Bookworm, Ubuntu 23.04+, and other modern Linux distributions implement [PEP 668](https://peps.python.org/pep-0668/), which prevents system-wide pip installations to avoid conflicts with system package managers.

### Solution (Automatic)
**The hal-9000 installer now handles this automatically!**

The installer detects PEP 668 protection and applies the `--break-system-packages` flag when needed. You should see:
```
Detected PEP 668 protected environment
Using --break-system-packages flag for installation
```

### Solution (Manual)
If you encounter issues or need to install manually:

```bash
# Option 1: Use the --break-system-packages flag
pip3 install --user --break-system-packages chroma-mcp

# Option 2: Use pipx (recommended for CLI tools)
sudo apt install pipx
pipx install chroma-mcp

# Option 3: Create a virtual environment
python3 -m venv ~/hal-9000-env
source ~/hal-9000-env/bin/activate
pip install chroma-mcp
```

### Affected Distributions
- Debian 12 (Bookworm) and newer
- Ubuntu 23.04 and newer
- Fedora 38 and newer
- Any distribution with Python 3.11+ and PEP 668 enabled

---

## Python Package Installation Issues

### Missing pip3
**Error:** `pip3: command not found`

**Solution:**
```bash
# Debian/Ubuntu
sudo apt-get install python3-pip

# macOS
brew install python3

# Fedora/RHEL
sudo dnf install python3-pip
```

### Permission Denied
**Error:** `Permission denied` when installing packages

**Solution:**
Always use the `--user` flag (automatically handled by hal-9000 installer):
```bash
pip3 install --user package-name
```

### Outdated pip
**Error:** Various installation failures

**Solution:**
```bash
python3 -m pip install --upgrade pip
```

---

## Path Configuration

### Scripts Not Found After Installation
**Error:** `command not found: chroma-mcp` (or other installed scripts)

**Cause:** Python user bin directory is not in your PATH.

**Solution:**

1. **Identify the Python bin directory:**
   ```bash
   python3 -m site --user-base
   # Output example: /Users/username/.local
   # Bin directory: /Users/username/.local/bin
   ```

2. **Add to PATH (the installer can do this automatically):**

   For **zsh** (default on macOS):
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

   For **bash**:
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Verify:**
   ```bash
   which chroma-mcp
   # Should output: /Users/username/.local/bin/chroma-mcp
   ```

---

## Platform-Specific Issues

### macOS

#### Missing Command Line Tools
**Error:** `xcrun: error: invalid active developer path`

**Solution:**
```bash
xcode-select --install
```

#### Homebrew Python Issues
If using Homebrew Python, ensure it's in your PATH:
```bash
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
```

### Linux

#### Missing Build Dependencies
**Error:** Compilation errors during package installation

**Solution:**
```bash
# Debian/Ubuntu
sudo apt-get install build-essential python3-dev

# Fedora/RHEL
sudo dnf install gcc python3-devel

# Arch
sudo pacman -S base-devel python
```

### Docker/Containers

#### Root User Warning
**Warning:** `Running pip as the 'root' user...`

**Note:** This warning is informational in containers and can be ignored. The hal-9000 installer handles container environments correctly.

#### Container Image Recommendations
For testing hal-9000 in containers:
- Use `debian:bookworm-slim` or `ubuntu:24.04` for modern PEP 668 testing
- Install prerequisites: `apt-get install -y python3 python3-pip nodejs npm git`
- The installer's PEP 668 handling works automatically in containers

---

## Testing Installation

### Verify MCP Server Installation

```bash
# Check if servers are installed
which chroma-mcp
which memory-bank-server

# Test server execution
chroma-mcp --help
memory-bank-server --help
```

### Verify Claude Config

```bash
# macOS
cat "$HOME/Library/Application Support/Claude/claude_desktop_config.json" | jq '.mcpServers'

# Linux
cat ~/.config/Claude/claude_desktop_config.json | jq '.mcpServers'
```

### Test in Isolated Environment

You can test hal-9000 installation safely using Docker:

```bash
cd /path/to/hal-9000
docker run -it --rm -v $(pwd):/workspace -w /workspace debian:bookworm-slim bash

# Inside container:
apt-get update && apt-get install -y python3 python3-pip nodejs npm git
echo "2" | ./plugins/hal-9000/install.sh
```

---

## Common Error Messages

### "ModuleNotFoundError"
**Cause:** Package not installed correctly or not in Python path

**Solution:**
```bash
# Reinstall the package
pip3 install --user --force-reinstall package-name

# Verify installation
pip3 show package-name
```

### "ImportError: cannot import name"
**Cause:** Version conflict or incompatible dependencies

**Solution:**
```bash
# Check installed versions
pip3 list | grep package-name

# Upgrade dependencies
pip3 install --user --upgrade package-name
```

### "SSL Certificate Error"
**Cause:** Outdated certificates or corporate proxy

**Solution:**
```bash
# Update certificates (macOS)
pip3 install --user --upgrade certifi

# Or bypass SSL (not recommended for production)
pip3 install --user --trusted-host pypi.org --trusted-host files.pythonhosted.org package-name
```

---

## Getting Help

If you continue to experience issues:

1. **Check the logs** - Installation output contains detailed error messages
2. **Verify prerequisites** - Ensure Python 3.8+, Node.js 16+, and pip3 are installed
3. **Test manually** - Try installing individual MCP servers using the `safe_pip_install` function
4. **Report issues** - Open an issue at the hal-9000 repository with:
   - Operating system and version
   - Python version (`python3 --version`)
   - Complete error message
   - Installation command used

---

## Technical Details

### How PEP 668 Detection Works

The hal-9000 installer includes automatic PEP 668 detection in `common.sh`:

```bash
# Check for EXTERNALLY-MANAGED marker file
python_lib=$(python3 -c 'import sys; print(sys.prefix)')
if [[ -f "$python_lib/EXTERNALLY-MANAGED" ]]; then
    # Apply --break-system-packages flag
fi
```

### Safe Installation Function

All Python MCP servers use the `safe_pip_install` function which:
1. Detects PEP 668 protection
2. Applies appropriate flags automatically
3. Handles both packages and requirements files
4. Provides clear user feedback

Usage:
```bash
# In an installer script
source "../common.sh"
safe_pip_install package-name
safe_pip_install -r requirements.txt
safe_pip_install --quiet package-name
```

---

## Version History

- **v1.1.0** - Added automatic PEP 668 detection and handling
- **v1.0.0** - Initial release

---

*Last updated: December 2024*
