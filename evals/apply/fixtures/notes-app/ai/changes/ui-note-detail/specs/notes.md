# Spec: notes — Delta dla ui-note-detail

## ADDED

### REQ-070: Szczegóły notatki

**Given** notatka
**When** użytkownik ją otwiera
**Then** widzi tytuł, datę i treść

**Acceptance Criteria:**
- [ ] AC-1: `renderNoteDetail(note)` zwraca `<article>` z tytułem w `<h1>`, datą `RRRR-MM-DD` z `createdAt` w `<time>` i treścią — tekst przez `escapeHtml`

---

### REQ-071: Pusta treść i powrót

**Given** widok szczegółów
**When** notatka nie ma treści
**Then** widać informację o pustej treści i link powrotu

**Acceptance Criteria:**
- [ ] AC-1: pusta treść → „Brak treści” zamiast pustego akapitu
- [ ] AC-2: widok ma link `<a href="#/notes">Wróć do listy</a>`

---

### REQ-072: Tryb edycji

**Given** widok szczegółów
**When** użytkownik włącza albo anuluje edycję
**Then** stan edycji się przełącza

**Acceptance Criteria:**
- [ ] AC-1: `noteDetailReducer(stan, akcja)`: `{ type: 'edit' }` → `editing: true` z kopią tytułu w `draft`, `{ type: 'cancel' }` → `editing: false` bez `draft`

---

## INVARIANTS

- **INV-1:** `test/web-note-list.test.js` przechodzi bez zmian
