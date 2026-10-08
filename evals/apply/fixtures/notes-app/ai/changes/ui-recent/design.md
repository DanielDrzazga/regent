# Design: ui-recent

## Overview

Handler HTTP `handleGetNotes` w `src/http.js` i widok ostatnich notatek w `web/recent-notes.js`, który
korzysta z nowej metody klienta API. BE i FE idą niezależnie — FE mockuje HTTP wg kontraktu.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Interface | endpoint | src/http.js (nowy), test/http.test.js (nowy) |
| Frontend | klient API, widok | web/api-client.js, web/recent-notes.js (nowy), test/web-recent-notes.test.js (nowy) |

## API / Interface Contract

### GET /notes?limit=N

- **200:** `{ "notes": [{ "id": 3, "title": "…", "body": "…", "createdAt": "…" }], "total": 12 }` — notatki od najnowszej
- **400:** `{ "error": "invalid_limit" }` — limit spoza 1–50 albo niecałkowity

Handler: `handleGetNotes(store, { limit }) → { status, body }`. Klient: `api.getRecentNotes(limit)` → `body` dla 200, `ApiError` dla 400.

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Handler | czysta funkcja `(store, query) → { status, body }` | serwer HTTP | testowalny bez sieci |

## Odstępstwa od zasad

Brak.

## Error Handling

| Scenariusz | Status | Response | Recovery |
|------------|--------|----------|----------|
| Zły limit | 400 | `{ "error": "invalid_limit" }` | UI pokazuje błąd |

## Testing Strategy

- **Unit:** `test/http.test.js` — limit, kolejność, `total`, 400
- **Component (UI):** `test/web-recent-notes.test.js` — `fetch` podmieniony wg kontraktu: 200 i 400
