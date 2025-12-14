# Hell-Agents Plugin

Curated collection of specialized Claude Code agent configurations, best practices, and workflows for parallel task execution.

## What's Included

This plugin provides documentation and examples for using Claude Code's specialized agents effectively:

### Development Agents
- **java-developer** - Java development with test-first methodology
- **java-architect-planner** - Design Java architecture and execution plans
- **java-debugger** - Systematic bug investigation and fixing

### Review & Analysis Agents
- **code-review-expert** - Code quality review and best practices
- **plan-auditor** - Validate technical plans for completeness
- **deep-analyst** - Complex problem analysis and system relationships
- **codebase-deep-analyzer** - Comprehensive codebase analysis

### Research & Exploration Agents
- **Explore** - Fast codebase exploration and discovery
- **deep-research-synthesizer** - Multi-source research synthesis
- **devonthink-researcher** - DEVONthink database research

### Planning & Organization Agents
- **Plan** - Software architecture and implementation planning
- **project-management-setup** - Create project tracking infrastructure
- **knowledge-tidier** - Consolidate information across knowledge bases

### Specialized Agents
- **pdf-chromadb-processor** - Process PDFs into ChromaDB
- **statusline-setup** - Configure Claude Code status line

## Installation

This plugin is installed automatically through the hal-9000 marketplace.

## Agent Usage Patterns

### 1. Parallel Agent Execution

Launch multiple agents concurrently for maximum efficiency:

```
Launch three agents in parallel:
1. Explore agent: Find all authentication-related code
2. Plan agent: Design the OAuth2 implementation
3. Code-review-expert: Review existing auth patterns
```

### 2. Sequential Agent Workflows

Chain agents for complex multi-step tasks:

```
Step 1: Use Plan agent to design feature
Step 2: Use plan-auditor to validate the plan
Step 3: Use java-developer to implement
Step 4: Use code-review-expert to review
```

### 3. Specialized Task Delegation

Delegate specific tasks to specialized agents:

```
Use java-debugger agent to investigate why TestUserAuth is failing
Use deep-analyst agent to understand the performance bottleneck in QueryExecutor
Use Explore agent to find all usages of deprecated SecurityManager
```

## Best Practices

### When to Use Agents

✅ **Use agents for:**
- Complex multi-step tasks
- Parallel exploration of large codebases
- Specialized analysis (debugging, architecture, review)
- Tasks requiring deep domain expertise
- Research across multiple sources

❌ **Don't use agents for:**
- Simple one-file changes
- Quick information lookups
- Tasks you can complete faster directly

### Agent Selection Guide

**For Planning:**
- New feature → `Plan` agent
- Validate plan → `plan-auditor` agent
- Multi-phase project → `project-management-setup` agent

**For Development:**
- Java implementation → `java-developer` agent
- Architecture design → `java-architect-planner` agent
- Bug investigation → `java-debugger` agent

**For Analysis:**
- Code review → `code-review-expert` agent
- Codebase understanding → `codebase-deep-analyzer` agent
- Complex debugging → `deep-analyst` agent

**For Exploration:**
- Find code patterns → `Explore` agent (quick/medium/very thorough)
- Research topic → `deep-research-synthesizer` agent
- Document search → `devonthink-researcher` agent

### Optimal Agent Workflows

#### Feature Implementation
```
1. Explore: "Find existing payment processing patterns" (quick)
2. Plan: "Design Stripe integration for checkout"
3. plan-auditor: "Review the Stripe integration plan"
4. java-developer: "Implement the payment service according to plan"
5. code-review-expert: "Review PaymentService implementation"
```

#### Bug Investigation
```
1. Explore: "Find all code paths that lead to NullPointerException in UserService" (medium)
2. java-debugger: "Debug why UserService.authenticate() throws NPE with valid credentials"
3. code-review-expert: "Review the fix for defensive programming patterns"
```

#### Architecture Review
```
1. codebase-deep-analyzer: "Analyze the current microservices architecture"
2. deep-analyst: "Investigate service coupling and identify boundaries"
3. Plan: "Design service decomposition strategy"
4. plan-auditor: "Validate the decomposition plan for risks"
```

## Agent Configurations

### Agent Thoroughness Levels

Many agents support thoroughness levels:

