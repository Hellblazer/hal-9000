#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
HAL_COMMANDS=("check.md" "load.md" "session-delete.md" "sessions.md")
HAL_AGENTS=("java-developer.md" "java-architect-planner.md" "java-debugger.md" "code-review-expert.md" "plan-auditor.md" "deep-analyst.md" "codebase-deep-analyzer.md" "deep-research-synthesizer.md" "deep-thinker.md" "cli-controller.md" "bead-master.md" "beads-auditor.md")

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║       HAL-9000 Claude Marketplace Uninstaller     ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will remove:${NC}"
echo "  - Commands (check, load, sessions, session-delete)"
echo "  - Custom agents (12 specialized agents)"
echo "  - Backup directories"
echo ""
echo -e "${YELLOW}MCP servers must be removed manually from Claude's config.${NC}"
echo ""
read -rp "Continue? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Removing commands...${NC}"

removed_count=0
for cmd in "${HAL_COMMANDS[@]}"; do
    cmd_path="$CLAUDE_COMMANDS_DIR/$cmd"
    if [[ -f "$cmd_path" ]]; then
        rm "$cmd_path"
        echo "  ✓ Removed $cmd"
        ((removed_count++))
    fi
done

echo ""
if [[ $removed_count -gt 0 ]]; then
    echo -e "${GREEN}✓ Removed $removed_count command(s)${NC}"
else
    echo -e "${YELLOW}No HAL-9000 commands found${NC}"
fi

# Remove custom agents
echo ""
echo -e "${YELLOW}Removing custom agents...${NC}"

removed_agents=0
for agent in "${HAL_AGENTS[@]}"; do
    agent_path="$CLAUDE_AGENTS_DIR/$agent"
    if [[ -f "$agent_path" ]]; then
        rm "$agent_path"
        echo "  ✓ Removed $agent"
        ((removed_agents++))
    fi
done

echo ""
if [[ $removed_agents -gt 0 ]]; then
    echo -e "${GREEN}✓ Removed $removed_agents agent(s)${NC}"
else
    echo -e "${YELLOW}No HAL-9000 agents found${NC}"
fi

echo ""
echo -e "${YELLOW}To remove MCP servers:${NC}"
echo "1. Edit your Claude config file:"
echo "   - macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "   - Linux: ~/.config/Claude/claude_desktop_config.json"
echo "2. Remove the entries for: chromadb, allPepper-memory-bank, devonthink"
echo "3. Restart Claude Code/Desktop"
echo ""

# Handle backups
echo ""
echo -e "${YELLOW}Checking for backup directories...${NC}"

BACKUP_DIRS=$(find ~ -maxdepth 1 -name ".hal-9000-backup-*" -type d 2>/dev/null | sort -r || true)
if [[ -n "$BACKUP_DIRS" ]]; then
    BACKUP_COUNT=$(echo "$BACKUP_DIRS" | wc -l | xargs)
    echo -e "${BLUE}Found $BACKUP_COUNT backup director(ies):${NC}"
    echo "$BACKUP_DIRS" | head -5
    echo ""
    read -rp "Remove all backup directories? (y/N): " remove_backups
    if [[ "$remove_backups" =~ ^[Yy]$ ]]; then
        while IFS= read -r backup_dir; do
            if [[ -d "$backup_dir" ]]; then
                rm -rf "$backup_dir"
                echo "  ✓ Removed $(basename "$backup_dir")"
            fi
        done <<< "$BACKUP_DIRS"
        echo -e "${GREEN}✓ Removed all backups${NC}"
    else
        echo ""
        echo "Backup directories preserved. To restore from backup:"
        echo "  - Config: ~/Library/Application Support/Claude/claude_desktop_config.json"
        echo "  - Commands: ~/.claude/commands/"
        echo "  - Agents: ~/.claude/agents/"
        echo ""
    fi
else
    echo -e "${YELLOW}No backup directories found${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Uninstall complete!                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
