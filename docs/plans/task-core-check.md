# Plan: task-core-check

> Poprawki przed tygodniem sprawdzenia etapu 1 (`docs/plans/task-core.md`, Przebieg sesji 4).
> Lekka ścieżka: gałąź `feat/task-core-check`, ten plan, bramka i smoke. Decyzje użytkownika
> 2026-09-29: skrypt pomiaru trafia do repo, nazwę sekcji kontraktu poprawić od razu.

## Cel

1. **Kontrakt API trafia do paczki.** W projekcie prywatnym 5 z 29 designów nazywa sekcję
   „Kontrakt API↔UI”, bo tak mówi checklista `agents/architect.md`, a szablon i reguła paczki —
   „API / Interface Contract”. Każda paczka `[BE]`/`[FE]` z takiego designu jest bez kontraktu.
2. **Porównanie po tygodniu jednym poleceniem.** Pomiar z T11 (skrypt w scratchpadzie) trafia do
   `tools/watch/` jako `regent-apply-tokens`: ta sama metryka, podział na uruchomienia z paczką
   i bez, zliczenie `BRAK W PACZCE` wg sekcji — oba kryteria „Sprawdzenia etapu” z transkryptów.

## Decyzje

| Decyzja | Wartość |
|---|---|
| Paczka | alias: gdy design nie ma sekcji „API / Interface Contract”, paczka bierze pierwszą sekcję, której nagłówek zaczyna się od „Kontrakt API”. Nazwa z szablonu ma pierwszeństwo; brak obu → „Brak w design.md: API / Interface Contract” jak dotąd |
| Agent | checklista `architect` wskazuje sekcję „API / Interface Contract” z nazwy; regresja w `framework-lint.sh` sekcja 7 |
| Narzędzie | bin `regent-apply-tokens` w pakiecie `tools/watch` (parser transkryptów już tam jest): czysta funkcja w `src/parse/firstturn.ts`, polecenie w `src/apply-tokens.ts` (wejście i wyjście przez `Io`, jak `tools/regent/src/main.ts`), punkt wejścia `src/apply-tokens-cli.ts`. Tylko odczyt, wynik to same liczby |
| Próbka | subagenci `backend-dev`, `frontend-dev`, `dba` (z prefiksem `regent:` i bez), prompt z `ai/changes/`. `--project <katalog>` (powtarzalne) zawęża po `cwd` z rekordów (katalog i podkatalogi, więc też worktree), `--since`/`--until RRRR-MM-DD` po dacie lokalnej pierwszego rekordu. Grupy: bez paczki i z paczką (`# Paczka:` w prompcie) |
| Metryka | jak w Przebiegu sesji 4: tura do `end_turn` albo `turn_duration`, wejście = input + zapis i odczyt cache (`usageFromRecord`), deduplikacja po `message.id`. Mediany: suma pierwszej tury, wywołania API, kontekst pierwszego wywołania, przy pierwszej edycji, maksymalny, odczyt plików zmiany (`tasks.md`, `design.md`, `specs/`, bajty / 3,5) |
| `BRAK W PACZCE` | linie `BRAK W PACZCE: <plik> › <sekcja> — …` z tekstu odpowiedzi subagenta (bez wzorca z promptu), zliczone per `<plik> › <sekcja>` |

## Taski

- [x] T1: paczka — alias „Kontrakt API” dla „API / Interface Contract” (nazwa z szablonu wygrywa),
  test na fixture'ze; checklista `architect` z nazwą sekcji i regresja w lint; `docs/tasks.md`
- [x] T2: `regent-apply-tokens` — `firstturn.ts` z testami na syntetycznym transkrypcie, polecenie
  z `--project`, `--since`, `--until`, `--json`, testy na syntetycznym katalogu `projects/`;
  dokumentacja (`docs/tasks.md` — sprawdzenie etapu, `docs/README.md` — Narzędzia)
- [ ] T3: bramka (`framework-lint.sh`, `claude plugin validate .`, `npm test` i `npm run typecheck`
  w `tools/regent/` i `tools/watch/`) i smoke: `regent-apply-tokens --project ~/_Private/Projects
  --until 2026-09-28` odtwarza punkt odniesienia z Przebiegu sesji 4; `packet` na zmianie
  prywatnej z „Kontrakt API↔UI” ma kontrakt; merge do `main`

## Poza zakresem

Zmiana reguły paczki poza aliasem kontraktu (np. „Odstępstwa od zasad” w starszych designach —
to prawdziwy brak sekcji), zapis wyników pomiaru gdziekolwiek poza terminalem, pomiar sesji
głównej `apply`.
