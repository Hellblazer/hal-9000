# Memory Bank MCP Server

Persistent memory system for maintaining project context across Claude Code sessions.

## What It Does

Memory Bank provides:
- **Project-based organization**: Each project gets its own memory space
- **Persistent context**: Maintain knowledge across sessions
- **File-based storage**: Simple markdown files for easy inspection
- **Knowledge coordination**: Share context between parallel agents

## Use Cases

- Maintain long-running project context
- Store architectural decisions and rationale
- Track ongoing work across multiple sessions
- Coordinate knowledge between parallel Claude agents
- Build up domain-specific knowledge over time

## Installation

Run the installation script:

```bash
./install.sh
```

This will:
1. Install the `@allpepper/memory-bank-mcp` npm package
2. Create the default memory bank directory at `~/memory-bank`

## Configuration

The `config.json` uses the default memory bank location. You can customize the path by editing the `MEMORY_BANK_ROOT` environment variable.

## Available Tools

Once installed, Claude Code can use:
- `list_projects` - View all projects in memory bank
- `list_project_files` - List files for a specific project
- `memory_bank_read` - Read a memory file
- `memory_bank_write` - Create a new memory file
- `memory_bank_update` - Update an existing memory file

## Memory Structure

Memory files are organized as:

```
~/memory-bank/
├── project-name/
│   ├── decisions.md
│   ├── architecture.md
│   ├── ongoing-work.md
│   └── ...
└── another-project/
    └── ...
```

## Best Practices

1. **Project Naming**: Use clear, consistent project names
2. **File Organization**: Group related information in separate files
3. **Regular Updates**: Keep memory current as work progresses
4. **Review Periodically**: Clean up stale information

## Prerequisites

- Node.js 16 or higher
- npm

## Troubleshooting

### Memory files not found

Check that `MEMORY_BANK_ROOT` points to the correct directory:

```bash
ls ~/memory-bank
```

### Permission errors

Ensure the memory bank directory is writable:

```bash
chmod -R u+w ~/memory-bank
```

## Links

- [Memory Bank MCP GitHub](https://github.com/allpepper/memory-bank-mcp)
- [MCP Documentation](https://modelcontextprotocol.io/)
