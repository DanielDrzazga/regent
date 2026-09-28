# Logging Patterns

> Źródło prawdy dla `/regent:logging` i agenta `regent:logging-engineer`. Opisuje **istniejący** logger
> projektu — ścieżkę importu, API, poziomy i zasady. NIE jest instrukcją budowy loggera.
> Wypełnij konkretami wykrytymi przez `/regent:init` lub podanymi w wywiadzie.

## Status

- [ ] Standard logowania **wdrożony** (logger istnieje w kodzie)
- [ ] Standard logowania **do wdrożenia** (brak loggera — `/regent:logging` przerwie i zapyta)

## Logger

| Pole | Wartość |
|------|---------|
| Biblioteka | [np. nestjs-pino / winston / pino / CustomLoggerService] |
| Ścieżka importu | [np. `src/core/logging/custom-logger.service`] |
| Sposób wstrzykiwania | [np. DI przez konstruktor: `private readonly logger: CustomLoggerService`] |
| Format wyjścia | [np. JSON strukturalny] |

## API loggera

Opisz dokładne metody używane w projekcie. Przykład dla `CustomLoggerService`:

```typescript
this.logger.business({
  action: "MESSAGE_SENT",          // RZECZOWNIK_CZASOWNIK, UPPERCASE, EN
  module: "WhatsAppSenderService", // nazwa klasy logującej
  message: "Wysłano wiadomość",    // opis naturalny
  context: { recipientId: "usr_123", templateId: "order_v1" }, // TYLKO ID encji
});

this.logger.technical({
  action: "META_API_ERROR",
  module: "WhatsAppSenderService",
  message: "Błąd Meta API",
  error: { message: err.message, stack: err.stack, code: err.response?.status },
});
```

Jeśli projekt używa loggera natywnego (np. `Logger` z NestJS albo `pino`) — opisz tu jego API zamiast powyższego.

## Poziomy

| level | Kiedy |
|-------|-------|
| `debug` | Diagnostyka, wejścia/wyjścia metod, stany pośrednie (off na prod) |
| `info`  | Normalny przebieg / zdarzenie biznesowe OK |
| `warn`  | Odzyskiwalne — retry, fallback, brak danych nieblokujący |
| `error` | Błąd operacji (z obiektem `error`) |
| `fatal` | Krytyczny / nieodzyskiwalny |

## Typy logów

- **`business()`** — zdarzenie domenowe zrozumiałe dla nietechnicznego odbiorcy.
- **`technical()`** — HTTP/axios/DB/retry/błędy oraz wszystko inne.

## Dekoratory / helpery (jeśli są)

- [np. `@LogDuration()` — mierzy czas metody]
- [np. `@WithEventContext()` — handler CQRS, ustawia `contextType: event`]

## Zasady (twarde)

- `action`: `RZECZOWNIK_CZASOWNIK`, UPPERCASE, EN (`MESSAGE_SENT`, nie `sendMessage`).
- `context`: TYLKO ID encji — **zero PII/sekretów** (telefon, e-mail, token, hasło).
- Jeden log per operacja — nie w pętli / hot-path.
- Nie loguj w warstwie `domain/` — tylko application/infrastructure/interface.
- Nie dubluj logu requestu (jest interceptor HTTP / axios logger).
- Pola `contextId` / `contextType` / `@timestamp` ustawiane automatycznie — nie ręcznie.

## Przykłady per warstwa

- **Application (use case):** `info` + `business()` na wejściu/wyjściu operacji domenowej.
- **Infrastructure (integracja):** `technical()` na wywołaniach zewnętrznych i w `catch`.
- **Interface (controller):** zwykle pokryte przez interceptor — nie dubluj.

## Synchronizacja z observability (opcjonalne — jeśli projekt ma `ai/docs/observability/`)

Jeśli projekt utrzymuje dashboardy/alerty (Kibana) w `ai/docs/observability/`, a filtrują one po
konkretnych wartościach `action` (często zaszytych na sztywno w agregacji Filters) — **zmiana `action`
cicho psuje dashboard/alert** (panel pokaże 0, nic nie ostrzeże). Po dodaniu / zmianie nazwy / usunięciu
logowanej `action` (lub zmianie `type`/`module`) sprawdź `ai/docs/observability/maintenance.md`.

Ten link egzekwują: `/regent:logging` (Krok 4.5) i `/regent:verify` (Etap 7). Jeśli projekt nie ma observability —
pomiń tę sekcję.
