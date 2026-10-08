# Spec: notes — Delta dla note-export

## ADDED

### REQ-040: Markdown notatki

**Given** notatka
**When** użytkownik eksportuje ją do Markdown
**Then** dostaje tytuł jako nagłówek i treść

**Acceptance Criteria:**
- [ ] AC-1: `toMarkdown(note)` zwraca `# <tytuł>\n\n<treść>\n`; pusta treść daje `# <tytuł>\n`

---

### REQ-041: Eksport wszystkich do Markdown

**Given** lista notatek
**When** użytkownik eksportuje wszystkie
**Then** dostaje jeden dokument

**Acceptance Criteria:**
- [ ] AC-1: `exportMarkdown(notes)` łączy wyniki `toMarkdown` w kolejności listy separatorem `\n---\n\n`; pusta lista → pusty napis

---

### REQ-042: Eksport do JSON

**Given** lista notatek
**When** użytkownik eksportuje ją do JSON
**Then** dostaje tablicę notatek

**Acceptance Criteria:**
- [ ] AC-1: `toJSON(notes)` zwraca tekst JSON tablicy obiektów z polami `id`, `title`, `body`, `createdAt` (bez innych pól)

---

### REQ-043: Import z JSON

**Given** tekst JSON z eksportu
**When** użytkownik go importuje
**Then** dostaje notatki

**Acceptance Criteria:**
- [ ] AC-1: `fromJSON(text)` zwraca tablicę notatek z polami jak w REQ-042
- [ ] AC-2: niepoprawny JSON albo element bez `title` → `InvalidImportError` z `code` `INVALID_IMPORT`

---

## INVARIANTS

- **INV-1:** eksport nie zmienia magazynu notatek
