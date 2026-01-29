# Contributing to hal-9000

Thank you for your interest in contributing to the hal-9000 Claude Code plugin marketplace!

## Repository Structure

![hal-9000 Repository Structure](../docs/diagrams/contributing-structure.png)

## How to Contribute

### Important: v2.0.0 Breaking Changes

**All 16 custom agents were removed in v2.0.0.** Contributors should use marketplace plugins or custom MCP servers for specialized functionality instead of creating agents.

### Adding Marketplace Plugins

Create plugins with custom commands, MCP servers, or hooks. See plugin.json schema documentation.

For specialized functionality, create marketplace plugins or custom MCP servers (not agents).

### Adding a New Hook

1. Create a Python file in `plugins/hal-9000/hooks/`:

```python
#!/usr/bin/env python3
"""
Description of what this hook checks.
"""

def check_my_pattern(command):
    """
    Check if command matches pattern.
    Returns tuple: (decision: str, reason: str or None)

    decision is one of: "allow", "ask", "block"
    """
    if should_block(command):
        return "block", "Explanation of why this is blocked"
    elif needs_approval(command):
        return "ask", "Reason for asking approval"
    return "allow", None
```

2. Add the check function to `bash_hook.py`:
   - Import your function
   - Add it to the `checks` list

3. Add tests in `plugins/hal-9000/tests/test_hooks.py`

4. Update `plugins/hal-9000/.claude-plugin/hooks.json` if adding a new standalone hook

### Adding a New Slash Command

1. Create a markdown file in `plugins/hal-9000/commands/`:

```markdown
# Command Name

Description of what this command does.

## Usage
How to use the command.

## Implementation
The prompt that Claude will execute.
```

2. Register in `plugins/hal-9000/.claude-plugin/plugin.json`:

```json
{
  "commands": {
    "my-command": {
      "file": "commands/my-command.md",
      "description": "Brief description"
    }
  }
}
```

### Modifying Shell Scripts

When modifying `aod.sh` or `hal9000.sh`:

1. Use functions from `lib/container-common.sh` for common operations
2. Follow the existing error handling patterns (`set -Eeuo pipefail`)
3. Use proper quoting for all variables
4. Add cleanup in trap handlers

### Adding MCP Server Documentation

1. Create a directory in `plugins/hal-9000/mcp-servers/[server-name]/`
2. Add `README.md` with:
   - What the server does
   - Prerequisites
   - Configuration options
   - Usage examples
   - Troubleshooting

## Testing

### Running Hook Tests

```bash
cd plugins/hal-9000
python -m pytest tests/test_hooks.py -v
```

### Testing Plugin Installation

1. Add the marketplace locally in Claude Code settings
2. Install/update the plugin
3. Verify functionality:
   - Hooks block expected commands
   - Slash commands work
   - MCP servers start correctly

## Pull Request Guidelines

1. **Version Bump**: Update version in:
   - `plugins/hal-9000/.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`

2. **Changelog**: Add entry to `plugins/hal-9000/CHANGELOG.md`

3. **JSON Validation**: Ensure all JSON files are valid:
   ```bash
   jq . < plugins/hal-9000/.claude-plugin/plugin.json
   jq . < .claude-plugin/marketplace.json
   ```

4. **Tests**: Ensure all tests pass

5. **Documentation**: Update relevant README files

## Code Style

### Python
- Follow PEP 8
- Use type hints where helpful
- Include docstrings for functions

### Shell Scripts
- Use `set -Eeuo pipefail`
- Quote all variables
- Use arrays for command arguments
- Include comments for complex logic

### Markdown
- Use ATX-style headers (`#`)
- Include code examples with language tags
- Keep lines under 100 characters where practical

## Questions?

Open an issue on GitHub for:
- Bug reports
- Feature requests
- Questions about contributing

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
