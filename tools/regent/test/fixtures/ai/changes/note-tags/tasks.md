# Tasks: note-tags

## Setup
- [x] T-01: [DB] Migracja: tabela note_tags — REQ-004 — pliki: migrations/004_note_tags.sql — weryfikacja: migracja up/down/up ✅ (commit: 1a2b3c4 · testy: REQ-004 → test/migrations.test.ts › note_tags up/down)

## Implementation
- [ ] T-02: [BE] Serwis tagów — REQ-004/AC-1..3 — pliki: src/tags/service.ts — weryfikacja: testy REQ-004/AC-1..3 zielone (po T-01)
- [ ] T-03: [BE] Filtr GET /notes?tag — REQ-005/AC-1 — pliki: src/notes/controller.ts — weryfikacja: test API REQ-005/AC-1 (po T-02)
- [ ] T-04: [FE] Tagi na liście notatek — REQ-002/AC-2, REQ-005/AC-2 — pliki: web/NoteList.tsx — design: Observability — weryfikacja: test komponentu (po T-01)
- [ ] T-05: Indeks tagów — REQ-005/AC-1 — pliki: src/tags/index.ts — weryfikacja: test indeksu (po T-01)

```markdown
- [ ] T-99: przykład w bloku kodu — nie jest taskiem
```

## Integracja / E2E
- [ ] T-06: [BE] E2E tagów — REQ-004, REQ-005 — pliki: e2e/tags.e2e.ts — weryfikacja: test E2E zielony (po T-03, T-04)

---
Total: 6 tasks | Size: M
