# Custom Agent Configurations

Agent configuration files for specialized Claude Code tasks. Installed to `~/.claude/agents/`.

## Available Agents

### Development
- **java-developer** - Java implementation with test-first methodology
- **java-architect-planner** - Architecture design and planning
- **java-debugger** - Bug investigation and fixing

### Review & Analysis
- **code-review-expert** - Code quality and best practices review
- **plan-auditor** - Technical plan validation
- **deep-analyst** - Complex problem analysis
- **codebase-deep-analyzer** - Comprehensive codebase analysis

### Research
- **Explore** - Codebase exploration and discovery
- **deep-research-synthesizer** - Multi-source research synthesis
- **devonthink-researcher** - DEVONthink database research

### Organization
- **Plan** - Architecture and implementation planning
- **project-management-setup** - Project tracking infrastructure
- **knowledge-tidier** - Information consolidation across knowledge bases
- **pdf-chromadb-processor** - PDF processing into ChromaDB

## Usage

### Basic Invocation

Launch agents via Task tool with `subagent_type` parameter:
```
Use java-developer agent to implement UserService
Use code-review-expert agent to review the authentication module
Use Explore agent to find all database query patterns
```

### Parallel Execution

Launch multiple agents simultaneously:
```
Launch three agents in parallel:
- Explore agent: Find authentication code
- Plan agent: Design OAuth2 integration
- code-review-expert: Review existing auth patterns
```

### Sequential Workflows

Chain agents for multi-step tasks:
```
1. Plan agent: Design payment processing feature
2. plan-auditor: Validate the design
3. java-developer: Implement according to plan
4. code-review-expert: Review implementation
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
- New feature → Plan
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

**Exploration**
- Find code patterns → Explore
- Research topics → deep-research-synthesizer
- Document search → devonthink-researcher

## Thoroughness Levels

Some agents support thoroughness levels:
- **quick** - Basic search, fast results
- **medium** - Moderate depth, balanced speed
- **very thorough** - Comprehensive analysis, slower

Example:
```
Use Explore agent with very thorough level to find all configuration loading patterns
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

## Common Workflows

### Feature Implementation
```
1. Explore: Find existing payment patterns (quick)
2. Plan: Design Stripe checkout integration
3. plan-auditor: Review integration plan
4. java-developer: Implement PaymentService
5. code-review-expert: Review implementation
```

### Bug Investigation
```
1. Explore: Find code paths to NullPointerException (medium)
2. java-debugger: Debug UserService.authenticate() NPE
3. code-review-expert: Review fix for defensive patterns
```

### Architecture Review
```
1. codebase-deep-analyzer: Analyze microservices architecture
2. deep-analyst: Investigate service coupling
3. Plan: Design service decomposition
4. plan-auditor: Validate decomposition plan
```

### Research & Implementation
```
1. deep-research-synthesizer: Research Spring Boot rate limiting
2. Explore: Find current rate limiting code
3. Plan: Design improved rate limiting
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
- Try different agents (Explore vs. Grep)
- Check code location assumptions
