#!/usr/bin/env bash
# release.sh - Create a new release for hal-9000
#
# This script updates version numbers and creates a git tag.
# GitHub Actions automatically builds and pushes Docker images on tag push.
#
# Usage:
#   ./release.sh <version>           # Dry run - show what would change
#   ./release.sh <version> --execute # Actually perform the release
#
# Example:
#   ./release.sh 1.3.0               # Preview changes for 1.3.0
#   ./release.sh 1.3.0 --execute     # Release 1.3.0
#
# What happens:
#   1. Updates version in all relevant files
#   2. Updates CHANGELOG.md with release date
#   3. Commits changes and creates git tag
#   4. Pushes to GitHub (triggers GitHub Actions)
#   5. GitHub Actions builds and pushes all Docker images
#   6. GitHub Actions creates a GitHub Release

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Files that contain version strings
readonly VERSION_FILES=(
    "$REPO_ROOT/README.md"
    "$REPO_ROOT/.claude-plugin/marketplace.json"
    "$SCRIPT_DIR/.claude-plugin/plugin.json"
    "$SCRIPT_DIR/README.md"
    "$SCRIPT_DIR/docker/README.md"
    "$SCRIPT_DIR/docker/build-profiles.sh"
    "$SCRIPT_DIR/docker/Dockerfile.hal9000"
    "$SCRIPT_DIR/aod/README.md"
)

show_help() {
    cat <<EOF
${BLUE}hal-9000 Release Process${NC}

${GREEN}Usage:${NC}
  ./release.sh <version>             Preview changes (dry run)
  ./release.sh <version> --execute   Perform the release

${GREEN}Steps performed:${NC}
  1. Validate version format (semver)
  2. Update version in all files
  3. Update CHANGELOG.md with release date
  4. Commit changes with release message
  5. Create git tag v<version>
  6. Push to GitHub (triggers GitHub Actions)

${GREEN}GitHub Actions then:${NC}
  - Builds Docker images (base, python, node, java) for amd64 + arm64
  - Pushes to ghcr.io/hellblazer/hal-9000
  - Creates GitHub Release with changelog

${GREEN}Files updated:${NC}
EOF
    for f in "${VERSION_FILES[@]}"; do
        echo "  - ${f#$REPO_ROOT/}"
    done
    cat <<EOF

${GREEN}Example:${NC}
  ./release.sh 1.3.0           # Preview
  ./release.sh 1.3.0 --execute # Release

EOF
}

get_current_version() {
    grep '"version"' "$SCRIPT_DIR/.claude-plugin/plugin.json" | head -1 | sed 's/.*"\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/'
}

validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format '$version'. Use semver (e.g., 1.2.3)${NC}" >&2
        exit 1
    fi
}

check_prerequisites() {
    local missing=()

    command -v docker >/dev/null || missing+=("docker")
    command -v git >/dev/null || missing+=("git")
    command -v sed >/dev/null || missing+=("sed")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required tools: ${missing[*]}${NC}" >&2
        exit 1
    fi

    # Check Docker is running
    if ! docker ps >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running${NC}" >&2
        exit 1
    fi

    # Check we're on main branch
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current)
    if [[ "$branch" != "main" ]]; then
        echo -e "${YELLOW}Warning: Not on main branch (currently on '$branch')${NC}" >&2
    fi

    # Check for uncommitted changes
    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
        echo -e "${YELLOW}Warning: Uncommitted changes exist${NC}" >&2
    fi
}

