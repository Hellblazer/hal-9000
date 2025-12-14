# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**[Project Name]**: [Brief description]

[Add 2-3 sentences about what this project does and its purpose]

## Tech Stack

- **Runtime**: Node.js [version]
- **Language**: TypeScript [version]
- **Package Manager**: [npm / yarn / pnpm]
- **Framework**: [Next.js / Express / Nest.js / etc.]
- **Testing**: [Jest / Vitest / etc.]

## Common Commands

```bash
# Install dependencies
[npm install / yarn / pnpm install]

# Development server
[npm run dev / yarn dev / pnpm dev]

# Build for production
[npm run build / yarn build / pnpm build]

# Run tests
[npm test / yarn test / pnpm test]

# Run tests in watch mode
[npm test -- --watch / yarn test --watch]

# Type checking
[npm run type-check / yarn type-check]

# Linting
[npm run lint / yarn lint / pnpm lint]

# Format code
[npm run format / yarn format / pnpm format]
```

## Project Structure

```
project-root/
├── src/
│   ├── components/         # React components (if applicable)
│   ├── lib/                # Shared utilities
│   ├── types/              # TypeScript type definitions
│   ├── api/                # API routes/handlers
│   └── index.ts            # Entry point
├── tests/                  # Test files
├── public/                 # Static assets
└── package.json            # Dependencies and scripts
```

### Key Directories

- `[directory]` - [Purpose]
- `[directory]` - [Purpose]

## Architecture

[Describe your architecture. Examples:]

### Component Structure (for React/Vue)
- Presentational components: Pure UI, no business logic
- Container components: Connect to state/data
- Hooks: Reusable stateful logic

### API Structure (for Backend)
- Routes: Define endpoints
- Controllers: Handle requests
- Services: Business logic
- Repositories: Data access

### [Your Architecture Pattern]
[Describe key architectural decisions]

## TypeScript Best Practices

### Type Safety
- Avoid `any` - use `unknown` if type is truly unknown
- Use strict mode (`"strict": true` in tsconfig.json)
- Define interfaces for data structures
- Use type guards for runtime validation

### Code Conventions
- Use functional programming patterns where appropriate
- Prefer `const` over `let`, never use `var`
- Use async/await over raw Promises
- Destructure objects and arrays

## Testing Strategy

### Test Structure
```typescript
describe('ComponentName', () => {
  it('should do something when condition', () => {
    // Arrange
    // Act
    // Assert
  });
});
```

### Running Tests
```bash
# All tests
[npm test]

# Specific test file
[npm test -- ComponentName.test.ts]

# With coverage
[npm test -- --coverage]

# Update snapshots
[npm test -- -u]
```

### Testing Conventions
- Test files: `*.test.ts` or `*.spec.ts`
- Place tests next to source files or in `tests/` directory
- Mock external dependencies (APIs, databases)
- Test behavior, not implementation details

## Dependencies

### Key Libraries
- [Library]: [Purpose]
- [Library]: [Purpose]

### Managing Dependencies
```bash
# Add dependency
[npm install package-name]

# Add dev dependency
[npm install -D package-name]

# Update dependencies
[npm update]

# Check for outdated packages
[npm outdated]
```

## Common Development Tasks

### Adding a New Component/Module
1. Create file in appropriate directory
2. Define TypeScript interfaces/types
3. Implement functionality
4. Write tests
5. Export from index if needed

### Environment Variables
- Development: `.env.local`
- Production: Set in deployment platform
- Access via `process.env.VARIABLE_NAME`
- Never commit `.env` files

### API Integration
[If applicable:]
- API client: [Location]
- Type definitions: [Location]
- Error handling: [Convention]

## Code Style

### Formatting
- Prettier configuration in `.prettierrc`
- ESLint rules in `.eslintrc`
- Run `[npm run format]` before committing

### Naming Conventions
- Components: PascalCase (`UserProfile.tsx`)
- Functions/variables: camelCase (`getUserData`)
- Constants: UPPER_SNAKE_CASE (`API_BASE_URL`)
- Types/Interfaces: PascalCase (`User`, `ApiResponse`)

## Build & Deployment

### Development Build
```bash
[npm run dev]
```

### Production Build
```bash
[npm run build]
[npm start]  # If applicable
```

### Environment-Specific Config
- Development: Uses `.env.local`
- Production: Uses environment variables from platform
- [Any specific configuration notes]

## Troubleshooting

### Type Errors
- Run `[npm run type-check]` to see all errors
- Check `tsconfig.json` for strict settings
- Ensure all dependencies have type definitions

### Build Errors
```bash
# Clear cache
rm -rf node_modules .next dist
[npm install]

# Check for dependency conflicts
[npm list]
```

### Test Failures
- Check test output for specific errors
- Run single test file to isolate issue
- Clear test cache if using Jest

## Git Workflow

- Branch naming: `feature/description`, `fix/description`
- Commit messages: [Your convention]
- Pre-commit hooks: [Husky, lint-staged, etc.]

## Links & Resources

- [Documentation URL]
- [Issue Tracker URL]
- [Deployment URL]
- [Design System / Storybook]

## Notes for Claude Code

[Add any specific guidance for Claude when working in this codebase]

- [Framework-specific patterns to follow]
- [State management approach]
- [API integration patterns]
- [Specific considerations for this project]
