# CLAUDE.md Templates

Project-specific CLAUDE.md templates for different tech stacks. These templates provide Claude Code with context about your project's build system, architecture, and development workflow.

## Available Templates

### Java Projects
**File**: `java-project.md`

For Maven or Gradle-based Java projects. Includes:
- Modern Java patterns (var, records, sealed classes)
- Maven/Gradle build commands
- Testing strategies
- Common architectural patterns

### TypeScript Projects
**File**: `typescript-project.md`

For TypeScript/Node.js projects. Includes:
- npm/yarn/pnpm commands
- Testing with Jest/Vitest
- Build and development workflows
- Type safety best practices

### Python Projects
**File**: `python-project.md`

For Python projects with pip, poetry, or pipenv. Includes:
- Virtual environment management
- Testing with pytest
- Dependency management
- Common Python patterns

## Usage

1. Choose the template that matches your project's tech stack
2. Copy it to your project root as `CLAUDE.md`
3. Customize it with project-specific details:
   - Update command examples with actual project commands
   - Add project-specific architecture notes
   - Document any unique patterns or conventions
   - List important directories and their purposes

```bash
# Example: Set up CLAUDE.md for a Java project
cp ~/git/hal-9000/templates/java-project.md /path/to/your/project/CLAUDE.md
```

Then edit the file to match your project specifics.

## What to Include

### Essential Information
- **Build commands**: How to compile, test, run
- **Project structure**: Key directories and their purposes
- **Architecture**: High-level design patterns
- **Testing**: How to run tests, where test files live
- **Common tasks**: Frequent development operations

### What NOT to Include
- Generic programming advice (Claude already knows this)
- Obvious instructions ("write good code")
- Every file and directory (Claude can discover these)
- Information that's better in README.md (installation, deployment)

## Tips for Customization

1. **Be specific to YOUR project**: Don't copy generic advice
2. **Focus on the "big picture"**: What requires reading multiple files to understand?
3. **Document conventions**: How does your team structure code?
4. **Update as needed**: Keep it current as your project evolves
5. **Test it**: Have Claude read it and ask questions

## Example Customizations

### Adding custom build commands
```markdown
## Build Commands

# Development build with hot reload
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Production build
./mvnw clean package -Pproduction
```

### Documenting architecture
```markdown
## Architecture

This project uses hexagonal architecture:
- `domain/` - Core business logic (no dependencies)
- `application/` - Use cases and orchestration
- `infrastructure/` - External concerns (DB, API, etc.)
```

### Project-specific conventions
```markdown
## Code Conventions

- All services implement `LifecycleAware` interface
- Use constructor injection only (no field injection)
- Integration tests go in `src/integration-test/`
```

## Contributing

Have a template for another tech stack? Add it here!

Common stacks to consider:
- Go projects
- Rust projects
- React/Next.js projects
- Vue/Nuxt projects
- Django/Flask projects
- Ruby on Rails projects
