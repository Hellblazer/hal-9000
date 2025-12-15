#!/usr/bin/env bash
# aod-init.sh - Generate aod configuration templates
#
# Usage: ./aod-init.sh [--yaml|--simple] [output_file]

set -Eeuo pipefail

readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

show_help() {
    cat <<EOF
${CYAN}aod-init${NC} - Generate aod configuration templates

${GREEN}Usage:${NC}
  aod-init [OPTIONS] [output_file]

${GREEN}Options:${NC}
  --yaml        Generate YAML format config (recommended)
  --simple      Generate simple colon-separated format
  --help        Show this help message

${GREEN}Examples:${NC}
  aod-init                    # Interactive prompts, writes to aod.conf
  aod-init --yaml tasks.yml   # Generate YAML config
  aod-init --simple aod.conf  # Generate simple format

${GREEN}Formats:${NC}

  ${YELLOW}YAML (Recommended):${NC}
    tasks:
      - branch: feature/auth
        profile: python
        description: Add OAuth2 authentication

      - branch: feature/api
        profile: node
        description: Build REST API endpoints

  ${YELLOW}Simple (Colon-separated):${NC}
    feature/auth:python:Add OAuth2 authentication
    feature/api:node:Build REST API endpoints

${GREEN}Available Profiles:${NC}
  python, node, java, go, rust, ruby, php, default

EOF
}

generate_yaml() {
    local output_file="${1:-aod.yml}"

    cat > "$output_file" <<'EOF'
# aod Configuration (YAML format)
#
# Each task creates:
#   - Git worktree for the branch
#   - Isolated ClaudeBox container
#   - Dedicated tmux session
#
# Available profiles: python, node, java, go, rust, ruby, php, default

tasks:
  # Example: Authentication feature
  - branch: feature/auth
    profile: python
    description: Add OAuth2 authentication with JWT tokens

  # Example: REST API development
  - branch: feature/api
    profile: node
    description: Build REST API endpoints for user management

  # Example: Bug fix
  - branch: bugfix/validation
    profile: python
    description: Fix input validation in registration form

# Tips:
#   - Keep branch names short but descriptive
#   - Profile determines container environment (languages, tools)
#   - Description appears in session list and CLAUDE.md
#   - Use consistent naming: feature/, bugfix/, refactor/, etc.
EOF

    printf "${GREEN}✓${NC} Created YAML config: ${CYAN}%s${NC}\n" "$output_file"
    printf "\n${YELLOW}Next steps:${NC}\n"
    printf "  1. Edit the config file to add your tasks\n"
    printf "  2. Run: ${CYAN}aod %s${NC}\n" "$output_file"
}

generate_simple() {
    local output_file="${1:-aod.conf}"

    cat > "$output_file" <<'EOF'
# aod Configuration (Simple format)
#
# Format: branch:profile:description
#
# Each task creates:
#   - Git worktree for the branch
#   - Isolated ClaudeBox container
#   - Dedicated tmux session
#
# Available profiles: python, node, java, go, rust, ruby, php, default

# Example: Authentication feature
feature/auth:python:Add OAuth2 authentication with JWT tokens

# Example: REST API development
feature/api:node:Build REST API endpoints for user management

# Example: Bug fix
bugfix/validation:python:Fix input validation in registration form

# Tips:
#   - Lines starting with # are comments
#   - Keep branch names short but descriptive
#   - Profile determines container environment (languages, tools)
#   - Description appears in session list and CLAUDE.md
#   - Use consistent naming: feature/, bugfix/, refactor/, etc.
EOF

    printf "${GREEN}✓${NC} Created simple config: ${CYAN}%s${NC}\n" "$output_file"
    printf "\n${YELLOW}Next steps:${NC}\n"
    printf "  1. Edit the config file to add your tasks\n"
    printf "  2. Run: ${CYAN}aod %s${NC}\n" "$output_file"
}

interactive() {
    printf "${CYAN}╔════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║   aod Configuration Generator          ║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════╝${NC}\n\n"

    printf "Choose format:\n"
    printf "  ${GREEN}1)${NC} YAML (recommended - more readable)\n"
    printf "  ${GREEN}2)${NC} Simple (colon-separated)\n\n"

    read -p "Select format [1]: " format
    format="${format:-1}"

    read -p "Output file [aod.conf]: " output
    output="${output:-aod.conf}"

    echo ""

    case "$format" in
        1)
            # Default to .yml extension for YAML
            [[ "$output" == "aod.conf" ]] && output="aod.yml"
            generate_yaml "$output"
            ;;
        2)
            generate_simple "$output"
            ;;
        *)
            printf "${YELLOW}Invalid choice, using YAML${NC}\n"
            generate_yaml "$output"
            ;;
    esac
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --yaml)
            generate_yaml "${2:-aod.yml}"
            ;;
        --simple)
            generate_simple "${2:-aod.conf}"
            ;;
        "")
            interactive
            ;;
        *)
            # Assume it's an output filename
            if [[ "$1" =~ \.(yml|yaml)$ ]]; then
                generate_yaml "$1"
            else
                generate_simple "$1"
            fi
            ;;
    esac
}

main "$@"
