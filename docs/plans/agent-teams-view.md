# Plan: agent-teams-view

> Nowa funkcja Regenta: widok pracy agentów w tmux. Lekka ścieżka: gałąź `feat/agent-teams-view`,
> ten plan, bramka i smoke. Funkcja eksploracyjna — zaczyna się od spike'a, a fakty z niego mogą
> zmienić taski T3–T5.

## Cel

Praca agentów jest widoczna na żywo w tmux:

1. **Wykonanie** — natywne agent teams Claude Code w trybie split-pane: każdy członek zespołu to
   osobna sesja we własnym panelu tmux, z którą można rozmawiać wprost.
2. **Przegląd** — osobne polecenie `regent-watch` (Node/TS, Ink) w oddzielnym panelu lub oknie tmux:
   agenci i ich bieżąca akcja, oś czasu zdarzeń, tokeny i koszt, blokady i błędy.

## Decyzje (2026-09-28)

| Decyzja | Wartość |
|---|---|
| Podejście | agent teams (eksperymentalne) — zastrzeżenia zgłoszone: koszt tokenów, delegacja do nazwanego agenta tworzy członka zespołu zamiast subagenta, ograniczenia wznawiania |
| Zakres włączenia | **tylko wybrany projekt**: `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` i `teammateMode: "tmux"` w jego `.claude/settings.local.json`; nigdy globalnie (zmieniłoby delegację SDD w każdej sesji, także w projektach z pracy i w starym SDD z `~/.claude`) |
| Widok | osobne polecenie, tylko odczyt: pokazuje agentów z bieżącą akcją, oś czasu, tokeny i koszt, blokady i błędy |
| Technologia | Node 24 + TypeScript + Ink, testy Vitest; pakiet w `tools/watch/` — poza komponentami pluginu |
| Źródła danych | `~/.claude/teams/session-<8 znaków>/config.json` (członkowie, sesje, panele tmux; znika po sesji), `~/.claude/tasks/session-…/` (lista zadań), `…/inboxes/<agent>.json` (wiadomości), transkrypty `~/.claude/projects/<projekt>/<sesja>.jsonl` (+ `subagents/`) |

## Taski

- [x] T1: spike w projekcie testowym (tmux, Haiku, 2 członków zespołu, krótkie zadanie) — **koszt
  tokenów, uruchomienie za zgodą**. Fakty do spisania w sekcji „Fakty ze spike'a":
  - schemat `config.json`, plików zadań i skrzynek;
  - gdzie leżą transkrypty członków zespołu i jak powiązać je z członkiem;
  - czy ustawienia per projekt (`env`, `teammateMode`) wystarczają;
  - co widać w transkrypcie przy blokadzie hooka i błędzie narzędzia
- [x] T2: szkielet `tools/watch/` — `package.json` (bin `regent-watch`), `tsconfig`, Ink, Vitest,
  skrypty `test` i `typecheck`; `node_modules/` poza repo (`.gitignore`)
- [x] T3: parsery jako czyste funkcje z testami na syntetycznych fixture'ach (odtworzonych ze spike'a,
  bez treści z żadnego prawdziwego projektu): zespół → agenci; transkrypt → zdarzenia (narzędzie,
  wynik, czas); tokeny z dedupem po `message.id` (jak `session-tokens.sh`); blokady (`is_error`,
  błąd hooka)
- [x] T4: widok Ink — panel agentów (akcja, czas trwania, status), oś czasu z przewijaniem, tokeny
  i koszt per agent i razem, lista blokad i błędów; odświeżanie przy zmianie plików; wybór sesji:
  najnowsza w bieżącym katalogu albo `--session <id>`
- [x] T5: uruchomienie w tmux — `regent-watch` w nowym panelu (`tmux split-window -h regent-watch`)
  albo oknie; bez automatycznego hooka
- [x] T6: dokumentacja `docs/agent-teams.md` — włączenie per projekt, uruchomienie widoku, koszt,
  wpływ na delegację SDD, ograniczenia; README i `docs/README.md`
- [x] T7: bramka — `bash scripts/framework-lint.sh` + `claude plugin validate .` + w `tools/watch/`
  `npm test` i `npm run typecheck`
- [x] T8: smoke — sesja z zespołem w tmux (Haiku) i `regent-watch` obok; widać członków, akcje,
  tokeny i zablokowane `git add .` (projekt z `ai/docs/`) — **koszt tokenów, za zgodą**
- [x] T9: merge `feat/agent-teams-view` → `main`, push

## Fakty ze spike'a (2026-09-28)

Claude Code 2.1.280, lead i dwaj członkowie zespołu (`alpha`, `beta`) na Haiku 4.5 w odłączonej
sesji tmux; projekt syntetyczny z `ai/docs/` w scratchpadzie, plugin przez `--plugin-dir`.
Dwie rundy: zadania bez zależności, potem zadanie zależne i shutdown. Koszt: 0,67 USD
(lead 0,32, alpha 0,18, beta 0,17).

