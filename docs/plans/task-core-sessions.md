# Sesje: task-core

> Podział implementacji `docs/plans/task-core.md` na cztery sesje Claude Code. Każda sesja startuje
> świeżo (nowe okno albo `/clear`), najlepiej tuż po resecie okna limitu. Model ustaw przez `/model`
> przed wklejeniem promptu. Postęp niosą checkboxy i sekcja Przebieg w planie, nie pamięć sesji.

| Sesja | Taski | Model | Po sesji działa |
|---|---|---|---|
| 1 | T1–T4 | Sonnet | `regent task add/take/handoff/done/drop/list/show` na bazie, utknięcie |
| 2 | T5–T7 | Opus | `sync` z artefaktów SDD, import `tasks.md`, `next` i `packet` |
| 3 | T8–T9 | Opus | hooki `SessionStart`/`Stop`, `regent.sh`, skill `apply` na paczce |
| 4 | T10–T12 | Sonnet | dokumentacja, smoke, merge do `main`, start tygodnia sprawdzenia |

## Zasady wspólne (każda sesja)

1. **Kontekst:** przeczytaj w całości `docs/plans/task-core.md`; reguły z `.claude/rules/` ładują się
   same. Nie czytaj tego, czego zakres sesji nie potrzebuje.
2. **Gałąź:** sesja 1 zakłada `feat/task-core` z aktualnego `main`. Kolejne:
   `git checkout feat/task-core && git pull`.
3. **Wznowienie:** zacznij od pierwszego nieodhaczonego taska z zakresu sesji — poprzednią mogło
   przerwać wyczerpanie limitu. Niezacommitowane zmiany (`git status`, `git diff`) to przerwany
   task: przejrzyj je i dokończ, nie zaczynaj od zera.
4. **Pętla na task:** testy najpierw, potem kod, potem zielone:
   - `npm test` i `npm run typecheck` w `tools/regent/`;
   - przy zmianach w `scripts/`, `skills/`, `hooks/`, `agents/` także `bash scripts/framework-lint.sh`
     i `claude plugin validate .` (jedyne dozwolone ostrzeżenie: brak `version`);
   - odhacz task `[x]` w planie, commit (jedna linia, Conventional Commits po polsku, `git add`
     z listą plików), `git push origin feat/task-core`.
5. **Bez subagentów** — mechanikę robi sesja główna (reguła repo).
6. **Odstępstwo od planu:** decyzja, której plan nie rozstrzyga, albo fakt, który go podważa →
   zatrzymaj się i zapytaj. Drobne odstępstwa (nazwa pliku, kolejność kroków) zapisz w Przebiegu.
7. **Prywatność:** fixture'y w repo są syntetyczne. Treść z prawdziwych projektów, ich nazwy i dane
   z pracy nie trafiają do repo — do Przebiegu tylko liczby.
8. **Nie ruszaj** `~/.claude` (stary framework SDD) i nie merguj do `main` przed sesją 4.
9. **Koniec sesji:** dopisz w planie `## Przebieg (RRRR-MM-DD) — sesja N` (co zrobione, odstępstwa,
   fakty z pomiarów), commit i push. Raport dla mnie: co zrobione, co zostało, czy następna sesja
   może ruszać.

## Sesja 1 — T1–T4 (Sonnet)

```
Wykonaj sesję 1 z docs/plans/task-core-sessions.md: taski T1–T4 z docs/plans/task-core.md.
Trzymaj się zasad wspólnych z tego pliku i zatrzymaj się po T4.
```

- **Wzorzec pakietu:** `tools/watch/` — `package.json` (`type: module`, `engines.node >=24`, bin,
  skrypty `build`/`test`/`typecheck`, `prepare` buduje), `tsconfig.json`, `tsconfig.build.json`,
  `.gitignore` (`node_modules/`, `dist/`). Zależności tylko deweloperskie (TypeScript, Vitest,
  `@types/node`); w runtime tylko moduły Node (`node:sqlite`, `node:util` `parseArgs`).
- **Baza:** jedyny plik z `node:sqlite`. Ścieżka z `REGENT_DB` (testy, izolacja) albo
  `${XDG_STATE_HOME:-~/.local/state}/regent/regent.db`. `ExperimentalWarning` wycisz tylko dla SQLite.
- **Zegar wstrzykiwany**, nie `Date.now()` w logice — T4 testuje utknięcie na podmienionym czasie.
- **Poza zakresem sesji:** sync, import `tasks.md`, paczka, hooki, skille.
- **Gotowe, gdy:** na bazie tymczasowej przechodzi scenariusz `add` → `take` → `handoff me` →
  `done --reason`, niedozwolone przejście kończy się kodem 1 z listą możliwych, `list` pokazuje
  utknięte zadanie w sekcji Uwaga.

## Sesja 2 — T5–T7 (Opus)

```
Wykonaj sesję 2 z docs/plans/task-core-sessions.md: taski T5–T7 z docs/plans/task-core.md.
Trzymaj się zasad wspólnych z tego pliku i zatrzymaj się po T7.
```

- **Przeczytaj przed kodem:** w `scripts/sdd-check.sh` funkcje `cmd_status`, `TASK_AWK`,
  `meta_field`; `skills/propose/SKILL.md` sekcja 2d (format taska); `skills/apply/SKILL.md` Krok 4c
  (format śladu po commicie); `skills/archive/SKILL.md` (`--abandon`); `templates/design-template.md`
  i `templates/spec-template.md` (nagłówki sekcji, z których składa się paczka).
