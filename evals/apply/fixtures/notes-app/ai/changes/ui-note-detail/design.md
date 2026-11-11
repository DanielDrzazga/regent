# Design: ui-note-detail

## Overview

Widok `web/note-detail.js` (render) i reducer trybu edycji w `web/note-detail-state.js`.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Frontend | widok szczegółów | web/note-detail.js (nowy), test/web-note-detail.test.js (nowy) |
| Frontend | tryb edycji | web/note-detail-state.js (nowy), test/web-note-detail-state.test.js (nowy) |

## API / Interface Contract

Bez nowych endpointów. `renderNoteDetail(note) → string`, `noteDetailReducer(state, action) → state`.

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Data | `createdAt.slice(0, 10)` | `Intl.DateTimeFormat` | format ISO bez strefy |

## Odstępstwa od zasad

Brak.

## Error Handling

Bez błędów — dane z magazynu.

## Testing Strategy

- **Component (UI):** `test/web-note-detail.test.js`, `test/web-note-detail-state.test.js` — każdy AC osobnym testem
