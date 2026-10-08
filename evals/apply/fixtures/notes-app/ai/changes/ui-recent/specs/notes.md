# Spec: notes — Delta dla ui-recent

## ADDED

### REQ-060: Endpoint ostatnich notatek

**Given** magazyn z notatkami
**When** klient pyta o `GET /notes?limit=N`
**Then** dostaje N najnowszych notatek i ich łączną liczbę

**Acceptance Criteria:**
- [ ] AC-1: `handleGetNotes(store, { limit })` zwraca `{ status: 200, body: { notes, total } }` — `notes` to najwyżej `limit` notatek od najnowszej, `total` to liczba wszystkich
- [ ] AC-2: `limit` spoza 1–50 albo niecałkowity → `{ status: 400, body: { error: 'invalid_limit' } }`

---

### REQ-061: Widok ostatnich notatek

**Given** widok startowy
**When** wczytuje ostatnie notatki
**Then** pokazuje je albo czytelny błąd

**Acceptance Criteria:**
- [ ] AC-1: `loadRecentNotes(api, limit)` wywołuje `api.getRecentNotes(limit)` (`GET /notes?limit=N` w `web/api-client.js`) i zwraca stan `ready` z notatkami i `total`; błąd API → stan `error`
- [ ] AC-2: `renderRecentNotes(stan)` pokazuje tytuły (przez `escapeHtml`) i „Pokazano X z Y”; stan `error` → `role="alert"` z tekstem „Nie udało się wczytać ostatnich notatek”

---

## INVARIANTS

- **INV-1:** `api.listNotes()` działa jak dotąd
