# Custom Agent Configurations

Agent configuration files for specialized Claude Code tasks. 16 agents installed to `~/.claude/agents/`.

## Available Agents

### Development (3)
- **java-developer** - Java implementation with test-first methodology
- **java-architect-planner** - Architecture design and planning
- **java-debugger** - Bug investigation and fixing

### Review & Analysis (4)
- **code-review-expert** - Code quality and best practices review
- **plan-auditor** - Technical plan validation
- **deep-analyst** - Complex problem analysis
- **codebase-deep-analyzer** - Comprehensive codebase analysis

### Research (2)
- **deep-research-synthesizer** - Multi-source research synthesis
- **devonthink-researcher** - DEVONthink database research

### Organization (3)
- **project-management-setup** - Project tracking infrastructure
- **knowledge-tidier** - Information consolidation across knowledge bases
- **pdf-chromadb-processor** - PDF processing into ChromaDB

### Built-in Agent Patterns
These are common invocation patterns, not separate agent files:
- **Explore** - Use codebase-deep-analyzer for exploration tasks
- **Plan** - Use java-architect-planner or plan-auditor for planning

## Usage

### Basic Invocation

Launch agents via Task tool with `subagent_type` parameter:
```
Use java-developer agent to implement UserService
Use code-review-expert agent to review the authentication module
Use codebase-deep-analyzer agent to find all database query patterns
```

### Parallel Execution

Launch multiple agents simultaneously:
```
Launch three agents in parallel:
- codebase-deep-analyzer agent: Find authentication code
- java-architect-planner agent: Design OAuth2 integration
- code-review-expert agent: Review existing auth patterns
```

### Sequential Workflows

Chain agents for multi-step tasks:
```
1. java-architect-planner agent: Design payment processing feature
2. plan-auditor agent: Validate the design
3. java-developer agent: Implement according to plan
4. code-review-expert agent: Review implementation
```

## When to Use Agents

Use agents for:
- Multi-step tasks requiring specialized knowledge
- Parallel exploration of large codebases
- Deep analysis (debugging, architecture, security review)
- Research across multiple sources or documents

Don't use agents for:
- Simple single-file changes
- Quick lookups or one-off questions
- Tasks faster to do directly

## Agent Selection

**Planning & Design**
- New feature → java-architect-planner
- Validate design → plan-auditor
- Multi-phase project → project-management-setup

**Development**
- Java implementation → java-developer
- Architecture design → java-architect-planner
- Bug investigation → java-debugger

**Analysis**
- Code review → code-review-expert
- System understanding → codebase-deep-analyzer
- Complex debugging → deep-analyst

**Research**
- Find code patterns → codebase-deep-analyzer
- Research topics → deep-research-synthesizer
- Document search → devonthink-researcher

## Thoroughness Levels

Some agents support thoroughness levels:
- **quick** - Basic search, fast results
- **medium** - Moderate depth, balanced speed
- **very thorough** - Comprehensive analysis, slower

Example:
```
Use codebase-deep-analyzer agent with very thorough level to find all configuration loading patterns
```

## Integration

### Memory Bank

Agents can store findings in memory bank:
```
Use deep-research-synthesizer to research microservices patterns,
store findings in memory bank project "architecture-research"
```

### ChromaDB

Agents can search and store in ChromaDB:
```
Use pdf-chromadb-processor to index architecture documentation
Use deep-research-synthesizer to query ChromaDB for relevant patterns
```

### DEVONthink

Research agents leverage DEVONthink databases:
```
Use devonthink-researcher to explore "distributed consensus algorithms"
Use deep-analyst to analyze consensus patterns found
```

### beads (bd) Issue Tracking

Agents should use `bd` for all task tracking - do NOT use markdown TODO lists.

**Before starting work:**
```bash
bd ready                          # Check for ready work
bd update <id> --status in_progress  # Claim a task
```

**When discovering new work:**
```bash
bd create "Found bug in auth" -t bug -p 1 --deps discovered-from:<parent-id>
```

**After completing work:**
```bash
bd close <id> --reason "Implemented and tested"
```

**Best practices:**
- Always check `bd ready` before asking "what should I work on?"
- Link discovered issues with `discovered-from` dependency
- Commit `.beads/issues.jsonl` together with code changes
- Use `--json` flag for programmatic parsing

## Common Workflows

### Feature Implementation
```
1. codebase-deep-analyzer: Find existing payment patterns (quick)
2. java-architect-planner: Design Stripe checkout integration
3. plan-auditor: Review integration plan
4. java-developer: Implement PaymentService
5. code-review-expert: Review implementation
```

### Bug Investigation
```
1. codebase-deep-analyzer: Find code paths to NullPointerException (medium)
2. java-debugger: Debug UserService.authenticate() NPE
3. code-review-expert: Review fix for defensive patterns
```

### Architecture Review
```
1. codebase-deep-analyzer: Analyze microservices architecture
2. deep-analyst: Investigate service coupling
3. java-architect-planner: Design service decomposition
4. plan-auditor: Validate decomposition plan
```

### Research & Implementation
```
1. deep-research-synthesizer: Research Spring Boot rate limiting
2. codebase-deep-analyzer: Find current rate limiting code
3. java-architect-planner: Design improved rate limiting
4. java-developer: Implement according to plan
```

## Tips

- Use parallel agents for independent tasks
- Chain specialist agents for complex workflows
- Match agent to task domain
- Set thoroughness based on urgency vs. completeness
- Store agent findings in memory bank for future reference
- Resume agents using their IDs for continued work

## Troubleshooting

### Agent times out
- Reduce thoroughness level
- Break task into smaller sub-tasks
- Provide more specific constraints

### Agent returns incomplete results
- Increase thoroughness level
- Provide more context in prompt
- Use multiple agents for different aspects

### Agent doesn't find expected code
- Verify search patterns are correct
- Try codebase-deep-analyzer with different thoroughness levels
- Check code location assumptions
