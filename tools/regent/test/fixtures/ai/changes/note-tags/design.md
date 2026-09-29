# Design: note-tags

<!--
  INSTRUKCJA z szablonu — usuń sekcje, które nie dotyczą zmiany.
-->

## Overview

Tabela `note_tags` (notatka, tag), serwis tagów w domenie notatek, filtr w `GET /notes` i tagi na liście w UI.

## Architektura

### Diagram systemu

```
NoteList ──GET /notes?tag──▶ NotesController ──▶ TagService ──▶ note_tags
```

### Affected Files

<!-- Kontrakt czytania dla apply i verify. -->

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Infrastructure | tabela tagów | migrations/004_note_tags.sql |
| Application | serwis tagów | src/tags/service.ts |
| Interface | filtr w API | src/notes/controller.ts |
| Frontend | tagi na liście | web/NoteList.tsx |

### Component Breakdown

- TagService — normalizacja i zapis tagów

## API / Interface Contract

### GET /notes?tag=x

**Response (200):** lista notatek z polem `tags: string[]`.

```markdown
## to nie jest nagłówek — linia w bloku kodu
```

## Database Changes

```sql
CREATE TABLE note_tags (note_id INTEGER NOT NULL, tag TEXT NOT NULL, PRIMARY KEY (note_id, tag));
```

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| Zapis tagów | osobna tabela | kolumna JSON | filtr po indeksie |

## Odstępstwa od zasad

| Zasada | Odstępstwo | Uzasadnienie | Dlaczego prostsza droga nie wystarczyła |
|--------|------------|--------------|-----------------------------------------|
| MUST-3 | serwis czyta tabelę bez repozytorium | jedno zapytanie | repozytorium tylko przekazywałoby wywołanie |

## Ryzyka

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitygacja |
|--------|-------------------|-------|-----------|
| Duże listy tagów | Low | Low | limit w kolejnej zmianie |

## Error Handling

| Scenariusz | Status | Response | Recovery |
|------------|--------|----------|----------|
| Pusty tag | 400 | `{ "error": "empty tag" }` | popraw wejście |

## Observability / Logging

| Punkt (operacja / błąd) | level | type (business/technical) | action |
|-------------------------|-------|---------------------------|--------|
| tag dodany | info | business | NOTE_TAGGED |

## Testing Strategy

- **Unit:** TagService — normalizacja, duplikaty, pusty tag
- **Component (UI):** NoteList z tagami
- **E2E:** dodanie tagu i filtr

## Security Considerations

- [ ] Input validation — długość tagu
