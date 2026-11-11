# Spec: notes — Delta dla note-archive

## ADDED

### REQ-020: Archiwizacja notatki

**Given** magazyn z notatką
**When** użytkownik ją archiwizuje
**Then** notatka jest oznaczona jako zarchiwizowana

**Acceptance Criteria:**
- [ ] AC-1: `store.archive(id)` ustawia `archived: true` i zwraca kopię notatki; nowa notatka ma `archived: false`
- [ ] AC-2: nieistniejące `id` → `NoteNotFoundError` z `code` `NOTE_NOT_FOUND`

---

### REQ-021: Lista bez zarchiwizowanych

**Given** magazyn z notatkami, w tym zarchiwizowanymi
**When** użytkownik otwiera listę
**Then** domyślnie nie widzi zarchiwizowanych

**Acceptance Criteria:**
- [ ] AC-1: `store.list()` pomija zarchiwizowane, kolejność od najnowszej bez zmian
- [ ] AC-2: `store.list({ includeArchived: true })` zwraca wszystkie

---

## INVARIANTS

- **INV-1:** `store.list()` bez zarchiwizowanych notatek zwraca to samo co przed zmianą
