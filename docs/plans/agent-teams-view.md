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

- [ ] T1: spike w projekcie testowym (tmux, Haiku, 2 członków zespołu, krótkie zadanie) — **koszt
  tokenów, uruchomienie za zgodą**. Fakty do spisania w sekcji „Fakty ze spike'a":
  - schemat `config.json`, plików zadań i skrzynek;
  - gdzie leżą transkrypty członków zespołu i jak powiązać je z członkiem;
  - czy ustawienia per projekt (`env`, `teammateMode`) wystarczają;
  - co widać w transkrypcie przy blokadzie hooka i błędzie narzędzia
- [ ] T2: szkielet `tools/watch/` — `package.json` (bin `regent-watch`), `tsconfig`, Ink, Vitest,
  skrypty `test` i `typecheck`; `node_modules/` poza repo (`.gitignore`)
- [ ] T3: parsery jako czyste funkcje z testami na syntetycznych fixture'ach (odtworzonych ze spike'a,
  bez treści z żadnego prawdziwego projektu): zespół → agenci; transkrypt → zdarzenia (narzędzie,
  wynik, czas); tokeny z dedupem po `message.id` (jak `session-tokens.sh`); blokady (`is_error`,
  błąd hooka)
- [ ] T4: widok Ink — panel agentów (akcja, czas trwania, status), oś czasu z przewijaniem, tokeny
  i koszt per agent i razem, lista blokad i błędów; odświeżanie przy zmianie plików; wybór sesji:
  najnowsza w bieżącym katalogu albo `--session <id>`
- [ ] T5: uruchomienie w tmux — `regent-watch` w nowym panelu (`tmux split-window -h regent-watch`)
  albo oknie; bez automatycznego hooka
- [ ] T6: dokumentacja `docs/agent-teams.md` — włączenie per projekt, uruchomienie widoku, koszt,
  wpływ na delegację SDD, ograniczenia; README i `docs/README.md`
- [ ] T7: bramka — `bash scripts/framework-lint.sh` + `claude plugin validate .` + w `tools/watch/`
  `npm test` i `npm run typecheck`
- [ ] T8: smoke — sesja z zespołem w tmux (Haiku) i `regent-watch` obok; widać członków, akcje,
  tokeny i zablokowane `git add .` (projekt z `ai/docs/`) — **koszt tokenów, za zgodą**
- [ ] T9: merge `feat/agent-teams-view` → `main`, push

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
