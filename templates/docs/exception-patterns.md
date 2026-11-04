# Exception Patterns

> Optional. Fill in if `/regent:init` detects custom exception classes / a global error handler.

## Exception hierarchy

| Exception | When | HTTP status |
|-----------|------|-------------|
| [e.g. `DomainError`] | Business rule violation | 422 / 400 |
| [e.g. `NotFoundError`] | Resource does not exist | 404 |
| [e.g. `ValidationError`] | Invalid input data | 400 |
| [e.g. `UnauthorizedError`] | No authorization | 401 / 403 |

## Rules

- Throw **typed** domain exceptions, not a generic `Error`.
- Domain exceptions in `domain/`/`application/`; mapping to HTTP in `interface/`.
- A global handler maps exceptions → response (code + safe message).
- **Do not expose** internal details/stack trace in the response to the client.
- Log errors with `technical()` + `error` with `{ message, stack, code }` (→ `logging-patterns.md`).

## Global handler

- [Mechanism — e.g. NestJS `ExceptionFilter` / Express error middleware]
- [Path — e.g. `src/core/exceptions/`]

## Error response format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Safe message for the client"
  }
}
```
