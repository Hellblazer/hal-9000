# CLAUDE.md - TypeScript Project Template

## Project

**Name**: [PROJECT_NAME]
**Description**: [DESCRIPTION]
**Node**: [VERSION]
**Manager**: [npm/yarn/pnpm]
**Framework**: [Next.js/Express/Nest.js/None]

## Commands

```bash
npm install                       # Install
npm run dev                       # Dev server
npm run build                     # Build
npm test                          # Tests
npm test -- --watch               # Watch mode
npm run lint                      # Lint
npm run format                    # Format
```

## Structure

```
src/
  components/   # UI (React)
  lib/          # Utilities
  types/        # Type definitions
  api/          # API routes
tests/
package.json
tsconfig.json
```

## Conventions

- Strict mode enabled
- No `any` - use `unknown` if needed
- `const` over `let`, never `var`
- async/await over raw Promises
- Interfaces for data structures

## Testing

- Files: `*.test.ts` or `*.spec.ts`
- Mock external dependencies
- Test behavior, not implementation

## Naming

- Components: PascalCase
- Functions/vars: camelCase
- Constants: UPPER_SNAKE_CASE
- Types: PascalCase

## Key Modules

- [MODULE] - [PURPOSE]

## Notes

[PROJECT-SPECIFIC GUIDANCE]
