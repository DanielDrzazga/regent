# Code Style

> Wypełnij na podstawie eslint/prettier/tsconfig wykrytych przez `/regent:init`.

## Narzędzia

| Narzędzie | Konfiguracja | Komenda |
|-----------|--------------|---------|
| Linter | [np. ESLint — `.eslintrc.js`] | `make lint` |
| Formatter | [np. Prettier — `.prettierrc`] | `make format` |
| Type-check | [np. tsc — `tsconfig.json`] | `make type-check` |

## Formatowanie

| Reguła | Wartość |
|--------|---------|
| Wcięcia | [np. 2 spacje] |
| Cudzysłowy | [np. single] |
| Średniki | [tak / nie] |
| Max długość linii | [np. 100] |
| Trailing comma | [np. all] |

## Zasady jakości

- Funkcja robi JEDNĄ rzecz (SRP).
- Max 3 poziomy zagnieżdżenia.
- Brak dead code / zakomentowanego kodu.
- Brak `console.log` / debug w commitach.
- Error handling kompletny i typowany (→ `exception-patterns.md`).
- Brak duplikacji logiki (DRY).
- Reuse przed implementacją — sprawdź, czy helper/util/wzorzec już nie istnieje.

## Importy

- [Kolejność — np. zewnętrzne → wewnętrzne → względne]
- [Aliasy ścieżek — np. `@modules/*`, `@core/*`]
