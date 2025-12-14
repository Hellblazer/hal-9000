# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**[Project Name]**: [Brief description]

[Add 2-3 sentences about what this project does and its purpose]

## Build System

**Build Tool**: [Maven / Gradle]

### Common Commands

```bash
# Build the project
./mvnw clean install
# Or for Gradle:
./gradlew build

# Run tests
./mvnw test
# Or for Gradle:
./gradlew test

# Run a single test
./mvnw test -Dtest=ClassName#methodName

# Run the application
./mvnw spring-boot:run
# Or for standard Java:
java -jar target/[artifact-name].jar

# Generate sources (if applicable)
./mvnw generate-sources

# Skip tests during build
./mvnw clean install -DskipTests
```

## Java Version & Features

- **Java Version**: [Java 21 / Java 24 / etc.]
- **Language Features**: [Record classes / Sealed classes / Pattern matching / etc.]
- **Preview Features**: [List any --enable-preview features in use]

### Java Code Conventions

- Always use `var` for local variables where type is obvious
- Never use `synchronized` - prefer `java.util.concurrent` collections
- Use records for immutable data classes
- Prefer sealed interfaces for closed type hierarchies
- Use pattern matching in switch expressions

## Project Structure

```
project-root/
├── src/main/java/          # Main source code
├── src/main/resources/     # Configuration files
├── src/test/java/          # Unit tests
├── src/test/resources/     # Test resources
└── pom.xml                 # Maven configuration
```

### Key Packages

- `[package.domain]` - [Core business logic]
- `[package.application]` - [Application services]
- `[package.infrastructure]` - [External integrations]

## Architecture

[Describe your high-level architecture. Examples:]

### Hexagonal Architecture
- Domain layer contains pure business logic with no external dependencies
- Application layer orchestrates use cases
- Infrastructure layer handles external concerns (DB, HTTP, etc.)

### Event-Driven
- Commands trigger state changes
- Events notify of state changes
- Aggregates enforce business invariants

### [Your Architecture Pattern]
[Describe the key architectural decisions and patterns]

## Testing Strategy

### Test Structure
- Unit tests: Test individual components in isolation
- Integration tests: Test component interactions
- [Additional test types if applicable]

### Running Tests
```bash
# All tests
./mvnw test

# Specific test class
./mvnw test -Dtest=UserServiceTest

# Integration tests only (if separated)
./mvnw verify -P integration-tests

# With coverage
./mvnw test jacoco:report
```

### Test Conventions
- Test class naming: `[ClassUnderTest]Test`
- Test method naming: `should[ExpectedBehavior]_when[Condition]`
- Use AssertJ for fluent assertions
- Mock external dependencies, not domain logic

## Dependencies

### Key Libraries
- [Library name]: [Purpose / When to use]
- [Library name]: [Purpose / When to use]

### Adding Dependencies
- Check for version conflicts: `./mvnw dependency:tree`
- Update versions in `pom.xml` [or `gradle.properties`]

## Common Development Tasks

### Adding a New Feature
1. Create domain model if needed
2. Implement business logic in service
3. Write unit tests
4. Add integration tests
5. Update relevant documentation

### Database Migrations
[If using Flyway/Liquibase:]
```bash
# Location: src/main/resources/db/migration/
# Naming: V{version}__{description}.sql
# Apply: ./mvnw flyway:migrate
```

### Configuration
- Development config: `application-dev.yml`
- Production config: `application-prod.yml`
- Secrets: Use environment variables, never commit secrets

## Important Conventions

[Document project-specific conventions here]

### Code Style
- Follow project's `.editorconfig`
- Use project's code formatter configuration
- [Any specific style guidelines]

### Git Workflow
- Branch naming: `feature/description`, `fix/description`
- Commit messages: [Your convention]
- [Any specific git workflow rules]

## Troubleshooting

### Build Issues
```bash
# Clean build cache
./mvnw clean

# Update dependencies
./mvnw dependency:resolve

# Check for dependency conflicts
./mvnw dependency:tree
```

### Test Failures
- Check logs in `target/surefire-reports/`
- Run single test to isolate issue
- Ensure test databases are clean

## Links & Resources

- [Project Documentation URL]
- [Issue Tracker URL]
- [CI/CD Dashboard URL]
- [Architecture Decision Records]

## Notes for Claude Code

[Add any specific guidance for Claude when working in this codebase]

- [Important patterns to follow]
- [Things to avoid]
- [Specific considerations for this project]
