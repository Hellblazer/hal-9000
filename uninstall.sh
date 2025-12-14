#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
HAL_COMMANDS=("check.md" "load.md" "session-delete.md" "sessions.md")

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║       HAL-9000 Claude Marketplace Uninstaller     ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will remove hal-9000 slash commands.${NC}"
echo -e "${YELLOW}MCP servers must be removed manually from Claude's config.${NC}"
echo ""
read -p "Continue? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Removing slash commands...${NC}"

removed_count=0
for cmd in "${HAL_COMMANDS[@]}"; do
    cmd_path="$CLAUDE_COMMANDS_DIR/$cmd"
    if [ -f "$cmd_path" ]; then
        rm "$cmd_path"
        echo "  ✓ Removed $cmd"
        ((removed_count++))
    fi
done

echo ""
if [ $removed_count -gt 0 ]; then
    echo -e "${GREEN}✓ Removed $removed_count slash command(s)${NC}"
else
    echo -e "${YELLOW}No hal-9000 slash commands found${NC}"
fi

echo ""
echo -e "${YELLOW}To remove MCP servers:${NC}"
echo "1. Edit your Claude config file:"
echo "   - macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "   - Linux: ~/.config/Claude/claude_desktop_config.json"
echo "2. Remove the entries for: chromadb, allPepper-memory-bank, devonthink"
echo "3. Restart Claude Code/Desktop"
echo ""

# Check for backups
BACKUP_DIRS=$(ls -dt ~/.hal-9000-backup-* 2>/dev/null | head -5 || true)
if [ -n "$BACKUP_DIRS" ]; then
    echo -e "${BLUE}Backup directories found:${NC}"
    echo "$BACKUP_DIRS"
    echo ""
    echo "To restore from backup, copy files from a backup directory back to:"
    echo "  - Config: ~/Library/Application Support/Claude/claude_desktop_config.json"
    echo "  - Commands: ~/.claude/commands/"
    echo ""
fi

echo -e "${GREEN}Uninstall complete!${NC}"
