# Spec: notes — Delta dla note-search

## ADDED

### REQ-010: Wyszukiwanie notatek

**Given** magazyn z notatkami
**When** użytkownik szuka frazy
**Then** dostaje notatki, których tytuł albo treść zawiera frazę

**Acceptance Criteria:**
- [ ] AC-1: `searchNotes(store, query)` dopasowuje frazę w tytule i treści bez względu na wielkość liter, wynik od najnowszej
- [ ] AC-2: pusta fraza (także same spacje) zwraca wszystkie notatki od najnowszej

---

### REQ-011: Limit długości tytułu

**Given** użytkownik tworzący notatkę
**When** tytuł po przycięciu ma więcej niż 80 znaków
**Then** notatka się nie zapisuje

**Acceptance Criteria:**
- [ ] AC-1: tytuł dłuższy niż 80 znaków po przycięciu → `TitleTooLongError` z `code` `TITLE_TOO_LONG`; 80 znaków przechodzi

---

## INVARIANTS

- **INV-1:** istniejące testy `test/notes.test.js` przechodzą bez zmian