**Włączenie per projekt działa.** `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` i
`teammateMode: "tmux"` w `.claude/settings.local.json` wystarczają: katalog zespołu powstaje przy
starcie sesji, a członkowie dostają własne panele w oknie leada. Członkowie w panelach dziedziczą
`--plugin-dir`: dostają kontekst z hooka SessionStart, a git-guard działa w ich sesjach.

**`~/.claude/teams/session-<8 znaków ID sesji leada>/config.json`** — stan bieżący, nie historia:

```json
{ "name": "session-9421a5dd", "createdAt": 1790610728213,
  "leadAgentId": "team-lead@session-9421a5dd", "leadSessionId": "<pełne ID sesji leada>",
  "members": [
    { "agentId": "team-lead@…", "name": "team-lead", "agentType": "team-lead",
      "tmuxPaneId": "leader", "backendType": "in-process", "cwd": "…", "joinedAt": 0, "subscriptions": [] },
    { "agentId": "alpha@…", "name": "alpha", "color": "blue", "model": "haiku", "prompt": "…",
      "tmuxPaneId": "%1", "backendType": "tmux", "isActive": true, "planModeRequired": false,
      "cwd": "…", "joinedAt": 0, "subscriptions": [] } ] }
```

- `isActive` przełącza się między `true` (tura trwa) a `false` (bezczynny).
- Po zatwierdzonym shutdownie członek **znika z `members`**, a jego panel tmux się zamyka.
- `config.json` nie ma ID sesji członka. Cały katalog `teams/session-…` znika po wyjściu z leada.

**`~/.claude/tasks/session-…/`** — `<id>.json` = `{id, subject, description, status: pending |
in_progress | completed, owner?, blocks: [], blockedBy: []}` oraz `.highwatermark` (ostatni numer)
i `.lock`. Pliki zadań **znikają kilka sekund po ukończeniu wszystkich zadań**, sam katalog zostaje.

**`~/.claude/teams/session-…/inboxes/<agent>.json`** — tablica `{from, text, timestamp, read,
type: "message", msgV: 1, msg_id, summary?, color?}`; wiadomość protokołu to JSON zapisany w `text`
(`task_assignment`, `idle_notification` z `idleReason` i `result`, `shutdown_request`,
`shutdown_approved` z `paneId`). Wpisy **znikają po doręczeniu** (ułamki sekund) — skrzynka nie
nadaje się na źródło historii.

**Transkrypty.** Członek zespołu w panelu ma własny transkrypt obok transkryptu leada:
`~/.claude/projects/<projekt>/<ID sesji członka>.jsonl`. Wszystkie jego rekordy `user`, `assistant`,
`system` i `attachment` niosą `teamName` (`session-…`) i `agentName` (`alpha`). Powiązanie członka:
`teamName` = nazwa zespołu, `agentName` = `members[].name`. Rekordy leada nie mają tych pól; lead
to plik, którego nazwa zaczyna się od 8 znaków z `teamName`. Zwykli subagenci:
`<sesja>/subagents/agent-<id>.jsonl` (`isSidechain: true`, `agentId`) + `agent-<id>.meta.json`
(`agentType`, `description`).

- Spawn w transkrypcie leada: `tool_use` `Agent` z `name` i `model`; `toolUseResult` =
  `{status: "teammate_spawned", name, agent_id, model, color, tmux_pane_id, team_name, is_splitpane}`.
