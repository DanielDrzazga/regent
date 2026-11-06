# Code Style

> Fill in based on the eslint/prettier/tsconfig detected by `/regent:init`.

## Tools

| Tool | Configuration | Command |
|------|---------------|---------|
| Linter | [e.g. ESLint — `.eslintrc.js`] | `make lint` |
| Formatter | [e.g. Prettier — `.prettierrc`] | `make format` |
| Type-check | [e.g. tsc — `tsconfig.json`] | `make type-check` |

## Formatting

| Rule | Value |
|------|-------|
| Indentation | [e.g. 2 spaces] |
| Quotes | [e.g. single] |
| Semicolons | [yes / no] |
| Max line length | [e.g. 100] |
| Trailing comma | [e.g. all] |

## Quality rules

- A function does ONE thing (SRP).
- Max 3 levels of nesting.
- No dead code / commented-out code.
- No `console.log` / debug in commits.
- Error handling complete and typed (→ `exception-patterns.md`).
- No duplicated logic (DRY).
- Reuse before implementing — check whether a helper/util/pattern already exists.

## Imports

- [Order — e.g. external → internal → relative]
- [Path aliases — e.g. `@modules/*`, `@core/*`]