update_version_in_files() {
    local old_version="$1"
    local new_version="$2"
    local dry_run="$3"

    echo -e "\n${BLUE}Updating version: ${old_version} → ${new_version}${NC}\n"

    for file in "${VERSION_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "  ${YELLOW}⚠ File not found: ${file#$REPO_ROOT/}${NC}"
            continue
        fi

        local relative_path="${file#$REPO_ROOT/}"

        if grep -q "$old_version" "$file"; then
            if [[ "$dry_run" == "true" ]]; then
                echo -e "  ${CYAN}Would update:${NC} $relative_path"
            else
                # Use different sed syntax for macOS vs Linux
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s/$old_version/$new_version/g" "$file"
                else
                    sed -i "s/$old_version/$new_version/g" "$file"
                fi
                echo -e "  ${GREEN}✓ Updated:${NC} $relative_path"
            fi
        else
            echo -e "  ${YELLOW}– No change:${NC} $relative_path (version not found)"
        fi
    done
}

update_changelog() {
    local version="$1"
    local dry_run="$2"
    local changelog="$SCRIPT_DIR/CHANGELOG.md"
    local today
    today=$(date +%Y-%m-%d)

    if [[ "$dry_run" == "true" ]]; then
        echo -e "\n${CYAN}Would update CHANGELOG.md with release date: $today${NC}"
    else
        # Update "Unreleased" or version without date to have today's date
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/## \[$version\].*/## [$version] - $today/" "$changelog"
        else
            sed -i "s/## \[$version\].*/## [$version] - $today/" "$changelog"
        fi
        echo -e "\n${GREEN}✓ Updated CHANGELOG.md with release date${NC}"
    fi
}

git_commit_and_tag() {
    local version="$1"
    local dry_run="$2"

    if [[ "$dry_run" == "true" ]]; then
        echo -e "\n${CYAN}Would commit and tag:${NC}"
        echo -e "  git add -A"
        echo -e "  git commit -m 'Release v$version'"
        echo -e "  git tag -a v$version -m 'Release v$version'"
    else
        echo -e "\n${BLUE}Committing and tagging...${NC}"
        git -C "$REPO_ROOT" add -A
        git -C "$REPO_ROOT" commit -m "Release v$version"
        git -C "$REPO_ROOT" tag -a "v$version" -m "Release v$version"
        echo -e "${GREEN}✓ Created commit and tag v$version${NC}"
    fi
}

push_git() {
    local version="$1"
    local dry_run="$2"

    if [[ "$dry_run" == "true" ]]; then
        echo -e "\n${CYAN}Would push to GitHub:${NC}"
        echo -e "  git push origin main"
        echo -e "  git push origin v$version"
    else
        echo -e "\n${BLUE}Pushing to GitHub...${NC}"
        git -C "$REPO_ROOT" push origin main
        git -C "$REPO_ROOT" push origin "v$version"
        echo -e "${GREEN}✓ Pushed commits and tag to GitHub${NC}"
    fi
}

main() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    local new_version="$1"
    local execute="false"

    if [[ "${2:-}" == "--execute" ]]; then
        execute="true"
    fi

    local dry_run="true"
    [[ "$execute" == "true" ]] && dry_run="false"

    validate_version "$new_version"
    check_prerequisites

    local current_version
    current_version=$(get_current_version)

    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN - No changes will be made${NC}"
    else
        echo -e "${GREEN}EXECUTING RELEASE${NC}"
    fi
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "Current version: ${current_version}"
    echo -e "New version:     ${new_version}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"

    # Step 1: Update version in files
    update_version_in_files "$current_version" "$new_version" "$dry_run"

    # Step 2: Update changelog
    update_changelog "$new_version" "$dry_run"

    # Step 3: Git commit and tag
    git_commit_and_tag "$new_version" "$dry_run"

    # Step 4: Push git (triggers GitHub Actions for Docker build)
    push_git "$new_version" "$dry_run"

    # Note about GitHub Actions
    if [[ "$dry_run" == "false" ]]; then
        echo -e "\n${CYAN}GitHub Actions will now:${NC}"
        echo -e "  • Build Docker images (base, python, node, java)"
        echo -e "  • Push to ghcr.io/hellblazer/hal-9000"
        echo -e "  • Create GitHub Release"
        echo -e "\n${CYAN}Monitor progress:${NC}"
        echo -e "  https://github.com/Hellblazer/hal-9000/actions"
    fi

    echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
        echo -e "\nTo execute this release, run:"
        echo -e "  ${GREEN}./release.sh $new_version --execute${NC}"
    else
        echo -e "${GREEN}RELEASE v$new_version COMPLETE!${NC}"
        echo -e "\nVerify at:"
        echo -e "  https://github.com/Hellblazer/hal-9000/releases/tag/v$new_version"
        echo -e "  https://github.com/Hellblazer/hal-9000/pkgs/container/hal-9000"
    fi
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
}

main "$@"
