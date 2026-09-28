# Exception Patterns

> Opcjonalny. Wypełnij, jeśli `/regent:init` wykryje własne klasy wyjątków / globalny error handler.

## Hierarchia wyjątków

| Wyjątek | Kiedy | HTTP status |
|---------|-------|-------------|
| [np. `DomainError`] | Naruszenie reguły biznesowej | 422 / 400 |
| [np. `NotFoundError`] | Zasób nie istnieje | 404 |
| [np. `ValidationError`] | Nieprawidłowe dane wejściowe | 400 |
| [np. `UnauthorizedError`] | Brak autoryzacji | 401 / 403 |

## Zasady

- Rzucaj **typowane** wyjątki domenowe, nie generyczne `Error`.
- Wyjątki domenowe w `domain/`/`application/`; mapowanie na HTTP w `interface/`.
- Globalny handler mapuje wyjątki → odpowiedź (kod + bezpieczny komunikat).
- **Nie ujawniaj** szczegółów wewnętrznych/stack trace w odpowiedzi do klienta.
- Błędy loguj `technical()` + `error` z `{ message, stack, code }` (→ `logging-patterns.md`).

## Globalny handler

- [Mechanizm — np. NestJS `ExceptionFilter` / Express error middleware]
- [Ścieżka — np. `src/core/exceptions/`]

## Format odpowiedzi błędu

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Bezpieczny komunikat dla klienta"
  }
}
```