- **T5:** stan zmiany liczy `sdd-check.sh status` (wywołanie skryptu, nie kopia jego logiki).
  Zmiana w `skills/archive/SKILL.md` (`Status: Abandoned` przy `--abandon`) → lint.
- **T6:** parser tasków w TS odwzorowuje semantykę `TASK_AWK` (bloki kodu, grupy `## `, `T-NN`,
  stany checkboxów). Test zgodności: na tych samych fixture'ach liczby tasków zgadzają się
  z `sdd-check.sh status`.
- **T7:** reguły paczki dokładnie jak w tabeli Decyzje planu; `--stats` szacuje tokeny jako
  bajty / 3,5. `done --commit --tests` przepisuje wyłącznie linię tego taska.
- **Fixture'y:** syntetyczne `ai/changes/` w `tools/regent/test/fixtures/` — zmiana w nowym
  formacie (`T-NN`, tagi, REQ/AC, `(po T-XX)`) i jedna w starszym (bez `T-NN`).
- **Gotowe, gdy:** na fixture'ach `sync` odtwarza stany z mapy SDD, `next --layer BE` zwraca
  tylko taski z zamkniętymi zależnościami, a `packet --stats` pokazuje paczkę mniejszą od plików.

## Sesja 3 — T8–T9 (Opus)

```
Wykonaj sesję 3 z docs/plans/task-core-sessions.md: taski T8–T9 z docs/plans/task-core.md.
Trzymaj się zasad wspólnych z tego pliku i zatrzymaj się po T9.
```

- **Przeczytaj przed kodem:** `hooks/hooks.json`; `scripts/hooks/session-context.sh`
  i `sync-bin.sh` (wzorzec: cisza na stdout, zawsze kod 0); `scripts/hooks/git-guard.sh` funkcja
  `extract` (JSON hooka bez jq); `scripts/tests/*.test.sh` (wzorzec testów w bashu 3.2);
  `scripts/framework-lint.sh` sekcje 2 i 8; `skills/apply/SKILL.md` w całości.
- **T8:** `scripts/regent.sh` szuka `${CLAUDE_PLUGIN_ROOT}/tools/regent/dist/cli.js`, potem `regent`
  w PATH; brak → kod 3 i jedna linia na stderr. `task-sync.sh` bierze z JSON-a `session_id`,
  `transcript_path`, `cwd`; poza projektem z `ai/docs/` nic nie robi.
- **T9:** w `skills/apply/SKILL.md` dwie ścieżki — z CLI (Krok 1, 3, 4a, 4c przez `regent.sh task
  next/packet/take/done`) i bez CLI (dokładnie jak dziś). Routing po tagach, budżet subagentów
  i commit per task bez zmian. Subagent dostaje paczkę w prompcie i zgłasza `BRAK W PACZCE: …`.
  Reguła lint: skill wołający `regent.sh` ma `Bash` w `allowed-tools` (jak dla `sdd-check.sh`).
- **Nie włączaj pluginu** nigdzie — hooki testuj JSON-em na stdin.
- **Gotowe, gdy:** testy hooków zielone w `/bin/bash` 3.2 i bashu z PATH; `framework-lint.sh` bez
  ERROR; w `apply` ścieżka bez CLI jest słowo w słowo tą dzisiejszą.

## Sesja 4 — T10–T12 (Sonnet)

```
Wykonaj sesję 4 z docs/plans/task-core-sessions.md: taski T10–T12 z docs/plans/task-core.md.
Trzymaj się zasad wspólnych z tego pliku. Merge do main dopiero po zielonej bramce i smoke.
```

- **T10:** `docs/tasks.md` w stylu `docs/agent-teams.md` (instalacja jak `regent-watch`: `npm install`
  w `tools/regent/`, opcjonalnie `npm link`), wpis w README; pełna bramka z zasady 4.
- **T11 smoke bez tokenów:**
  - projekt testowy w scratchpadzie (nie w repo): `git init`, `ai/docs/`, zmiana przeprowadzona przez
    Draft → Approved → taski → weryfikacja → archiwum edycjami plików, po każdej JSON hooka na stdin
    `scripts/hooks/task-sync.sh` z `CLAUDE_PLUGIN_ROOT` = repo; `regent task show` pokazuje każdy krok;
  - porzucenie przez `Status: Abandoned`;
  - `packet --stats` na jednej zarchiwizowanej zmianie z projektu prywatnego — tylko odczyt, do
    Przebiegu same liczby;
  - czas hooka `Stop` (`time`); gdy wyraźnie ponad 200 ms — zapisz i zapytaj o warunek z Ryzyk planu;
  - punkt odniesienia do sprawdzenia etapu: tokeny wejścia pierwszej tury subagentów `apply`
    z transkryptów projektów prywatnych sprzed zmiany (parser w `tools/watch/src/parse/`), mediana.
- **T12:** merge `feat/task-core` → `main` (fast-forward), push; w Przebiegu data startu tygodnia
  sprawdzenia; w `.claude/rules/project.md` „Następny krok” → tydzień sprawdzenia etapu 1, potem
  plan etapu 2.
- **Gotowe, gdy:** `main` zawiera etap 1, smoke opisany w Przebiegu, punkt odniesienia zmierzony.
