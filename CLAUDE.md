# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**hal-9000: Hellbound Claude Marketplace**

This is a **Claude Code plugin marketplace** repository. It contains plugins that users can install through Claude Code's marketplace feature.

**This is NOT a software project to build.** It's a marketplace definition with plugin packages.

## Repository Structure

```
hal-9000/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition
├── plugins/
│   └── hal-9000/                 # Main plugin
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin metadata
│       ├── agents/               # 12 custom agent definitions
│       ├── aod/                  # Army of Darkness multi-branch tool
│       ├── commands/             # Slash commands (/check, /load, etc.)
│       ├── hal9000/              # Containerized Claude launcher
│       ├── hooks/                # Safety hooks
│       ├── mcp-servers/          # MCP server configs & docs
│       └── README.md
├── templates/                    # CLAUDE.md templates for projects
├── CHEATSHEET.md                 # Quick reference guide
├── README.md                     # Main documentation
└── CLAUDE.md                     # This file (repo development guide)
```

## What is a Plugin Marketplace?

A Claude Code plugin marketplace is a repository that:
- Contains `.claude-plugin/marketplace.json` defining available plugins
- Each plugin has `.claude-plugin/plugin.json` with metadata
- Users add the marketplace to Claude Code settings
- Plugins can provide: MCP servers, slash commands, hooks, etc.

## Working in This Repository

### Adding a New Plugin

1. Create plugin directory: `plugins/[plugin-name]/`
2. Add `.claude-plugin/plugin.json`:
   ```json
   {
     "name": "plugin-name",
     "description": "Plugin description",
     "version": "1.0.0",
     "author": {...},
     "mcpServers": {...},      // Optional
     "commands": {...},         // Optional
     "hooks": {...}            // Optional
   }
   ```
3. Add plugin content (MCP servers, commands, etc.)
4. Update `.claude-plugin/marketplace.json`:
   ```json
   {
     "plugins": [
       ...,
       {
         "name": "plugin-name",
         "source": "./plugins/plugin-name",
         "description": "Brief description",
         "version": "1.0.0"
       }
     ]
   }
   ```
5. Write README.md for the plugin
6. Test by adding marketplace to Claude Code

### Plugin Types

**MCP Server Plugin** (like hal-9000):
- Provides `mcpServers` in plugin.json
- Each server needs command, args, optional env
- Can include installation steps

**Command Plugin** (like session-tools):
- Provides `commands` in plugin.json
- Each command references a .md file
- Commands are slash commands (/command)

**Hook Plugin**:
- Provides `hooks` in plugin.json
- Can trigger on SessionStart, PreCompact, etc.

### Modifying Existing Plugin

**hal-9000 plugin**:
- MCP server configs in `.claude-plugin/plugin.json`
- MCP documentation in `mcp-servers/*/README.md`
- Commands in `commands/*.md` (referenced in plugin.json)
- Agents in `agents/*.md` (installed to ~/.claude/agents/)
- Hooks in `hooks/*.py` (registered via hooks.json)
- To add MCP server: update plugin.json + add docs in mcp-servers/
- To add command: create .md file in commands/ + update plugin.json
- To add agent: create .md file in agents/

### Testing Changes

1. Update version in plugin.json
2. Test locally by adding marketplace to Claude Code:
   - Settings → Marketplaces → Add Local Marketplace
   - Point to repository path
3. Install/update plugin in Claude Code
4. Verify functionality

## Plugin.json Schema

### Required Fields
```json
{
  "name": "string",
  "description": "string",
  "version": "semver",
  "author": {
    "name": "string",
    "url": "string (optional)"
  },
  "repository": "string",
  "license": "string"
}
```

### Optional Fields
```json
{
  "mcpServers": {
    "server-id": {
      "command": "string",
      "args": ["array"],
      "env": {"key": "value"}
    }
  },
  "commands": {
    "command-name": {
      "file": "path/to/file.md",
      "description": "string"
    }
  },
  "hooks": {
    "SessionStart": [...],
    "PreCompact": [...]
  },
  "install": {
    "steps": [...],
    "postInstall": "string"
  }
}
```

## Environment Variables

Use `${VAR_NAME}` syntax in plugin.json:
- `${HOME}` - User home directory
- `${CLAUDE_PLUGIN_ROOT}` - Plugin installation root
- `${CHROMADB_TENANT}` - Custom env var (user must set)

## Documentation Standards

- Every plugin must have README.md
- Explain what it does, why use it, how to configure
- Include usage examples
- Document prerequisites and troubleshooting

## Templates Directory

Contains CLAUDE.md templates for different project types:
- `java-project.md` - Java/Maven/Gradle
- `typescript-project.md` - TypeScript/Node.js
- `python-project.md` - Python/pip/poetry

These are NOT plugins - they're reference templates for users' projects.

## Legacy Installer

`install.sh` and `uninstall.sh` provide alternative installation without marketplace feature. These manually:
- Install MCP server dependencies
- Copy command files
- Update Claude config

Marketplace installation is preferred.

## Testing Checklist

Before committing plugin changes:

1. ✅ Version bumped in plugin.json
2. ✅ marketplace.json updated if new plugin
3. ✅ JSON syntax valid (`jq . < file.json`)
4. ✅ README.md updated
5. ✅ Tested in Claude Code:
   - Add marketplace locally
   - Install/update plugin
   - Verify functionality
6. ✅ Environment variables documented

## Common Issues

**Marketplace not appearing**:
- Check `.claude-plugin/marketplace.json` exists
- Verify JSON syntax
- Restart Claude Code

**Plugin install fails**:
- Check install steps work standalone
- Verify command paths are correct
- Check prerequisites are installed

**MCP servers not loading**:
- Check command path exists
- Verify environment variables set
- Look at Claude Code logs

## License

Apache 2.0 - All contributions must comply.
