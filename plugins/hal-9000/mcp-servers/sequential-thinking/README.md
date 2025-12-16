# Sequential Thinking MCP Server

Step-by-step reasoning MCP server for complex problem-solving and analysis.

## What It Does

Sequential Thinking provides Claude with a structured approach to complex problems:

- **Step-by-step reasoning** - Break down complex problems into manageable steps
- **Hypothesis tracking** - Form and test hypotheses systematically
- **Progress visualization** - Track reasoning progress across steps
- **Revision support** - Allow backtracking and revision of earlier conclusions

## Usage

The Sequential Thinking server is automatically available in Claude Code after hal-9000 installation.

**Trigger phrases:**
- "Debug this issue using sequential thinking"
- "Think through this step by step"
- "Analyze this problem systematically"
- "Use sequential thinking to design this"

**Example:**
```
Please use sequential thinking to debug why the API returns 500 errors
intermittently. Consider database connections, rate limiting, and
memory issues as potential causes.
```

## How It Works

The server provides a `sequentialthinking` tool that Claude uses to:

1. **Initialize** - Set up the problem space and initial hypotheses
2. **Step** - Execute reasoning steps with explicit thought tracking
3. **Branch** - Explore alternative hypotheses when needed
4. **Revise** - Update conclusions based on new information
5. **Conclude** - Synthesize findings into actionable results

## Configuration

The server is pre-configured in hal-9000. No additional setup required.

**Plugin configuration:**
```json
{
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  }
}
```

**In containers (aod/hal9000):**
```json
{
  "sequential-thinking": {
    "command": "mcp-server-sequential-thinking"
  }
}
```

## Best Use Cases

- **Debugging** - Systematic bug investigation
- **Architecture design** - Step-by-step design decisions
- **Code review** - Thorough analysis of complex code
- **Problem solving** - Breaking down ambiguous requirements
- **Research** - Structured exploration of topics

## Detailed Examples

### Debugging a Complex Bug

```
Use sequential thinking to debug: The app crashes intermittently when
users submit forms. It only happens under high load.
```

Claude will:
1. Form initial hypotheses (race condition, memory leak, connection pool)
2. Test each hypothesis against available evidence
3. Request specific diagnostic information
4. Narrow down to root cause
5. Propose solution with confidence level

### Architecture Decision

```
Think through step-by-step: Should we use microservices or monolith
for our new e-commerce platform? We expect 10K users initially,
scaling to 1M over 2 years.
```

Claude systematically evaluates:
- Current team capabilities
- Expected scaling patterns
- Operational complexity
- Development velocity tradeoffs
- Migration path options

### Code Review Analysis

```
Analyze this authentication code systematically for security issues:
[paste code]
```

Claude examines:
- Input validation
- Token handling
- Session management
- Error messages (information leakage)
- Timing attacks
- Each finding with severity and remediation

### Design Pattern Selection

```
Step through the options: I need to implement a notification system
that supports email, SMS, push, and in-app notifications. New
channels may be added.
```

Claude evaluates patterns:
- Strategy pattern
- Observer pattern
- Factory + Strategy combination
- Event-driven architecture
With tradeoffs for each approach

## Comparison with Regular Claude

| Approach | Best For |
|----------|----------|
| Regular Claude | Quick questions, simple tasks |
| Sequential Thinking | Complex debugging, multi-step analysis, design decisions |

## Source

Based on [@modelcontextprotocol/server-sequential-thinking](https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking)

## Troubleshooting

**Server not responding:**
- Restart Claude Code
- Check if npx is available: `which npx`
- Try manual test: `npx -y @modelcontextprotocol/server-sequential-thinking`

**Not being used for complex tasks:**
- Explicitly request sequential thinking in your prompt
- Use trigger phrases like "think through this step by step"
