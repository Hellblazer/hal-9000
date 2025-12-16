# CLAUDE.md - Java Project Template

## Project

**Name**: [PROJECT_NAME]
**Description**: [DESCRIPTION]
**Java**: [VERSION]

## Build

```bash
./mvnw clean install              # Build
./mvnw test                       # Tests
./mvnw test -Dtest=Class#method   # Single test
./mvnw spring-boot:run            # Run (Spring)
java -jar target/*.jar            # Run (standalone)
```

## Structure

```
src/main/java/      # Source
src/main/resources/ # Config
src/test/java/      # Tests
pom.xml             # Dependencies
```

## Conventions

- Use `var` for local variables
- No `synchronized` - use `java.util.concurrent`
- Records for immutable data
- Sealed interfaces for closed hierarchies
- Pattern matching in switch

## Testing

- Naming: `ClassTest`, `should_X_when_Y`
- AssertJ for assertions
- Mock externals, not domain

## Key Packages

- [PACKAGE] - [PURPOSE]

## Notes

[PROJECT-SPECIFIC GUIDANCE]
