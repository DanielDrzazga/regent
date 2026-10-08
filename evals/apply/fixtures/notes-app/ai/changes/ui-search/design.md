# Design: ui-search

## Overview

Dwa nowe komponenty w `web/` wg `frontend-patterns.md`: pole wyszukiwania z reducerem i licznik wyników.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Frontend | pole wyszukiwania | web/search-box.js (nowy), test/web-search-box.test.js (nowy) |
| Frontend | licznik wyników | web/result-count.js (nowy), test/web-result-count.test.js (nowy) |

## API / Interface Contract

Bez nowych endpointów.

- `renderSearchBox({ query }) → string`, `searchReducer(state, action) → state`
- `renderResultCount(n: number) → string`

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Odmiana | funkcja w komponencie | biblioteka i18n | jedna reguła, bez zależności |

## Odstępstwa od zasad

Brak.

## Error Handling

Bez błędów — wejście z interfejsu.

## Testing Strategy

- **Component (UI):** `test/web-search-box.test.js` (render, akcje input i clear, escapowanie wartości), `test/web-result-count.test.js` (0, 1, 2, 5, 12, 22)
