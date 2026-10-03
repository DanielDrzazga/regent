# Plan: apply-kontynuacje

> Poprawka w tygodniu sprawdzenia etapu 1 (`docs/plans/task-core.md`, sekcja „Sprawdzenie etapu”).
> Lekka ścieżka: gałąź `fix/apply-kontynuacje`, ten plan, bramka i smoke. Decyzja użytkownika
> 2026-10-02: pomiar kontynuacji i reguła „nowy agent na paczkę” w skillu `apply` — obie teraz.

## Cel

Sesja `apply` z 2026-10-02 (projekt prywatny, 13 tasków `[FE]`) uruchomiła jednego subagenta
`frontend-dev`, a kolejne taski i rundę napraw po `verify` wysyłała mu przez `SendMessage`
(13 wiadomości). Każda tura zaczynała od całej historii: kontekst 17k → 177k → 280k → 383k → 494k,
39M tokenów wejścia w jednym agencie, a po przerwach 16 i 21 min cache zapisał się od nowa (247k
i 383k naraz). Stare sesje `apply` uruchamiały świeżego agenta (15 × `Agent`, 0 × `SendMessage`,
największy subagent 190k).

1. **Pomiar tego nie widział.** `regent-apply-tokens` liczy pierwszą turę, więc pokazał 3,8M —
   jak sukces paczki. Raport przez `SubagentHandback` nie zawsze kończy turę `end_turn`, a wtedy
   „pierwsza tura” wciąga też kontynuacje.
2. **Skill tego nie zabraniał.** „Jedno uruchomienie agenta z listą tasków”, „commit po każdym
   tasku” i „resume po agentId” przy `OPEN QUESTIONS` sesja główna pogodziła, prowadząc jednego
   agenta task po tasku. Tekst jest ten sam co w starej komendzie `apply-sdd`.

## Decyzje

| Decyzja | Wartość |
|---|---|
| Wiadomość do agenta | rekord `user` z tekstem (bez `tool_result`) po pierwszym wywołaniu API: z prefiksem `The coordinator sent a message` albo `The user sent a new message` (tak Claude Code wstawia `SendMessage`, rekord `isMeta`) albo nie-meta, który nie zaczyna się od `[` ani `<`. Inne meta-rekordy (obrazy, przypomnienia, przerwania, ucięta odpowiedź) nie są wiadomościami — w transkryptach subagentów na tej maszynie wiadomości mają tylko te dwa prefiksy |
| Koniec pierwszej tury | jak dotąd `end_turn`/… albo `turn_duration`, a dodatkowo pierwsza wiadomość do agenta |
| Cały agent | wszystkie wywołania API transkryptu (deduplikacja po `message.id`): suma wejścia, kontekst maksymalny, liczba wiadomości |
| Wynik | wiersze „kontynuowani” (`k/n`), „wiadomości do agenta” (suma), mediany „suma wejścia całego agenta” i „kontekst: maksymalny (cały agent)”. JSON: `continued`, `messages`, `median.sumAll`, `median.maxCtxAll` |
| Skill `apply` | uruchomienie = nowy subagent z nową paczką; kolejnego taska ani rundy (także napraw po `verify`) nie wysyłasz przez `SendMessage` agentowi, który już raportował. Kontynuacja tylko: odpowiedzi na `OPEN QUESTIONS` i poprawka tych samych tasków przed commitem. Commit po każdym tasku, a taski dzielą pliki → jeden task na uruchomienie |
| Paczka | do pliku w scratchpadzie (`regent.sh task packet … > <plik>`), w prompcie ścieżka i polecenie, by agent najpierw przeczytał ją w całości. Odstępstwo od „paczki w prompcie” z rozmowy: paczka z 2026-10-02 miała 41,9 kB (~12 tys. tokenów) — w prompcie weszłaby do kontekstu sesji głównej dwa razy (wynik `packet` i wejście `Agent`), a model przepisywałby ją tokenami wyjścia. Sesja główna i tak zrobiła tak w 2 z 2 uruchomień |

## Taski

- [x] T1: `firstturn.ts` — wiadomości do agenta, koniec pierwszej tury na wiadomości, wywołania
  całego agenta; testy na syntetycznym transkrypcie (kontynuacja bez `end_turn`, meta-rekordy,
  które nie są wiadomościami)
