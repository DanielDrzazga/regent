# Testing patterns

- `node:test` (`test`) + `node:assert/strict`; jeden plik testów na moduł.
- Każdy test tworzy własny magazyn/bazę — bez stanu współdzielonego między testami.
- Zegar w testach stały: `const fixedClock = () => new Date('2026-10-01T10:00:00Z')`.
- Nazwy testów po angielsku, opisują zachowanie (`rejects an empty title`).
- Migracja: test up → down → up na świeżej bazie.

## Testy UI

- Komponenty w `test/web-<komponent>.test.js`; wzorzec render → akcja → widoczny HTML w
  `ai/docs/patterns/frontend-patterns.md` (sekcja Testy komponentowe).
