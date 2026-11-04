# Plan: usun-regent-watch

> Regent przestaje być narzędziem tylko jednej osoby — czas posprzątać ustalenia, które były
> osobistą eksploracją, nie rdzeniem frameworka. Lekka ścieżka: gałąź `chore/usun-regent-watch`,
> ten plan, bramka i smoke. Decyzja użytkownika 2026-11-03: usuń `regent-watch` całkowicie.

## Cel

`regent-watch` (TUI mission-control w stylu OpenRig, pakiety `cli.ts`/`main.tsx`/`ui/`) znika
z repo. Powstał jako odpowiedź na pytanie z osobistej wizji („który aspekt OpenRig się spodobał")
i nie jest potrzebny, żeby Regent działał jako framework dla innych. `regent-apply-tokens`
(pomiar tokenów/paczek `apply`, używany w T9 toru `/regent:optimize`) zostaje — to rdzeń
frameworka, nie osobista preferencja.

## Decyzje (2026-11-03)

| Decyzja | Wartość |
|---|---|
| Zakres | usuń UI (`cli.ts`, `main.tsx`, `ui/`, `store.ts`, `view.ts`, `tmux.ts`, `workspace.ts`, `tail.ts`, `parse/team.ts`) i ich testy; zostaw `apply-tokens-cli.ts`, `apply-tokens.ts`, `parse/{firstturn,pricing,tools,transcript}.ts`, `session.ts` (tylko `defaultClaudeDir`), `units.ts` (tylko `fmtTokens`) |
| Katalog/nazwa pakietu | **zmiana decyzji 2026-11-04** (niżej, „Przebieg") — `tools/watch/` zniknął, `regent-apply-tokens` przeniesiony do `tools/regent/` jako drugi bin tego samego pakietu; pierwotna decyzja „zostaje, nie przenoszę" nieaktualna |
| `docs/plans/watch-ui.md`, `agent-teams-view.md` i inne historyczne plany | zostają bez zmian — zapis decyzji z przeszłości, lint (`docs/plans/`) ich nie sprawdza |
| `docs/agent-teams.md` | agent teams (natywna funkcja Claude Code) zostaje jako osobny temat — tylko sekcja `regent-watch` i jej odwołania wylatują |
| `.claude/rules/project.md` | zdanie „`regent-watch` staje się jego TUI" usuwa się — harness na razie bez TUI, bez nowego zobowiązania |
| Rejestr decyzji | wpis w `docs/roadmap.md` (świadomie poza frameworkiem) — hash z tego repo, nie z zamrożonego `claude-sdd-framework` |

## Taski

- [x] T1: usuń plik/katalogi UI `regent-watch` (`cli.ts`, `main.tsx`, `ui/`, `store.ts`, `view.ts`,
  `tmux.ts`, `workspace.ts`, `parse/team.ts`) i ich testy (`app.test.tsx`, `session.test.ts`,
  `store.test.ts`, `tail.test.ts`, `team.test.ts`, `view.test.ts`, `workspace.test.ts`); przytnij
  `session.ts` do `defaultClaudeDir`, `units.ts` do `fmtTokens`, `helpers.ts` do tego, co jeszcze
  czyta `transcript.test.ts`; usuń nieużywane fixture'y (`-tmp-inny/`, `teams/`, `subagents/`,
  sesja `OTHER`)
- [x] T2: `package.json` — `name` → `regent-apply-tokens`, opis zgodny z zawartością, `bin` tylko
  `regent-apply-tokens`, usuń zależności `ink`/`react` i dev `ink-testing-library`/`@types/react`;
  `tsconfig*.json` bez `jsx`, jeśli był tylko dla Ink; `npm install` + `npm run build` + `npm test`
  w `tools/watch/` zielone
- [x] T3: dokumentacja — `README.md` (spis treści, drzewo repo, sekcja „Agent teams i regent-watch"
  → „Agent teams", odnośnik w „Dokumentacja rozszerzona"), `docs/README.md` (indeks), `docs/tasks.md`
  (porównania instalacji i „parser regent-watch"), `docs/agent-teams.md` (usuń sekcję `regent-watch`,
  `## Prywatność` i `## Ograniczenia` specyficzne dla niego, przepisz tytuł i wstęp)
- [x] T4: `.claude/rules/project.md` — usuń „a `regent-watch` staje się jego TUI"; `docs/roadmap.md`
  — wpis w tabeli „Świadomie poza frameworkiem" z hashem ostatniego commita, gdzie `regent-watch`
  jeszcze istnieje w całości
- [x] T5a: bramka (`bash scripts/framework-lint.sh` — OK, 0 błędów/ostrzeżeń; `claude plugin
  validate .` — jedyne ostrzeżenie: brak `version`) i smoke (`npm install && npm run build && npm
  test` w `tools/watch/` — 59/59 zielone; `regent-apply-tokens --help` z zbudowanego `dist/` działa)
- [ ] T5b: merge do `main` i push — **zablokowane**: auto-mode classifier odmówił `git merge` do
  `main` z tej sesji („dangerous", bez dalszego uzasadnienia). Gałąź `chore/usun-regent-watch`
  wypchnięta na `origin`, czeka na merge przez użytkownika (ręcznie albo z sesji z innym trybem
  uprawnień)
- [x] T6: zmiana decyzji 2026-11-04 — przenieś `regent-apply-tokens` (`apply-tokens.ts`,
  `apply-tokens-cli.ts`, `parse/`, `session.ts`, `units.ts`) i jego testy/fixture'y z `tools/watch/`
  do `tools/regent/`; drugi `bin` w `tools/regent/package.json`; usuń `tools/watch/` całkowicie;
  `npm install && npm run build && npm test` w `tools/regent/` zielone (152 testy)
- [x] T7: dokumentacja po przenosinach — `README.md` (drzewo repo: jeden wiersz `tools/regent/`),
  `docs/README.md`, `docs/tasks.md` (instalacja, ścieżka parsera), `docs/plans/optimize.md`
  (ścieżka `pricing.ts`), `docs/roadmap.md` (ścieżka przywrócenia `regent-watch` z uwagą
  o przeniesionym `regent-apply-tokens`); bramka ponownie zielona

## Poza zakresem

Zamiennik TUI dla harnessu (roadmapowy punkt odłożony, nie rozstrzygnięty tu).

## Ryzyka

- **T9 `/regent:optimize`** (`docs/plans/optimize.md`) zależy od `regent-apply-tokens` — dlatego
  zostaje; użytkownik potwierdził to świadomie (patrz „Przebieg").
- **Niespójność nazwa/katalog** — rozwiązana 2026-11-04: `regent-apply-tokens` przeniesiony
  do `tools/regent/`, jeden pakiet, bez osobnego `tools/watch/`.

## Przebieg (2026-11-03)

Sesja zaczęła od pytania o zakres: `tools/watch/` to jeden pakiet npm z dwoma binami
(`regent-watch` — UI, `regent-apply-tokens` — pomiar). Użytkownik po zapoznaniu się z zależnościami
(`apply-tokens.ts` → `parse/firstturn.ts`, `session.ts`, `units.ts`, nie UI) i z tym, że T9 toru
`/regent:optimize` wymaga `regent-apply-tokens` jako następny krok — potwierdził: **usuń całe UI,
zostaw to, co używane w innych miejscach**. Użytkownik poszedł spać, decyzje wykonawcze (katalog,
nazwa pakietu, co zostaje w `session.ts`/`units.ts`/`helpers.ts`) podjęła sesja.

Przy tej okazji sprawdzony szerszy sprzątanie „elementów prywatnych” (na żądanie użytkownika):
`main` miał już świeży commit `f677200` usuwający `.claude/rules/privacy.md` i specyfikę
maszyn/pracodawcy z `git.md`/`project.md`/`README.md`. Dodatkowy skan repo (emaile, sekrety,
ścieżki `/Users`/`/home`, „Mac”, „firmow”) nie znalazł nic poza historycznymi planami
(`docs/plans/`, poza zakresem lintu) i poprawnymi odwołaniami (atrybucja, `git.md`, evale z
`example.invalid`). Jedyny realny ślad do usunięcia był `regent-watch` sam — stąd ta zmiana.

Bramka i smoke zielone (T5a), ale `git merge` do `main` z tej sesji zablokował auto-mode
classifier („dangerous", bez dalszego uzasadnienia) — T5b czeka na użytkownika. Commit też musiał
dostać poprawiony autora: `git config user.email` w tej sesji był pusty (naprawione lokalnie na
adres z `git.md`, zanim cokolwiek wypchnięto).

## Przebieg (2026-11-04)

Dalsze sprzątanie prywatnych elementów (na żądanie użytkownika) doprowadziło do pytania: po co
osobny pakiet `tools/watch/`, gdy został w nim tylko jeden bin (`regent-apply-tokens`), a drugi
pakiet (`tools/regent/`) ma identyczne `devDependencies` i ten sam wzorzec CLI (`Io`, jak
`tools/regent/src/main.ts` — już zauważone w `docs/plans/task-core-check.md`)? Użytkownik:
**przenieś to, co potrzebne, z `watch` do `regent`**.

- T6: `git mv` modułów (`parse/`, `session.ts`, `units.ts`, `apply-tokens.ts`, `apply-tokens-cli.ts`)
  i testów (`firstturn.test.ts`, `pricing.test.ts`, `tools.test.ts`, `transcript.test.ts`,
  `apply-tokens.test.ts`, fixture'y `claude/projects/`) do `tools/regent/`; `helpers.ts` z `watch/`
  zmienił nazwę na `watch-helpers.ts` (kolizja z istniejącym `tools/regent/test/helpers.ts` — inny
  plik, inne fixture'y, zero wspólnego kodu). Drugi `bin` w `package.json`, bez nowych zależności
  (te same `@types/node`/`typescript`/`vitest` w obu pakietach już wcześniej). `tools/watch/`
  usunięty w całości (`package.json`, `package-lock.json`, `tsconfig*.json`, `.gitignore`).
  Zielone: `npm install`, `npm run build`, `npm run typecheck`, `npm test` — 152/152 (93 regent +
  59 watch), smoke `regent --help` i `regent-apply-tokens --help` z jednego `dist/`.
- T7: poprawione odwołania w `README.md` (jeden wiersz drzewa dla `tools/regent/`), `docs/README.md`,
  `docs/tasks.md` (zdjęta nieaktualna uwaga „instalowany osobno jak regent-apply-tokens" — to już
  ten sam pakiet), `docs/plans/optimize.md` (`pricing.ts` pod nową ścieżką) i `docs/roadmap.md`
  (ścieżka przywrócenia `regent-watch` dostała uwagę, że `regent-apply-tokens` trzeba by wtedy
  wymontować z `tools/regent/` z powrotem). Bramka (`framework-lint.sh`, `claude plugin validate .`)
  zielona po zmianach.
- Ten sam zablokowany krok jak wczoraj: merge do `main` robi użytkownik, nie ta sesja.
