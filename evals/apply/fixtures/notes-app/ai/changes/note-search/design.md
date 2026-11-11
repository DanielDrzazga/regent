# Design: note-search

## Overview

Nowy moduł `src/search.js` z czystą funkcją wyszukiwania nad `store.list()` oraz walidacja długości tytułu w `store.create`.

## Architektura

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Application | wyszukiwanie | src/search.js (nowy), test/search.test.js (nowy) |
| Domain | limit tytułu | src/notes.js, test/notes.test.js |

## API / Interface Contract

- `searchNotes(store, query: string) → Note[]` — kopie notatek od najnowszej.
- `store.create({ title, body })` — rzuca `TitleTooLongError` (`code: 'TITLE_TOO_LONG'`), eksportowany z `src/notes.js`.

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Wyszukiwanie | filtr nad `store.list()` | indeks | kilkadziesiąt notatek, indeks to przerost |
| Limit tytułu | 80 znaków po przycięciu | limit przed przycięciem | spacje na brzegach nie są treścią |

## Odstępstwa od zasad

Brak.

## Error Handling

| Scenariusz | Błąd | Recovery |
|------------|------|----------|
| Tytuł > 80 znaków | `TitleTooLongError` | użytkownik skraca tytuł |

## Testing Strategy

- **Unit:** `test/search.test.js` — tytuł, treść, wielkość liter, pusta fraza; `test/notes.test.js` — 80 i 81 znaków
