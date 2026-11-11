# Logging Patterns

> Source of truth for `/regent:logging` and the `regent:logging-engineer` agent. Describes the project's **existing** logger
> — import path, API, levels and rules. It is NOT an instruction for building a logger.
> Fill in with specifics detected by `/regent:init` or given in the interview.

## Status

- [ ] Logging standard **deployed** (the logger exists in the code)
- [ ] Logging standard **to be implemented** (no logger — `/regent:logging` will stop and ask)

## Logger

| Field | Value |
|-------|-------|
| Library | [e.g. nestjs-pino / winston / pino / CustomLoggerService] |
| Import path | [e.g. `src/core/logging/custom-logger.service`] |
| Injection method | [e.g. DI through the constructor: `private readonly logger: CustomLoggerService`] |
| Output format | [e.g. structured JSON] |

## Logger API

Describe the exact methods used in the project. Example for `CustomLoggerService`:

```typescript
this.logger.business({
  action: "MESSAGE_SENT",          // NOUN_VERB, UPPERCASE, EN
  module: "WhatsAppSenderService", // name of the logging class
  message: "Message sent",         // natural description
  context: { recipientId: "usr_123", templateId: "order_v1" }, // entity IDs ONLY
});

this.logger.technical({
  action: "META_API_ERROR",
  module: "WhatsAppSenderService",
  message: "Meta API error",
  error: { message: err.message, stack: err.stack, code: err.response?.status },
});
```

If the project uses a native logger (e.g. `Logger` from NestJS or `pino`) — describe its API here instead of the above.

## Levels

| level | When |
|-------|------|
| `debug` | Diagnostics, method inputs/outputs, intermediate states (off in prod) |
| `info`  | Normal flow / business event OK |
| `warn`  | Recoverable — retry, fallback, non-blocking missing data |
| `error` | Operation error (with an `error` object) |
| `fatal` | Critical / unrecoverable |

## Log types

- **`business()`** — a domain event understandable to a non-technical audience.
- **`technical()`** — HTTP/axios/DB/retry/errors and everything else.

## Decorators / helpers (if any)

- [e.g. `@LogDuration()` — measures method duration]
- [e.g. `@WithEventContext()` — CQRS handler, sets `contextType: event`]

## Rules (hard)

- `action`: `NOUN_VERB`, UPPERCASE, EN (`MESSAGE_SENT`, not `sendMessage`).
- `context`: entity IDs ONLY — **zero PII/secrets** (phone, e-mail, token, password).
- One log per operation — not in a loop / hot path.
- Do not log in the `domain/` layer — only application/infrastructure/interface.
- Do not duplicate the request log (there is an HTTP interceptor / axios logger).
- The `contextId` / `contextType` / `@timestamp` fields are set automatically — not manually.

## Examples per layer

- **Application (use case):** `info` + `business()` on entry/exit of a domain operation.
- **Infrastructure (integration):** `technical()` on external calls and in `catch`.
- **Interface (controller):** usually covered by the interceptor — do not duplicate.

## Synchronization with observability (optional — if the project has `ai/docs/observability/`)

If the project maintains dashboards/alerts (Kibana) in `ai/docs/observability/`, and they filter on
specific `action` values (often hardcoded in a Filters aggregation) — **changing an `action`
silently breaks the dashboard/alert** (the panel shows 0, nothing warns). After adding / renaming / removing
a logged `action` (or changing `type`/`module`), check `ai/docs/observability/maintenance.md`.

This link is enforced by: `/regent:logging` (Step 4.5) and `/regent:verify` (Stage 7). If the project has no observability —
skip this section.
