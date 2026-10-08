# Design: note-export

## Overview

Dwa moduły czystych funkcji: `src/export.js` (Markdown) i `src/json.js` (JSON w obie strony).

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Application | Markdown | src/export.js (nowy), test/export.test.js (nowy) |
| Application | JSON | src/json.js (nowy), test/json.test.js (nowy) |

## API / Interface Contract

- `toMarkdown(note) → string`, `exportMarkdown(notes) → string`
- `toJSON(notes) → string`, `fromJSON(text) → Note[]` — rzuca `InvalidImportError` (`code: 'INVALID_IMPORT'`)

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Format | Markdown i JSON | CSV | Markdown do czytania, JSON do przenoszenia |

## Odstępstwa od zasad

Brak.

## Error Handling

| Scenariusz | Błąd | Recovery |
|------------|------|----------|
| Zły plik importu | `InvalidImportError` | popraw plik |

## Testing Strategy

- **Unit:** `test/export.test.js`, `test/json.test.js` — każdy AC osobnym testem
