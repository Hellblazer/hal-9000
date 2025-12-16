#!/usr/bin/env bash
# Common functions for MCP server installers

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Get Claude Code config path
# Claude Code (CLI) uses ~/.claude.json for MCP server configuration
# This is different from Claude Desktop which uses ~/Library/Application Support/Claude/
get_claude_config_path() {
    local config_path="$HOME/.claude.json"
    echo "$config_path"
}

# Create backup of Claude config
backup_config() {
    local config_file=$1
    local backup_file="${config_file}.backup-$(date +%Y%m%d-%H%M%S)"

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file"
        echo "$backup_file"
        return 0
    fi
    return 1
}

# Deep merge MCP server configuration into Claude config
# Uses jq to properly merge mcpServers objects without overwriting existing servers
merge_mcp_config() {
    local claude_config=$1
    local mcp_config_json=$2
    local server_name=$3

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required for config merging${NC}" >&2
        echo -e "${YELLOW}Install with: brew install jq (macOS) or apt-get install jq (Linux)${NC}" >&2
        return 1
    fi

    local tmp_config
    tmp_config=$(mktemp)

    # Deep merge: preserve existing mcpServers, add/update only our server
    if jq --argjson new "$mcp_config_json" \
          '.mcpServers = (.mcpServers // {}) * $new.mcpServers' \
          "$claude_config" > "$tmp_config" 2>/dev/null; then
        mv "$tmp_config" "$claude_config"
        return 0
    else
        rm -f "$tmp_config"
        echo -e "${RED}Error: Failed to merge configuration${NC}" >&2
        return 1
    fi
}

# Check if MCP server already configured
is_mcp_server_configured() {
    local config_file=$1
    local server_name=$2

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        return 1
    fi

    if jq -e ".mcpServers.\"$server_name\"" "$config_file" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check Python version (requires 3.8+)
check_python_version() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is required but not installed.${NC}" >&2
        return 1
    fi

    local python_version
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)"; then
        echo -e "${RED}Error: Python 3.8+ required. Found: $python_version${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Python $python_version${NC}"
    return 0
}

# Check Node.js version (requires 16+)
check_node_version() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Error: Node.js is required but not installed.${NC}" >&2
        return 1
    fi

    local node_version
    node_version=$(node --version 2>/dev/null | sed 's/v//')

    if ! node -e "process.exit(parseInt(process.version.slice(1)) >= 16 ? 0 : 1)"; then
        echo -e "${RED}Error: Node.js 16+ required. Found: $node_version${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Node.js $node_version${NC}"
    return 0
}

# Update PATH in shell config if needed
update_path_if_needed() {
    local bin_dir=$1
    local shell_config

    # Determine shell config file
    if [[ "$SHELL" == */zsh ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        shell_config="$HOME/.bashrc"
    else
        return 0  # Unknown shell, skip
    fi

    # Check if already in PATH
    if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        return 0
    fi

    # Check if already in config file
    if [[ -f "$shell_config" ]] && grep -q "export PATH=.*$bin_dir" "$shell_config"; then
        return 0
    fi

    # Offer to add to PATH
    echo ""
    echo -e "${YELLOW}The directory $bin_dir is not in your PATH.${NC}"
    read -rp "Add to $shell_config automatically? (y/N): " add_path

    if [[ "$add_path" =~ ^[Yy]$ ]]; then
        echo "" >> "$shell_config"
        echo "# Added by HAL-9000 installer" >> "$shell_config"
        echo "export PATH=\"$bin_dir:\$PATH\"" >> "$shell_config"
        echo -e "${GREEN}✓ Added to $shell_config${NC}"
        echo -e "${YELLOW}Note: Restart your terminal or run: source $shell_config${NC}"
    else
        echo ""
        echo -e "${YELLOW}To add manually, add this line to your $shell_config:${NC}"
        echo "export PATH=\"$bin_dir:\$PATH\""
    fi
    echo ""
}

# Get Python user base bin directory
get_python_bin_dir() {
    if ! command -v python3 &> /dev/null; then
        return 1
    fi

    python3 -m site --user-base 2>/dev/null | sed 's|$|/bin|'
}

# Check if command exists and is executable
check_command() {
    local cmd=$1
    local install_hint=$2

    if command -v "$cmd" &> /dev/null; then
        return 0
    fi

    echo -e "${RED}Error: $cmd is not installed${NC}" >&2
    if [[ -n "$install_hint" ]]; then
        echo -e "${YELLOW}$install_hint${NC}" >&2
    fi
    return 1
}

# Secure download with TLS 1.2+
secure_download() {
    local url=$1
    local output=$2

    if ! curl --tlsv1.2 -fsSL "$url" -o "$output"; then
        echo -e "${RED}Error: Failed to download from $url${NC}" >&2
        rm -f "$output"
        return 1
    fi
    return 0
}

# Check if running in hal9000 container
is_hal9000_container() {
    [[ -f /.dockerenv ]] || [[ -f /hal-9000/setup.sh ]]
}

# Check if system has PEP 668 externally-managed-environment protection
has_pep668_protection() {
    if ! command -v python3 &> /dev/null; then
        return 1
    fi

    # Check for EXTERNALLY-MANAGED marker file
    # The file is located at <prefix>/lib/python<version>/EXTERNALLY-MANAGED
    local marker_file
    marker_file=$(python3 -c 'import sys; import os; print(os.path.join(sys.prefix, "lib", f"python{sys.version_info.major}.{sys.version_info.minor}", "EXTERNALLY-MANAGED"))' 2>/dev/null)

    if [[ -f "$marker_file" ]]; then
        return 0
    fi

    # Fallback: Test with a dummy install attempt
    if pip3 install --dry-run --user pip 2>&1 | grep -q "externally-managed-environment"; then
        return 0
    fi

    return 1
}

# Safe pip install that handles PEP 668 protection
# Usage: safe_pip_install [pip_flags...] package1 [package2 ...]
# Examples:
#   safe_pip_install package1 package2
#   safe_pip_install -r requirements.txt
#   safe_pip_install --quiet package1
safe_pip_install() {
    local args=("$@")

    if [[ ${#args[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No packages specified for installation${NC}" >&2
        return 1
    fi

    # Check if pip3 exists
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}Error: pip3 is required but not installed.${NC}" >&2
        return 1
    fi

    local base_flags="--user"

    # Detect and handle PEP 668 protection
    if has_pep668_protection; then
        echo -e "${YELLOW}Detected PEP 668 protected environment${NC}"
        echo -e "${BLUE}Using --break-system-packages flag for installation${NC}"
        base_flags="--user --break-system-packages"
    fi

    # Install packages with all provided arguments
    if pip3 install $base_flags "${args[@]}"; then
        return 0
    else
        echo -e "${RED}Error: Failed to install packages${NC}" >&2
        return 1
    fi
}

# Export functions for sourcing
export -f get_claude_config_path
export -f backup_config
export -f merge_mcp_config
export -f is_mcp_server_configured
export -f check_python_version
export -f check_node_version
export -f update_path_if_needed
export -f get_python_bin_dir
export -f check_command
export -f secure_download
export -f is_hal9000_container
export -f has_pep668_protection
export -f safe_pip_install
