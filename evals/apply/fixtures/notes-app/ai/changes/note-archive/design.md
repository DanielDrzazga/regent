# Design: note-archive

## Overview

Pole `archived` w notatce, metoda `archive(id)` i opcja `includeArchived` w `list` — wszystko w `src/notes.js`.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Domain | archiwizacja, filtr listy | src/notes.js, test/notes.test.js |

## API / Interface Contract

- `store.archive(id: number) → Note` — rzuca `NoteNotFoundError` (`code: 'NOTE_NOT_FOUND'`), eksportowany z `src/notes.js`.
- `store.list({ includeArchived = false } = {}) → Note[]`.

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Archiwum | flaga w notatce | osobna lista | jedno źródło notatek |

## Odstępstwa od zasad

Brak.

## Error Handling

| Scenariusz | Błąd | Recovery |
|------------|------|----------|
| Archiwizacja nieistniejącej notatki | `NoteNotFoundError` | odśwież listę |

## Testing Strategy

- **Unit:** `test/notes.test.js` — archiwizacja, brak notatki, lista z i bez zarchiwizowanych
