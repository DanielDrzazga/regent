# Plan: ai-tracking-mode

> Regent przestaje wymuszać jeden tryb pracy z `ai/`. Lekka ścieżka: gałąź `feat/ai-tracking-mode`,
> ten plan, bramka i smoke w obu trybach. Decyzja użytkownika 2026-11-04.

## Cel

Dziś framework zakłada na trwałe, że `ai/` (artefakty SDD: `docs/`, `specs/`, `changes/`,
`changes/archive/`) jest osobisty i globalnie ignorowany przez git — nigdy nie trafia do repo
produktu. To założenie jest wbudowane w logikę skilli, nie tylko w opisy: `git add` nie wymienia
ścieżek w `ai/` (dodanie kończy się kodem 1), `archive` robi ręczną migawkę przed/po merge, bo
`git diff` nie widzi ignorowanych plików, a reviewer cudzego MR nie ma dostępu do `ai/` autora.

Zespół może chcieć pełną historię decyzji SDD w repo; solo dev może nadal chcieć osobisty
workspace. Regent wybiera **per projekt**, pytaniem przy `/regent:init`: `ai/` osobisty (jak dziś)
albo **współdzielony** — śledzony w repo produktu, w całości (`docs/`, `specs/`, `changes/`
aktywne i archiwum).

## Decyzje (2026-11-04)

