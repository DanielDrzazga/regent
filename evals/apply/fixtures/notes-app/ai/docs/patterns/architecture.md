# Architecture

- `src/notes.js` — magazyn notatek w pamięci (`createNoteStore`).
- `src/db/` — baza w pamięci i wykonywanie migracji; `migrations/` — migracje w kolejności z `migrations/index.js`.
- `web/` — interfejs: komponenty `(stan) → HTML`, klient API (`ai/docs/patterns/frontend-patterns.md`).
- Nowa funkcja domenowa → nowy moduł w `src/` z czystymi funkcjami; stan tylko w magazynie albo w bazie.

## Reference Implementations

- Magazyn i błąd domenowy: `src/notes.js`
- Migracja: `migrations/001_create_notes.js`, test up/down/up: `test/migrations.test.js`