- Wiadomość doręczona agentowi to rekord `user` z treścią `<teammate-message teammate_id="…"
  color="…" summary="…">…</teammate-message>` (u leada poprzedzoną „Another Claude session sent
  a message:"); wysłanie to `tool_use` `SendMessage` z `to`.
- **Błąd narzędzia:** `tool_result` z `is_error: true`, treść błędu (np. `File does not exist.`).
  Przy sukcesie `is_error` bywa `false` albo nie ma go wcale.
- **Blokada hooka:** `tool_result` z `is_error: true` i treścią `PreToolUse:Bash hook error:
  [<polecenie hooka>]: <stderr hooka>`; `toolUseResult` = ten sam tekst z przedrostkiem `Error: `.
  Osobnego rekordu blokady nie ma — `attachment` `hook_success` pojawia się tylko przy sukcesie.
- **Tokeny:** `message.usage` z `input_tokens`, `cache_creation_input_tokens` (+ podział
  `cache_creation.ephemeral_5m/1h_input_tokens`), `cache_read_input_tokens`, `output_tokens`,
  `speed`; ta sama odpowiedź w 2–3 liniach z tym samym `message.id` — dedup konieczny.
- **Koszt:** rekord `cost-state` (`totalCostUSD`, `modelUsage`) każda sesja zapisuje dopiero przy
  zamknięciu. Na żywo koszt trzeba szacować: `usage` × cennik. Cennik jest zgodny z Claude Code co do
  centa — liczniki z `modelUsage` członka × stawki Haiku (zapis cache 1h ×2) dają jego
  `totalCostUSD`. Suma `usage` z transkryptu jest za to niższa od `modelUsage`: o ok. 5% u członków,
  o ok. 25% u leada (cache read 1,1M wobec 1,66M) — zapytania poboczne nie trafiają do transkryptu,
  więc szacunek jest dolną granicą.
- Koniec tury: rekord `system` `subtype: "turn_duration"` z `durationMs`.

**Wpływ na taski:**

- T3: agenci z transkryptów (`teamName`/`agentName`), a `config.json` — tylko do statusu na żywo
  (`isActive`, obecność w `members`). Skrzynek i plików zadań nie parsujemy: są ulotne, a
  wiadomości i tak widać w transkryptach. Koszt: `cost-state`, gdy jest; wcześniej szacunek z cennika.
- T4: najnowszy transkrypt w katalogu projektu może należeć do członka zespołu — widok przechodzi
  wtedy przez `teamName` do sesji leada.
- T5: członkowie dzielą okno leada, więc widok w tym samym oknie dostanie wąski panel — domyślnie
  osobne okno tmux, sprawdzić w smoke (T8).

## Przebieg (2026-09-28)

- T2–T4: pakiet `tools/watch/` — Node 24, TypeScript 7, Ink 7, React 19, Vitest 5; 43 testy na
  syntetycznych fixture'ach (`test/fixtures/claude/`, generowane poza repo, bez treści z prawdziwych
  sesji). Mutacja regexu blokady hooka wywala 5 testów. Parsery tolerują nieznane rekordy i
  uszkodzone linie; czytanie przyrostowe od ostatniego offsetu (bez rozcinania znaków UTF-8);
  nowi członkowie i subagenci wykrywani co 3 s, obce sesje zapamiętane jako odrzucone.
- T7: lint 0 błędów, `claude plugin validate .` tylko z ostrzeżeniem o `version`, `npm test` 43/43,
  `npm run typecheck` czysto.
- T8 (smoke, 0,46 USD wg Claude Code; szacunek widoku 0,39): lead i członkowie `alpha`, `beta` na
  Haiku, `regent-watch` w osobnym oknie i na próbę w panelu obok leada. Widać było członków,
  `alpha · pracuje · Bash Wait 15 seconds`, tokeny i koszt na żywo, dwukrotnie zablokowane
  `git add .` (`blokada hooka git-guard.sh`) i błędy `Read`. Przewijanie działa, po `/exit` z
  „Exit and stop tasks" wszyscy `zamknięty`, a RAZEM pokazuje koszt wg Claude Code.
- T5 — fakt ze smoke'a: panel widoku w oknie leada wpada do stosu członków (174×20 z 250×60),
  więc dokumentacja zaleca osobne okno (`tmux new-window`), a `split-window` tylko bez zespołu.
- Uwagi ze smoke'a, zapisane w `docs/agent-teams.md`:
  - członkowie na Haiku nie umieli odpowiedzieć na shutdown (błędy protokołu `SendMessage`) —
    zamknięcie przez `/exit` leada;
  - członek na Haiku zapisał plik pod złą ścieżką bezwzględną w katalogu domowym, bo allowlista
    smoke'a miała gołe `Write` (plik usunięty zaraz po smoke'u). W dokumentacji zalecenie
    `Edit(/**)` zamiast gołego `Write`/`Edit`.
- Poza zakresem, do decyzji: git-guard w sesji tego repo (`GIT_GUARD_FORCE=1`) dał dwa fałszywe
  alarmy na złożonych poleceniach Bash — `-n` z `tmux new-session -n` wziął za `git commit -n`,
  a tekst o `git add` w treści heredoca za polecenie. Hook sprawdza całe polecenie, a nie
  pojedyncze polecenia `git`.

## Poza zakresem

Przystosowanie skilli SDD do pracy zespołowej (np. równoległe `/regent:verify`), kronika w SQLite,
włączanie agent teams w projektach z pracy, publikacja pluginu.

## Ryzyka

- **Funkcja eksperymentalna** — format plików zespołu może się zmienić; parsery pomijają nieznane
  pola i rekordy, testy na fixture'ach wychwycą zmianę.
- **Koszt** — każdy członek zespołu ma własny kontekst; spike i smoke na Haiku, z małym zespołem.
- **Delegacja SDD w projekcie z włączonymi teams** — nazwany agent (`regent:architect`) startuje jako
  członek zespołu, a nie subagent; dlatego teams tylko w wybranym projekcie.
- **Prywatność** — transkrypty mogą zawierać treść z projektów z pracy (Mac mieszany): widok tylko
  czyta lokalnie, niczego nie zapisuje ani nie wysyła; do repo trafiają wyłącznie syntetyczne fixture'y.
- **Windows** — split-pane nie działa w Windows Terminal; widok Ink zadziała, panele nie.
