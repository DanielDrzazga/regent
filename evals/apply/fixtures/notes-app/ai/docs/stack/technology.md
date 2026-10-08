# Technology

| Obszar | Wybór |
|--------|-------|
| Język | JavaScript (ESM, `"type": "module"`), Node ≥ 22 |
| Zależności | brak — tylko biblioteka standardowa Node |
| Baza danych | w pamięci: `src/db/database.js`, migracje `migrations/NNN_nazwa.js` (`id`, `up`, `down`) |
| Testy | `node:test` + `node:assert/strict`, pliki `test/<moduł>.test.js` |

## Kontrakt make

| Cel | Co robi |
|-----|---------|
| `make test-unit PATTERN=<moduł>` | testy z plików `test/*<moduł>*.test.js` |
| `make test` | wszystkie testy |
| `make lint` | `node --check` wszystkich plików |
| `make type-check` | n/d (JavaScript bez typów) |
| `make check` | lint + type-check + test |

## Frontend

| Obszar | Wybór |
|--------|-------|
| UI | bez frameworka: komponenty w `web/` jako funkcje `(stan) → HTML` (string) — wzorzec w `ai/docs/patterns/frontend-patterns.md` |
| Testy komponentów | `node:test`, pliki `test/web-<komponent>.test.js`, cel `make test-component PATTERN=<komponent>` |
