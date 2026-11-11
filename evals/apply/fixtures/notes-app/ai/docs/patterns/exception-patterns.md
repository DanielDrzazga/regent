# Exception patterns

- Błąd domenowy to klasa dziedzicząca po `Error` z `name` i `code` (wzór: `EmptyTitleError` w `src/notes.js`).
- Funkcje rzucają błąd domenowy; nie zwracają `null` na błędne wejście.
