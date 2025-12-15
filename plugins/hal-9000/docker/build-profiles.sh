#!/usr/bin/env bash
# Build and optionally push all HAL-9000 profile images
#
# Usage:
#   ./build-profiles.sh              # Build all profiles
#   ./build-profiles.sh --push       # Build and push to ghcr.io
#   ./build-profiles.sh python node  # Build specific profiles

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_BASE="ghcr.io/hellblazer/hal-9000"
readonly VERSION="1.2.0"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Available profiles
readonly ALL_PROFILES=(
    "base:Dockerfile.hal9000"
    "python:Dockerfile.python"
    "node:Dockerfile.node"
    "java:Dockerfile.java"
)

show_help() {
    cat <<EOF
${BLUE}HAL-9000 Profile Image Builder${NC}

${GREEN}Usage:${NC}
  build-profiles.sh [OPTIONS] [PROFILES...]

${GREEN}Options:${NC}
  --push          Push images to ghcr.io after building
  --no-cache      Build without using cache
  --help          Show this help

${GREEN}Profiles:${NC}
  base            Base image with claude-code-tools only
  python          Python 3.11 + uv + pip
  node            Node.js 20 LTS + npm + yarn + pnpm
  java            Java 21 LTS + Maven + Gradle

${GREEN}Examples:${NC}
  build-profiles.sh                    # Build all profiles
  build-profiles.sh --push             # Build and push all
  build-profiles.sh python node        # Build specific profiles
  build-profiles.sh --push --no-cache  # Rebuild and push all

${GREEN}Images Created:${NC}
  ${IMAGE_BASE}:latest       (base)
  ${IMAGE_BASE}:python
  ${IMAGE_BASE}:node
  ${IMAGE_BASE}:java

EOF
}

build_profile() {
    local profile="$1"
    local dockerfile="$2"
    local push="${3:-false}"
    local no_cache="${4:-false}"

    local tag="${IMAGE_BASE}:${profile}"
    local cache_flag=""

    [[ "$no_cache" == "true" ]] && cache_flag="--no-cache"

    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Building: ${tag}${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"

    # Build image
    if docker build $cache_flag \
        -f "$SCRIPT_DIR/$dockerfile" \
        -t "$tag" \
        -t "${IMAGE_BASE}:${profile}-${VERSION}" \
        "$SCRIPT_DIR/.."; then

        echo -e "${GREEN}✓ Built: ${tag}${NC}"

        # Push if requested
        if [[ "$push" == "true" ]]; then
            echo -e "${BLUE}Pushing: ${tag}${NC}"
            docker push "$tag"
            docker push "${IMAGE_BASE}:${profile}-${VERSION}"
            echo -e "${GREEN}✓ Pushed: ${tag}${NC}"
        fi
    else
        echo -e "${YELLOW}✗ Failed to build: ${tag}${NC}"
        return 1
    fi

    echo ""
}

main() {
    local push="false"
    local no_cache="false"
    local selected_profiles=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --push)
                push="true"
                shift
                ;;
            --no-cache)
                no_cache="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                selected_profiles+=("$1")
                shift
                ;;
        esac
    done

    # If no profiles specified, build all
    if [[ ${#selected_profiles[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No profiles specified, building all...${NC}\n"
        for profile_def in "${ALL_PROFILES[@]}"; do
            IFS=':' read -r profile dockerfile <<< "$profile_def"
            selected_profiles+=("$profile")
        done
    fi

    # Validate and build each profile
    local built_count=0
    local failed_count=0

    for requested_profile in "${selected_profiles[@]}"; do
        local found="false"

        for profile_def in "${ALL_PROFILES[@]}"; do
            IFS=':' read -r profile dockerfile <<< "$profile_def"

            if [[ "$profile" == "$requested_profile" ]]; then
                found="true"

                if build_profile "$profile" "$dockerfile" "$push" "$no_cache"; then
                    ((built_count++))
                else
                    ((failed_count++))
                fi
                break
            fi
        done

        if [[ "$found" == "false" ]]; then
            echo -e "${YELLOW}Warning: Unknown profile '$requested_profile'${NC}\n"
        fi
    done

    # Summary
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Built: ${built_count}${NC}"
    [[ $failed_count -gt 0 ]] && echo -e "${YELLOW}✗ Failed: ${failed_count}${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

main "$@"
