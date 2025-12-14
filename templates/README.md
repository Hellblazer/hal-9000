# CLAUDE.md Templates

Project-specific CLAUDE.md templates for different tech stacks and Claude Code configurations.

## HAL-9000 Configuration

### CLAUDE-aod-global.md

Template for adding aod (Army of Darkness) awareness to your global `~/.claude/CLAUDE.md`.

**Quick install:**
```bash
cat ~/git/hal-9000/templates/CLAUDE-aod-global.md >> ~/.claude/CLAUDE.md
```

**What it provides:**
- Documents `aod-send` and `aod-broadcast` commands
- Explains multi-branch session coordination
- Enables Claude to suggest aod commands when appropriate
- Works across all projects using aod

**Note:** aod also auto-generates session-specific `CLAUDE.md` in each worktree with current session context (session name, branch, other active sessions, etc.)

---

## Project-Specific Templates

### Java Projects
**File**: `java-project.md`

For Maven or Gradle-based Java projects. Covers modern Java patterns, build commands, testing, and architecture.

### TypeScript Projects
**File**: `typescript-project.md`

For TypeScript/Node.js projects. Covers npm/yarn/pnpm commands, testing, build workflows, and type safety.

### Python Projects
**File**: `python-project.md`

For Python projects with pip, poetry, or pipenv. Covers virtual environments, pytest testing, and dependency management.

## Usage

1. Choose the template matching your tech stack
2. Copy to project root as `CLAUDE.md`
3. Customize with project-specific details

```bash
cp ~/git/hal-9000/templates/java-project.md /path/to/your/project/CLAUDE.md
```

Then edit for your project.

## What to Include

### Essential
- Build commands (compile, test, run)
- Project structure (key directories)
- Architecture (design patterns)
- Testing (how to run tests)
- Common tasks (frequent operations)

### Skip
- Generic programming advice
- Obvious instructions
- Every file and directory
- Information better suited for README.md

## Customization Tips

1. Be specific to your project
2. Focus on "big picture" understanding
3. Document your team's conventions
4. Keep current as project evolves
5. Test by having Claude read it

## Example Customizations

### Custom build commands
```markdown
## Build Commands

# Development build with hot reload
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Production build
./mvnw clean package -Pproduction
```

### Architecture notes
```markdown
## Architecture

Hexagonal architecture:
- `domain/` - Core business logic (no dependencies)
- `application/` - Use cases and orchestration
- `infrastructure/` - External concerns (DB, API, etc.)
```

### Code conventions
```markdown
## Code Conventions

- All services implement `LifecycleAware` interface
- Use constructor injection only (no field injection)
- Integration tests go in `src/integration-test/`
```

## Contributing

Add templates for other stacks:
- Go projects
- Rust projects
- React/Next.js projects
- Vue/Nuxt projects
- Django/Flask projects
- Ruby on Rails projects
