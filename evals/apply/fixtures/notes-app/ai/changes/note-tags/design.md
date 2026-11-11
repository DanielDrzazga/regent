# Design: note-tags

## Overview

Migracja `002_create_note_tags` (tabela `note_tags`) i moduł `src/tags.js` z funkcjami tagowania nad bazą w pamięci.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Infrastructure | tabela tagów | migrations/002_create_note_tags.js (nowy), migrations/index.js, test/migrations.test.js |
| Application | tagowanie | src/tags.js (nowy), test/tags.test.js (nowy) |

## API / Interface Contract

- `tagNote(db, noteId: number, tag: string) → void`
- `noteIdsWithTag(db, tag: string) → number[]`

## Database Changes

Tabela `note_tags`: rekordy `{ noteId: number, tag: string }`, unikalna para (noteId, tag). Migracja w formacie `migrations/001_create_notes.js`, dopisana do listy w `migrations/index.js`.

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Zapis tagów | osobna tabela | pole w notatce | filtr po tagu bez skanu notatek |

## Odstępstwa od zasad

Brak.

## Error Handling

| Scenariusz | Błąd | Recovery |
|------------|------|----------|
| Pusty tag | `EmptyTagError` (`code: 'EMPTY_TAG'`) | popraw wejście |

## Testing Strategy

- **Unit:** `test/migrations.test.js` — up/down/up z nową migracją; `test/tags.test.js` — normalizacja, duplikat, wyszukanie
