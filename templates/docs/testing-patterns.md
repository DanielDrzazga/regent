# Testing Patterns

> Optional. Fill in based on the existing tests and the test runner configuration.

## Test pyramid

| Type | Target | Focus |
|------|--------|-------|
| Unit | ≥80% coverage | Business logic, validation, utility |
| Component (UI) | Key components | Render + interaction + behavior (if the project has a frontend) |
| Integration | Key flows | API endpoints, DB operations |
| E2E | Critical paths | Full API and/or browser scenarios |

## Structure

```
tests/
├── helpers/
│   ├── factories/   # createTestUser(), createTestOrder()
│   ├── mocks/       # mockUserRepository(), mockPaymentGateway()
│   ├── builders/    # UserBuilder.withEmail('x').build()
│   └── setup/       # setupTestDb(), createTestApp()
├── unit/
├── integration/
└── e2e/
# + tests/component/ or *.test.tsx colocated with the component — per the project convention
```

## Mocks-first

- Mock external dependencies; **NEVER** duplicate production code in tests.
- Share mocks/factories from `tests/helpers/` — no inline mocks (DRY).
- Integration/E2E: real DB (testcontainers / test DB), mock ONLY external APIs.

## Rules

- **Behavior, not implementation** — test WHAT, not HOW.
- **Arrange-Act-Assert**.
- Descriptive names: `should_return_error_when_email_is_invalid`.
- One test = one scenario; no flaky tests.
- Durations: unit < 100ms, integration < 1s, e2e < 5s.
- Every AC has a test; edge cases and error paths covered.

## UI tests (if the project has a frontend — remove in backend-only)

- **Component tests**: render + user interaction + assertion on visible behavior
  (not internal state); HTTP mock per `frontend-patterns.md` (Component tests section).
- **Browser E2E**: critical paths only (login, core flows); real backend.
- User-facing selectors (role/label), `data-testid` only when there is no role.
- Tools and conventions: `ai/docs/patterns/frontend-patterns.md` — single source.

## Tools

| Element | Value |
|---------|-------|
| Runner | [e.g. Jest / Vitest] |
| Coverage | [e.g. c8] |
| Commands | `make test`, `make test-unit`, `make test-component` (UI), `make test-coverage` |
