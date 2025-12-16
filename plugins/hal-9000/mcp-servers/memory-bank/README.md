# Memory Bank MCP Server

Persistent memory system for maintaining project context across Claude Code sessions.

## Features

- Project-based organization
- Persistent context across sessions
- File-based storage (markdown)
- Knowledge coordination between parallel agents

## Use Cases

- Maintain long-running project context
- Store architectural decisions
- Track ongoing work across sessions
- Coordinate knowledge between parallel agents
- Build domain-specific knowledge over time

## Installation

Run the installation script:

```bash
./install.sh
```

This installs the `@allpepper/memory-bank-mcp` npm package and creates the default directory at `~/memory-bank`.

## Configuration

The `config.json` uses the default memory bank location. Customize the path by setting the `MEMORY_BANK_ROOT` environment variable.

## Available Tools

- `list_projects` - View all projects
- `list_project_files` - List files for a project
- `memory_bank_read` - Read a memory file
- `memory_bank_write` - Create a memory file
- `memory_bank_update` - Update a memory file

## Usage Examples

### Starting a New Project

```
Create a memory bank project for "my-api-project" with initial architecture decisions
```

Claude will create the project directory and store your decisions:
```json
{
  "projectName": "my-api-project",
  "fileName": "architecture.md",
  "content": "# Architecture Decisions\n\n## Database\n- PostgreSQL for persistence..."
}
```

### Tracking Ongoing Work

```
Update the memory bank: I finished the authentication module and started on rate limiting
```

Claude updates your project's ongoing work file with current status.

### Resuming Work Across Sessions

```
What was I working on in the my-api-project?
```

Claude reads your memory bank to restore context:
- Recent decisions
- Work in progress
- Outstanding issues

### Coordinating Parallel Agents

When using multiple Claude sessions (aod/hal9000 squad):
```
Check the memory bank for what other sessions have documented about the API design
```

Memory bank provides shared context across parallel agents.

### Example Workflow

1. **Start session**: "Initialize memory for project-alpha"
2. **Record decisions**: "Store decision: using GraphQL instead of REST because..."
3. **Track progress**: "Update: completed user schema, starting auth"
4. **End session**: "Summarize today's progress to memory bank"
5. **Next session**: "What's the current state of project-alpha?"

## Memory Structure

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

- Use clear, consistent project names
- Group related information in separate files
- Keep memory current as work progresses
- Clean up stale information periodically

## Prerequisites

- Node.js 16+
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
