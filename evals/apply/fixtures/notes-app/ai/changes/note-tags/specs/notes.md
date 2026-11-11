# Spec: notes — Delta dla note-tags

## ADDED

### REQ-030: Tabela tagów

**Given** baza po migracji 001
**When** wykonuje się migracja tagów
**Then** baza ma tabelę `note_tags`

**Acceptance Criteria:**
- [ ] AC-1: migracja `002_create_note_tags` tworzy `db.tables.note_tags` (pusta tablica), `down` ją usuwa, a up/down/up przechodzi

---

### REQ-031: Tagowanie notatek

**Given** baza z tabelą `note_tags`
**When** użytkownik dodaje tag do notatki
**Then** tag zapisuje się raz, małymi literami

**Acceptance Criteria:**
- [ ] AC-1: `tagNote(db, noteId, tag)` zapisuje rekord `{ noteId, tag }` z tagiem przyciętym i małymi literami
- [ ] AC-2: ten sam tag drugi raz dla tej samej notatki nie tworzy duplikatu
- [ ] AC-3: `noteIdsWithTag(db, tag)` zwraca identyfikatory notatek z tagiem (bez względu na wielkość liter)

---

## INVARIANTS

- **INV-1:** migracja 001 i jej test działają bez zmian
