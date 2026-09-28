# Dokumentacja

Indeks dokumentacji frameworka. Szczegóły w plikach poniżej.

## Przewodniki

| Dokument | O czym |
|----------|--------|
| [getting-started.md](getting-started.md) | Pierwsze uruchomienie frameworka w projekcie — krok po kroku |
| [workflow.md](workflow.md) | Przepływ pracy SDD: komendy, cykl zmiany, delegacja do agentów |
| [writing-docs.md](writing-docs.md) | Jak pisać dokumentację w tym repo (styl, struktura) |
| [roadmap.md](roadmap.md) | Świadome decyzje (czego nie ma i dlaczego, jak przywrócić), pomysły odłożone i zrealizowane |
| [vision.md](vision.md) | Wizja Regenta — wynik wywiadu: problem, rdzeń, napięcia, otwarte pytania |
| [plans/](plans/) | Plany zmian prowadzonych lekką ścieżką (gałąź + checklista) |

## Skrypty

Skrypty pomocnicze leżą w [`scripts/`](../scripts/). Każdy ma tu swój opis:

| Skrypt | Dokumentacja | O czym |
|--------|--------------|--------|
| [`scripts/statusline.sh`](../scripts/statusline.sh) | [statusline.md](statusline.md) | Statusline z licznikiem kontekstu i progiem ostrzegawczym |
| [`scripts/sdd-check.sh`](../scripts/sdd-check.sh) | [sdd-check.md](sdd-check.md) | Deterministyczna walidacja artefaktów w projekcie: delta, tasks, pokrycie AC, merge, dryf |
| [`scripts/hooks/git-guard.sh`](../scripts/hooks/git-guard.sh) | [`/regent:init` Krok 3.5](../skills/init/SKILL.md) | Hook PreToolUse: blokuje `git add .`/`-A`, `git commit -a`, `--no-verify` w projektach SDD |
| [`scripts/framework-lint.sh`](../scripts/framework-lint.sh) | [CONTRIBUTING.md](../CONTRIBUTING.md#walidacja-lokalna) | Spójność frameworka: frontmatter, odwołania, tabele skilli, prefiks agentów, regresje promptów |
| [`scripts/session-tokens.sh`](../scripts/session-tokens.sh) | nagłówek skryptu | Zużycie tokenów w sesji Claude Code per prompt (z subagentami), z transkryptu `~/.claude/projects/` |

Gdy dojdzie nowy skrypt do `scripts/` — dopisz wiersz w tabeli powyżej i (jeśli
wymaga wyjaśnienia) osobny plik `docs/<nazwa>.md`.