- **quick** - Basic search, fastest results
- **medium** - Moderate exploration, balanced speed/depth
- **very thorough** - Comprehensive analysis, slower but complete

Example:
```
Use Explore agent with "very thorough" level to find all configuration loading patterns
```

### Agent Context Management

Agents automatically:
- Access full conversation history (when needed)
- Use available MCP servers (ChromaDB, Memory Bank, DEVONthink)
- Leverage beads for task tracking
- Store findings in memory bank for future reference

### Agent Tools Access

Different agents have access to different tools:

**Read-only agents** (Explore, deep-analyst):
- Glob, Grep, Read, WebFetch, WebSearch
- Cannot modify files

**Development agents** (java-developer):
- Full tool access including Write, Edit, Bash
- Can create/modify code and run tests

**Planning agents** (Plan, plan-auditor):
- Read tools + specialized planning tools
- Cannot execute code changes

## Examples

### Example 1: Parallel Codebase Exploration

```
Launch 3 Explore agents in parallel to understand the authentication system:

Agent 1 (quick): "Find all JWT token handling code"
Agent 2 (medium): "Explore OAuth2 integration patterns"
Agent 3 (quick): "Find security configuration and filters"
```

### Example 2: Feature Implementation Pipeline

```
1. Plan agent: "Design user profile editing feature with validation"
2. plan-auditor agent: "Audit the profile editing plan"
   (Fix any issues found)
3. java-developer agent: "Implement UserProfileService according to plan"
4. code-review-expert agent: "Review UserProfileService for security and best practices"
```

### Example 3: Research & Implementation

```
1. deep-research-synthesizer: "Research best practices for rate limiting in Spring Boot"
2. Explore: "Find our current rate limiting implementations"
3. Plan: "Design improved rate limiting strategy"
4. java-developer: "Implement rate limiting according to plan"
```

### Example 4: Bug Investigation Workflow

```
1. Explore (medium): "Find all code that modifies user session state"
2. java-debugger: "Debug SessionManager concurrent modification issue"
3. java-developer: "Implement fix with proper synchronization"
4. code-review-expert: "Review concurrency handling in SessionManager"
```

## Integration with Other Tools

### Beads Integration

Agents work seamlessly with beads task tracking:

```
Use Plan agent to create implementation plan for [epic-123]
Use java-developer agent to implement [task-456]
```

### Memory Bank Integration

Agents store findings in memory bank:

```
Use deep-research-synthesizer to research microservices patterns,
store findings in memory bank project "architecture-research"
```

### ChromaDB Integration

Agents can search and store in ChromaDB:

```
Use pdf-chromadb-processor to index all architecture documentation PDFs
Use deep-research-synthesizer to query ChromaDB for relevant patterns
```

### DEVONthink Integration

Research agents leverage DEVONthink:

```
Use devonthink-researcher to explore topic "distributed consensus algorithms"
Use deep-analyst to analyze the consensus patterns found
```

## Tips & Tricks

1. **Spawn at top level** - Let agents do the work, don't duplicate their tasks
2. **Use parallel agents** - Launch independent agents concurrently when possible
3. **Chain specialists** - Plan → Audit → Implement → Review
4. **Match agent to task** - Use specialized agents for their domain
5. **Set thoroughness** - Balance speed vs depth based on urgency
6. **Store findings** - Use memory bank to preserve agent discoveries
7. **Resume agents** - Use agent IDs to continue previous work

## Troubleshooting

### Agent Times Out
- Reduce thoroughness level (very thorough → medium → quick)
- Break task into smaller sub-tasks
- Provide more specific search constraints

### Agent Returns Incomplete Results
- Increase thoroughness level
- Provide more context in the prompt
- Use multiple agents in parallel for different aspects

### Agent Doesn't Find Expected Code
- Verify search patterns are correct
- Try different agents (Explore vs Grep)
- Check if code is in expected location

## Contributing

Have a useful agent workflow or configuration? Submit a PR to add it to the examples!

## See Also

- [Claude Code Agent Documentation](https://docs.claude.com/en/claude-code/agents)
- [Task Tool Documentation](https://docs.claude.com/en/claude-code/tools/task)
- [Beads Task Tracking](https://github.com/steveyegge/beads)
