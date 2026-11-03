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
| Katalog/nazwa pakietu | `tools/watch/` zostaje (nie przenoszę) — zmiana ścieżki uderzyłaby w odwołania w `docs/plans/optimize.md` (aktywny, T9) i w historyczne plany; `package.json` **name** → `regent-apply-tokens`, bo to jedyny bin, który zostaje |
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
- [x] T5: bramka (`bash scripts/framework-lint.sh` + `claude plugin validate .`) i smoke
  (`regent-apply-tokens --help` z zbudowanego `dist/`), merge do `main`, push

## Poza zakresem

Przeniesienie/rename katalogu `tools/watch/` → `tools/apply-tokens/` (osobna decyzja, większy
blast radius w historycznych planach); zamiennik TUI dla harnessu (roadmapowy punkt odłożony,
nie rozstrzygnięty tu).

## Ryzyka

- **T9 `/regent:optimize`** (`docs/plans/optimize.md`) zależy od `regent-apply-tokens` — dlatego
  zostaje; użytkownik potwierdził to świadomie (patrz „Przebieg").
- **Niespójność nazwa/katalog** — pakiet `regent-apply-tokens` mieszka w `tools/watch/`; zapisane
  w tym planie jako świadomy wybór, nie przeoczenie.

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
