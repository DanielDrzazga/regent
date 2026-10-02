# Dokumentacja

Indeks dokumentacji frameworka. Szczegóły w plikach poniżej.

## Przewodniki

| Dokument | O czym |
|----------|--------|
| [getting-started.md](getting-started.md) | Pierwsze uruchomienie frameworka w projekcie — krok po kroku |
| [workflow.md](workflow.md) | Przepływ pracy SDD: komendy, cykl zmiany, delegacja do agentów |
| [writing-docs.md](writing-docs.md) | Jak pisać dokumentację w tym repo (styl, struktura) |
| [roadmap.md](roadmap.md) | Świadome decyzje (czego nie ma i dlaczego, jak przywrócić), pomysły odłożone i zrealizowane |
| [tasks.md](tasks.md) | Zadania `regent task`: instalacja CLI, polecenia, stany, sync z artefaktów SDD, paczka dla `apply`, utknięcie |
| [agent-teams.md](agent-teams.md) | Agent teams w tmux (włączenie per projekt, koszt, wpływ na delegację) i podgląd `regent-watch` |
| [plans/](plans/) | Plany zmian prowadzonych lekką ścieżką (gałąź + checklista) |

## Skrypty

Skrypty pomocnicze leżą w [`scripts/`](../scripts/). Każdy ma tu swój opis. W poleceniach dla
terminala `${CLAUDE_PLUGIN_ROOT}` oznacza katalog pluginu — przy pracy nad pluginem to klon repo:

| Skrypt | Dokumentacja | O czym |
|--------|--------------|--------|
| [`scripts/statusline.sh`](../scripts/statusline.sh) | [statusline.md](statusline.md) | Statusline z licznikiem kontekstu i progiem ostrzegawczym |
| [`scripts/sdd-check.sh`](../scripts/sdd-check.sh) | [sdd-check.md](sdd-check.md) | Deterministyczna walidacja artefaktów w projekcie: delta, tasks, pokrycie AC, merge, dryf |
| [`scripts/hooks/git-guard.sh`](../scripts/hooks/git-guard.sh) | [`/regent:init` Krok 3.5](../skills/init/SKILL.md) | Hook PreToolUse pluginu: w projektach z `ai/docs/` blokuje `git add .`/`-A`, `git commit -a`, `--no-verify`, `-c core.hooksPath`, atrybucję AI w commicie i PR; `GIT_GUARD_FORCE=1` wymusza |
| [`scripts/hooks/session-context.sh`](../scripts/hooks/session-context.sh) | nagłówek skryptu | Hook SessionStart/SubagentStart: wstrzykuje `context/role.md` zawsze, `sdd.md` i `sdd-map.md` przy `ai/docs/` |
| [`scripts/hooks/sync-bin.sh`](../scripts/hooks/sync-bin.sh) | [statusline.md](statusline.md) | Hook SessionStart: kopiuje `statusline.sh` i `session-tokens.sh` do `${CLAUDE_PLUGIN_DATA}/bin/` |
| [`scripts/regent.sh`](../scripts/regent.sh) | nagłówek skryptu | Wywołanie CLI zadań (`tools/regent`) ze skilli i hooków: `dist/cli.js` w pluginie albo `regent` w PATH; brak → kod 3 |
| [`scripts/hooks/task-sync.sh`](../scripts/hooks/task-sync.sh) | nagłówek skryptu | Hook SessionStart i Stop: w projektach z `ai/docs/` `regent task sync` z sesją i transkryptem; cisza na stdout, kod 0 |
| [`scripts/framework-lint.sh`](../scripts/framework-lint.sh) | [CONTRIBUTING.md](../CONTRIBUTING.md#walidacja-lokalna) | Spójność frameworka: frontmatter, odwołania, tabele skilli, prefiks agentów, regresje promptów |
| [`scripts/session-tokens.sh`](../scripts/session-tokens.sh) | nagłówek skryptu | Zużycie tokenów w sesji Claude Code per prompt (z subagentami), z transkryptu `~/.claude/projects/` |

Gdy dojdzie nowy skrypt do `scripts/` — dopisz wiersz w tabeli powyżej i (jeśli
wymaga wyjaśnienia) osobny plik `docs/<nazwa>.md`.

## Narzędzia

Pakiety Node w [`tools/`](../tools/) — poza komponentami pluginu, instalowane osobno:

| Pakiet | Dokumentacja | O czym |
|--------|--------------|--------|
| [`tools/regent/`](../tools/regent/) | [tasks.md](tasks.md) | `regent task`: zadania z właścicielem i logiem przejść, sync z `ai/changes/`, paczka dla agenta `apply` |
| [`tools/watch/`](../tools/watch/) | [agent-teams.md](agent-teams.md#regent-watch), [tasks.md](tasks.md#pomiar-paczki-regent-apply-tokens) | `regent-watch`: mission control agentów Claude Code — sesje z całej maszyny, akcje, kontekst, oś czasu, graf, koszt, zdrowie; `regent-apply-tokens`: tokeny pierwszej tury subagentów `apply` z paczką i bez |