| Decyzja | Wartość |
|---|---|
| Wykrywanie trybu | bez nowego configu — `git check-ignore -q --no-index ai/` sprawdzany na żywo w każdym skillu, który musi wiedzieć (exit 0 → osobisty, exit 1 → współdzielony); to już istniejący wzorzec z Kroku 0.5 `init` |
| Zakres współdzielony | **wszystko** w `ai/` — `docs/`, `specs/`, `changes/` aktywne i `changes/archive/` |
| Odblokowanie globalnej reguły | jeśli `ai/` jest ignorowany przez istniejącą globalną regułę z innego projektu, `init` proponuje `!/ai/` w **projektowym** `.gitignore` (nadpisuje `core.excludesfile` — standardowy mechanizm negacji git) |
| Operacyjna logika do zmiany | `init` (Krok 0.5 — pytanie), `apply`/`bugfix` (Krok 4c/4 — `git add` dołącza `ai/changes/{nazwa}/tasks.md` w trybie współdzielonym), `archive` (Krok 2/2c — `git diff -- ai/specs` zamiast migawki; Krok 3 — commit przenosin do archiwum) |
| Kwalifikacja twierdzeń (bez przebudowy zachowania) | `propose`, `code-review` + `agents/code-reviewer.md`, `verify`, `status` — zdanie „`ai/` jest osobisty" przestaje być uniwersalnym faktem; zachowanie (skanuj tylko własne `ai/changes/`, generuj opis MR zawsze) zostaje konserwatywne w obu trybach |
| Obrona istniejącej decyzji | `explore` + `framework-lint.sh:192` (`forbid 'ai/product'`) + `docs/roadmap.md` (`/discover-sdd`) — reszta powodów (statusy F-XX, osobny agent) niezależna od trybu `ai/`; decyzja o braku żywego backlogu w `ai/product/` zostaje, uzasadnienie przestaje się opierać wyłącznie na „ai/ jest osobisty" |
| Regresje lintu | usunięte 3 reguły `forbid` (linie ~183-185 — `git diff --stat ai/specs`, `git add ai/`, `git add .*ai/changes`), bo poprawne w trybie współdzielonym; `require` na `git check-ignore` w `init` (linia 188) zostaje |
| Evale | `evals/{apply,verify,wiki}/scaffold.sh` dostają przełącznik `EVAL_AI_SHARED` pomijający wpis `/ai/` do `.git/info/exclude`; domyślne zachowanie (i baseline'y) bez zmian — nowe przypadki evali dla trybu współdzielonego **poza zakresem** |

## Taski

- [x] T1: `skills/init/SKILL.md` Krok 0.5 — `AskUserQuestion` (osobisty/współdzielony), rozwidlenie
  logiki, wynik w Kroku 4
- [x] T2: `skills/apply/SKILL.md` Krok 4c i `skills/bugfix/SKILL.md` Krok 4 — `git add` dołącza
  `ai/changes/{nazwa}/tasks.md` w trybie współdzielonym, jedno wywołanie Bash jak dziś
- [x] T3: `skills/archive/SKILL.md` Krok 2 (migawka) i 2c, Krok 3 (przenosiny) — rozwidlenie na
  `git diff -- ai/specs` / migawkę; commit przenosin do archiwum w trybie współdzielonym
- [x] T4: kwalifikacja twierdzeń — `skills/propose/SKILL.md`, `skills/code-review/SKILL.md`,
  `agents/code-reviewer.md`, `skills/verify/SKILL.md`, `skills/status/SKILL.md`
- [x] T5: `skills/explore/SKILL.md` i `docs/roadmap.md` (`/discover-sdd`) — przepisane uzasadnienie,
  decyzja bez zmian
- [x] T6: dokumentacja — `context/sdd.md`, `README.md`, `docs/getting-started.md`,
  `docs/workflow.md`, `templates/spec-template.md`, `templates/docs/git-workflow.md`
- [x] T7: `scripts/framework-lint.sh` — usunięcie 3 reguł regresji (sekcja 7)
- [x] T8: `evals/apply/scaffold.sh`, `evals/verify/scaffold.sh`, `evals/wiki/scaffold.sh` —
  przełącznik `EVAL_AI_SHARED`
- [x] T9: bramka — `framework-lint.sh` OK (0 błędów/ostrzeżeń); `claude plugin validate .` —
  jedyne ostrzeżenie: brak `version`. Smoke mechanizmów gita w scratchpadzie (`/tmp`, nie w repo):
  - `git check-ignore -q --no-index ai/` poprawnie rozpoznaje oba stany (brak reguły → exit 1;
    wpis w `core.excludesfile` → exit 0);
  - negacja `!/ai/` w projektowym `.gitignore` odkrywa `ai/` mimo globalnej reguły z innego
    projektu (exit 0 → exit 1 po dopisaniu), plik faktycznie trafia do `git ls-files`;
  - `git mv ai/changes/{nazwa} ai/changes/archive/{data}-{nazwa} && git commit` daje commit
    z rozpoznaną zmianą nazwy (`git log --stat` pokazuje `{nazwa => archive/...}`);
  - dwa commity na task (kod, potem ślad w `tasks.md` z hashem pierwszego) działają w kolejności
    opisanej w `apply` 4c — hash musi istnieć, zanim ślad go zacytuje;
  - `evals/{apply,verify,wiki}/scaffold.sh` w domyślnym trybie: `ai/` wciąż ignorowany (baseline
    evali nietknięty); z `EVAL_AI_SHARED=1`: `ai/` śledzony, skrypty kończą się bez błędu.
  Merge do `main` i push — czeka na użytkownika (ten sam blok auto-mode classifiera jak
  w `docs/plans/usun-regent-watch.md`).

## Poza zakresem

Realne wykorzystanie nowej widoczności w trybie współdzielonym (`propose` skanujący zmiany
kolegów, `code-review` czytający `ai/` z cudzego MR bez wklejania opisu, `status` z bezpośrednią
widocznością driftu kolegi) — zachowanie zostaje konserwatywne w tej zmianie, kontynuacja później.
Nowe przypadki evali dla trybu współdzielonego. Ponowne rozstrzygnięcie `ai/product/` /
`/discover-sdd` (decyzja w `roadmap.md` zostaje nienaruszona).

## Ryzyka

- **Globalna reguła ignore z innego projektu** — `init` wykrywa i proponuje `!/ai/` w projektowym
  `.gitignore`; bez tego krok 0.5 w trybie współdzielonym nic by nie zmienił.
- **Pierwszy commit `ai/` w trybie współdzielonym** — `init` tylko zapisuje pliki, nie commituje;
  pierwszy realny commit `ai/` nastąpi dopiero w `apply`/`bugfix`, razem z pierwszym taskiem.
  Trzeba to jasno powiedzieć w wyniku Kroku 4, inaczej `ai/docs/` zostanie nieśledzone do pierwszej
  zmiany.
- **Lint bez trzech reguł regresji** — inwariant „nie dodawaj `ai/` do gita w trybie osobistym"
  odpowiada teraz smoke w obu trybach, nie grep. Jeśli ktoś przez przypadek wróci do bezwarunkowego
  `git add ai/…`, złapie to tylko smoke albo realny błąd (kod 1) w sesji — zapisane świadomie,
  nie przeoczenie.
