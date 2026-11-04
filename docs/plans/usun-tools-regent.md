# Plan: usun-tools-regent

> Lekka ścieżka na gałęzi `chore/usun-regent-watch` (decyzja użytkownika: ta sama gałąź co
> usunięcie `regent-watch`), ten plan, bramka i smoke.

## Cel

Regent idzie do całej firmy i ma działać od razu po instalacji pluginu, bez Node i builda.
Usuwamy cały `tools/regent/` — CLI `regent task`, paczkę dla `/regent:apply` i `regent-apply-tokens`
— oraz wszystko, co z niego korzysta.

## Decyzje (2026-11-04)

| Decyzja | Wartość |
|---|---|
| Zakres | cały `tools/regent/`; bez paczki pomiar `regent-apply-tokens` traci przedmiot |
| `/regent:apply` | jedyna ścieżka to dotychczasowa „bez CLI” — subagent czyta pliki zmiany, ślad w `tasks.md` dopisuje sesja główna |
| Stan zmian | bez zmian: `sdd-check.sh status` (używa go `/regent:status`) |
| Evale `apply` | usunięty `holdout-no-cli` (to teraz jedyna ścieżka) i oceniacze `paczka-z-cli` |
| Przywrócenie | `docs/roadmap.md`, „Świadomie poza frameworkiem” — `git checkout b3a6cd1 -- …` |

## Taski

- [x] T1: `git rm` — `tools/regent/`, `scripts/regent.sh`, `scripts/hooks/task-sync.sh`, ich testy,
  `docs/tasks.md`, `evals/apply/holdout-no-cli/`
- [x] T2: `hooks/hooks.json` — bez `task-sync.sh` (SessionStart i cały `Stop`)
- [x] T3: `skills/apply/SKILL.md` — bez bloków „Z CLI”; `agents/dba.md` — bez paczki
- [x] T4: `/regent:optimize` i `docs/optimize.md` — bez budowania CLI w worktree i bez paczki
  w zestawie `apply`
- [x] T5: lint — bez kontroli `regent.sh` w `allowed-tools` i reguły o paczce w prompcie; nowe
  `forbid` na powrót CLI w `apply`
- [x] T6: `README.md`, `docs/README.md`, `.claude/rules/project.md`, przykłady w regule „Język”,
  `docs/roadmap.md`
- [x] T7: bramka (`framework-lint.sh`, `claude plugin validate .`) i smoke (`hooks.json`, testy skryptów)
