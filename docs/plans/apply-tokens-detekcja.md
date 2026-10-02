# Plan: apply-tokens-detekcja

> Poprawka pomiaru przed końcem tygodnia sprawdzenia etapu 1 (`docs/plans/task-core.md`, sekcja
> „Sprawdzenie etapu”). Lekka ścieżka: gałąź `fix/apply-tokens-detekcja`, ten plan, bramka i smoke.
> Decyzja użytkownika 2026-10-02: detekcję poprawić teraz, regułę paczki dla sekcji designu spoza
> szablonu rozstrzygnąć po tygodniu.

## Cel

Pierwsze dwa uruchomienia `apply` z paczką w tygodniu sprawdzenia (2026-10-01 i 2026-10-02, projekt
prywatny, `frontend-dev`) `regent-apply-tokens` policzył jako „bez paczki”, bez odczytu plików
zmiany i bez zgłoszeń `BRAK W PACZCE`. Przyczyny w transkryptach:

1. Sesja główna zapisała paczkę do pliku w scratchpadzie i kazała agentowi przeczytać ją przez
   `Read` — `# Paczka:` jest w wyniku narzędzia, nie w prompcie.
2. Agent czytał sekcje `design.md` przez `sed -n` w Bash, a odczyt plików zmiany liczy tylko `Read`.
3. Agent pisał pliki heredokiem (`cat > … <<'EOF'`), a „pierwsza edycja” liczy tylko `Edit`
   i `Write` — wyszła pusta.
4. Raport subagenta idzie przez narzędzie `SubagentHandback` (`input.message`), a `BRAK W PACZCE`
   jest szukane tylko w tekście odpowiedzi. Agent pisał też nagłówek `## BRAK W PACZCE` z punktami
   zamiast linii z szablonu.

## Decyzje

| Decyzja | Wartość |
|---|---|
| Paczka | z paczką = `# Paczka: ` na początku linii promptu albo wyniku narzędzia w pierwszej turze (także z numerem linii z `Read`: `1\t# Paczka: `). Nowy wiersz „paczka z pliku”: ile uruchomień z paczką dostało ją przez narzędzie, choć skill każe wkleić ją do promptu |
| Odczyt plików zmiany | + wynik `Bash`, którego polecenie wskazuje `ai/changes/` oraz `tasks.md`, `design.md` albo `specs/`. Liczy się cały wynik — przybliżenie w górę, gdy polecenie czyta też inne pliki |
| Pierwsza edycja | + `Bash` zapisujący plik: przekierowanie `>`/`>>` (bez `/dev/null` i deskryptorów), `tee`, `sed -i`, `perl -i`; poza treścią heredoca i napisami w cudzysłowach. Zapis ze skryptu (np. Python w heredoku) zostaje niewidoczny |
| `BRAK W PACZCE` | + `input.message` z `SubagentHandback`; + punkty pod nagłówkiem `BRAK W PACZCE` (do następnego nagłówka). Zgłoszenie zaczynające się od „brak”, „nic”, „nie” albo „none” to brak zgłoszenia |
| Punkt odniesienia | przeliczony nową metryką, żeby obie grupy liczyć tak samo; liczby z Przebiegu sesji 4 zostają w historii `task-core.md`, różnice w Przebiegu tego planu |

## Taski

- [x] T1: `firstturn.ts` — paczka w wyniku narzędzia, odczyt i zapis przez Bash, raport
  z `SubagentHandback` i spod nagłówka; testy na syntetycznym transkrypcie
- [x] T2: `apply-tokens.ts` — grupa z paczką z `FirstTurn`, wiersz „paczka z pliku” (tekst i JSON),
  pomoc; testy; `docs/tasks.md` — sekcja pomiaru
- [x] T3: bramka (`framework-lint.sh`, `claude plugin validate .`, `npm test` i `npm run typecheck`
  w `tools/watch/`) i smoke: tydzień sprawdzenia rozpoznaje 2 uruchomienia z paczką, punkt
  odniesienia przeliczony (różnice wobec sesji 4 w Przebiegu); merge do `main`

## Poza zakresem

Reguła paczki dla sekcji designu spoza szablonu oraz braki, które sesja główna wypisuje w prompcie
zamiast agenta — do decyzji po tygodniu sprawdzenia. Zmiana skilla `apply` (paczka w prompcie czy
w pliku).

## Przebieg (2026-10-02)

- T1: `firstturn.ts` — `packet: 'prompt' | 'tool'` (nagłówek `# Paczka: ` w prompcie albo w wyniku
  narzędzia pierwszej tury, także `1\t# Paczka: ` z `Read`), `bashWrites` (przekierowanie, `tee`,
  `sed -i`, `perl -i`, z pominięciem heredoca i cudzysłowów), odczyt plików zmiany przez Bash,
  `missingKeys` (linie z szablonu, punkty pod nagłówkiem, bez „brak”) i raport z `SubagentHandback`.
  21 nowych testów (92 w `tools/watch`).
- T2: `apply-tokens.ts` — grupa z paczką z `FirstTurn.packet`, `packetFromFile` w JSON i wiersz
  „paczka z pliku” w tabeli, pomoc; w teście polecenia subagent czytający paczkę z pliku;
  `docs/tasks.md` — sekcja pomiaru; odsyłacz w `task-core.md`, sekcja „Sprawdzenie etapu”.
- T3: bramka zielona (lint bez uwag, validate tylko `version`, testy i typecheck `tools/watch`).
  Smoke na transkryptach prywatnych, tylko odczyt `~/.claude/projects`:
  - tydzień sprawdzenia (`--since 2026-09-29`): 2 subagentów `frontend-dev`, oba z paczką, oba
    z pliku (2/2). Suma pierwszej tury 3,5 i 3,8 mln (mediana 3,6 mln wobec 5,0 mln w punkcie
    odniesienia), 30 i 31 wywołań (51), kontekst przy pierwszej edycji 54 i 103 tys. (przed
    poprawką: brak i 107 tys.; odniesienie 80 tys.), maksymalny 175 i 177 tys. (125 tys.). Pliki
    zmiany czytał 1 z 2: ~11 tys. tokenów `design.md` przez Bash — sekcje spoza szablonu, które
    sesja główna wskazała w prompcie (odniesienie: ~22 tys., 28 z 28). `BRAK W PACZCE`: brak
    zgłoszeń — drugi agent w każdym raporcie „Brak.”, pierwszy nie zgłaszał, bo braki podała
    sesja główna;
  - punkt odniesienia (`--until 2026-09-28`) po zmianie metryki: bez zmian poza medianą odczytu
    plików zmiany 22 362 → 22 369 (odczyty przez Bash), 0 uruchomień z paczką — liczby z sesji 4
    zostają ważne do porównania.
- Do decyzji po tygodniu: sekcje designu spoza szablonu w paczce (`— design: <sekcja>` w taskach
  albo reguła paczki) i braki, które sesja główna wypisuje sama — dziś widać je tylko jako odczyt
  plików zmiany przy paczce.