- [x] T2: `apply-tokens.ts` — wiersze i JSON całego agenta, pomoc; testy; `docs/tasks.md` — sekcja
  pomiaru
- [x] T3: skill `apply` — nowy subagent na paczkę, `SendMessage` tylko do `OPEN QUESTIONS`
  i poprawek, paczka z pliku; `agents/dba.md` (paczka z pliku), `docs/tasks.md` (ścieżka z CLI),
  regresja w `framework-lint.sh`
- [x] T4: bramka (`framework-lint.sh`, `claude plugin validate .`, `npm test` i `npm run typecheck`
  w `tools/watch/`) i smoke: tydzień sprawdzenia pokazuje kontynuowanego agenta, punkt odniesienia
  przeliczony (różnice w Przebiegu); merge do `main`

## Poza zakresem

Rozmiar paczki przy długich liniach tasków (dziś ~8 kB na task), reguła paczki dla sekcji designu
spoza szablonu, wymuszenie reguły hookiem (np. ostrzeżenie przy `SendMessage` do agenta `apply`) —
po tygodniu sprawdzenia, jeśli reguła w skillu nie wystarczy.

## Przebieg (2026-10-03)

- T1: `firstturn.ts` — `allCalls` i `messages` w `FirstTurn`; wiadomość (`isMessage`: prefiks
  `SendMessage` albo nie-meta bez `[`/`<`) po pierwszym wywołaniu kończy pierwszą turę; wywołania
  liczone do końca transkryptu. 5 nowych testów: kontynuacja z raportem przez `SubagentHandback` bez
  `end_turn`, przypomnienie przed pierwszym wywołaniem, obraz, ucięta odpowiedź i przerwanie nie są
  wiadomościami, `BRAK W PACZCE` z raportu kontynuacji.
- T2: `apply-tokens.ts` — `continued`, `messages`, `median.sumAll`, `median.maxCtxAll` (JSON) i cztery
  wiersze tabeli, pomoc; w teście polecenia subagent z paczką kontynuowany po `end_turn` (pierwsza
  tura bez zmian, cały agent większy). 98 testów w `tools/watch`; `docs/tasks.md` — sekcja pomiaru.
- T3: skill `apply` — „Uruchomienie = nowy subagent” w sekcji Agenci, wspólne pliki tasków → jeden
  task na uruchomienie, Krok 4a: paczka `> <scratchpad>/paczka-….md` i polecenie przeczytania jej
  najpierw, barierka w WAŻNE Rules; `agents/dba.md` i `docs/tasks.md` (paczka z pliku); w lint
  `require` „Uruchomienie = nowy subagent” i `forbid` „Prompt subagenta: paczka w całości” — oba łapią
  wersję z `main`.
- T4: bramka zielona (lint bez uwag, validate tylko `version`, testy i typecheck `tools/watch`).
  Smoke, tylko odczyt `~/.claude/projects`:
  - **oba uruchomienia z paczką z tygodnia sprawdzenia zniknęły** — sesje usunięte 2026-10-03
    w aplikacji desktop (`<sesja>.desktop-released.json`, `"reason": "delete"`, 22 sesje prywatne),
    razem z transkryptami subagentów. Kontynuowanego agenta z Celu nie da się już policzyć
    narzędziem; liczby w Celu pochodzą z analizy 2026-10-02, przed usunięciem;
  - na tych samych transkryptach gałąź i `main` dają identyczne metryki pierwszej tury: punkt
    odniesienia (`--until 2026-09-28`) to dziś 23 subagentów zamiast 28 (usunięte sesje), mediany
    5,0M / 52 wywołania / 78k przy pierwszej edycji / 128k maks. / 22k odczytu plików zmiany —
    praktycznie jak w sesji 4. Nowe wiersze: kontynuowani 2/23, 5 wiadomości, mediany całego agenta
    jak pierwszej tury;
  - wiadomości zgadzają się z rekordami z prefiksem `SendMessage` (3 agentów na tej maszynie, 1+1+4).
    W starym SDD też: `frontend-dev` z 2026-09-23 dostał 4 wiadomości i doszedł do 376k;
  - tydzień sprawdzenia (`--since 2026-09-29`): został 1 subagent `backend-dev` z 2026-10-03, bez paczki,
    bez kontynuacji.
- Wniosek dla tygodnia: do 2026-10-06 sesji `apply` nie usuwać; dopisane w `task-core.md`, sekcja
  „Sprawdzenie etapu”.
