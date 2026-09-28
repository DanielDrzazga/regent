# Testing Patterns

> Opcjonalny. Wypełnij na podstawie istniejących testów i konfiguracji test runnera.

## Piramida testów

| Typ | Target | Fokus |
|-----|--------|-------|
| Unit | ≥80% coverage | Logika biznesowa, walidacja, utility |
| Component (UI) | Kluczowe komponenty | Render + interakcja + zachowanie (jeśli projekt ma frontend) |
| Integration | Key flows | API endpoints, operacje DB |
| E2E | Critical paths | Pełne scenariusze API i/lub przeglądarkowe |

## Struktura

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
# + tests/component/ lub kolokacja *.test.tsx przy komponencie — wg konwencji projektu
```

## Mocks-first

- Mockuj zależności zewnętrzne; **NIGDY** nie duplikuj kodu produkcyjnego w testach.
- Współdziel mocki/factory z `tests/helpers/` — brak inline mocków (DRY).
- Integration/E2E: real DB (testcontainers / test DB), mock TYLKO external API.

## Zasady

- **Behavior, not implementation** — testuj CO, nie JAK.
- **Arrange-Act-Assert**.
- Nazwy opisowe: `should_return_error_when_email_is_invalid`.
- One test = one scenario; brak flaky testów.
- Czasy: unit < 100ms, integration < 1s, e2e < 5s.
- Każde AC ma test; edge cases i error paths pokryte.

## Testy UI (jeśli projekt ma frontend — usuń w backend-only)

- **Component tests**: render + interakcja użytkownika + asercja na widoczne zachowanie
  (nie wewnętrzny stan); mock HTTP wg `frontend-patterns.md` (sekcja Testy komponentowe).
- **E2E przeglądarkowe**: tylko critical paths (logowanie, core flows); realny backend.
- Selektory user-facing (role/label), `data-testid` tylko gdy brak roli.
- Narzędzia i konwencje: `ai/docs/patterns/frontend-patterns.md` — jedno źródło.

## Narzędzia

| Element | Wartość |
|---------|---------|
| Runner | [np. Jest / Vitest] |
| Coverage | [np. c8] |
| Komendy | `make test`, `make test-unit`, `make test-component` (UI), `make test-coverage` |
