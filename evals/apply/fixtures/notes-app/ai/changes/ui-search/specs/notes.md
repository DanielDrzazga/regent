# Spec: notes — Delta dla ui-search

## ADDED

### REQ-050: Pole wyszukiwania

**Given** widok listy notatek
**When** użytkownik wpisuje frazę albo ją czyści
**Then** pole pokazuje aktualną frazę

**Acceptance Criteria:**
- [ ] AC-1: `renderSearchBox({ query })` zwraca formularz z `role="search"`, etykietą „Szukaj” powiązaną z polem (`label for`) i wartością pola równą frazie (tekst przez `escapeHtml`)
- [ ] AC-2: `searchReducer(stan, akcja)`: akcja `{ type: 'input', value }` ustawia `query`, akcja `{ type: 'clear' }` ustawia pusty `query`

---

### REQ-051: Licznik wyników

**Given** wynik wyszukiwania
**When** widok pokazuje liczbę notatek
**Then** liczba ma poprawną polską odmianę

**Acceptance Criteria:**
- [ ] AC-1: `renderResultCount(n)` zwraca `<p role="status">…</p>` z tekstem: 0 → „Brak wyników”, 1 → „1 notatka”, 2–4 oraz 22–24, 32–34… (bez 12–14) → „N notatki”, pozostałe → „N notatek”

---

## INVARIANTS

- **INV-1:** istniejące testy `test/web-note-list.test.js` przechodzą bez zmian
