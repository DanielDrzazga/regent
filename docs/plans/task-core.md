# Plan: task-core

> Etap 1 planu produktu (poza repo): rdzeń zadań warstwy runtime Regenta. Lekka ścieżka: gałąź
> `feat/task-core`, ten plan, bramka i smoke. Plan czeka na potwierdzenie dwóch decyzji
> oznaczonych **do potwierdzenia**; do tego czasu nic nie jest implementowane.

## Cel

Żadne zadanie nie ginie bez śladu. Każde ma dokładnie jednego właściciela i log przejść. Kończy się
jawnym zamknięciem z powodem albo przekazaniem. Zadania z cyklu SDD zakładają się i przesuwają same
(liczy je skrypt z artefaktów w `ai/changes/`, nie model). Ręczne polecenia są dla wyjątków.
Uczestnicy: jeden agent i Ty; seaty to etap 2.

## Decyzje (2026-09-29)

| Decyzja | Wartość |
|---|---|
| Proces demona | **do potwierdzenia**: w etapie 1 bez procesu w tle. Jedno źródło stanu to baza i jeden moduł, który ją zmienia; CLI, hooki i później TUI tylko przez niego. Utknięcie liczy się przy odczycie, więc w etapie 1 nic nie musi działać w tle. Proces w tle (launchd/systemd, gniazdo, restarty) wchodzi, gdy pojawi się akcja w czasie: wznowienie po resecie (etap 3) albo push (etap 5) |
| Technologia | **do potwierdzenia**: Node 24 + TypeScript jak `regent-watch`, baza przez wbudowane `node:sqlite` (bez natywnej kompilacji na każdej maszynie), testy Vitest; pakiet `tools/regent/`, polecenie `regent` |
| Baza | jedna na maszynę: `${XDG_STATE_HOME:-~/.local/state}/regent/regent.db`, WAL, `busy_timeout` (równoległe hooki kilku sesji), wersja schematu w `user_version` z migracjami. Bez synchronizacji i bez kodu sieciowego — dane projektów z pracy nie opuszczają maszyny |
| Zadanie | projekt (korzeń gita), klucz (`sdd:<zmiana>` albo numer ręcznego), tytuł, stan, właściciel, ostatnia sesja i jej transkrypt, powód ostatniego przejścia. Priorytet dopiero w etapie 3 |
| Właściciel | `me` albo `agent`; od etapu 2 adres seatu. Przekazanie do `me` = stan „czeka na Ciebie” |
| Stany | oczekuje, w toku, czeka na Ciebie, wstrzymane do resetu (używane od etapu 3), zablokowane, przekazane, zakończone, porzucone. Zakończone i porzucone wymagają powodu; tabela dozwolonych przejść w kodzie, niedozwolone przejście → błąd z listą możliwych |
| Log przejść | każda zmiana stanu lub właściciela: czas, z → do, właściciel z → do, powód, źródło (`cli`, `sync`), sesja. Tylko dopisywanie |
| Utknięcie | liczone przy odczycie, nie zapisywane: zadanie w toku, którego ostatnia sesja nie zmieniła transkryptu od progu (domyślnie 30 min, `--stuck <min>`), albo zadanie w toku bez sesji |
| Polecenia | `regent task add <tytuł>`, `take <id>`, `handoff <id> <właściciel> --reason`, `done <id> --reason`, `drop <id> --reason`, `list [--all]` (z sekcją Uwaga: utknięte, bez artefaktów, czas ostatniego sync), `show <id>` (historia), `sync`; `--json` przy odczycie |
| Mapa SDD → stan | z `sdd-check.sh status` i `ai/changes/archive/`: `Draft` → czeka na Ciebie (spec do akceptacji); `Approved`, 0 tasków zrobionych → oczekuje; część zrobiona → w toku; wszystkie, bez weryfikacji → oczekuje (do weryfikacji); `BLOCK` → w toku (poprawki); `PASS`/`WARN` → czeka na Ciebie (przegląd i archiwum); `Rejected` → porzucone; w archiwum → zakończone, a z `Status: Abandoned` → porzucone |
| Sync a ręczne zmiany | sync zapisuje przejście tylko wtedy, gdy zmieniła się sygnatura artefaktów zmiany (Status, taski, werdykt, archiwum). Ręczne `done` czy `handoff` zostaje, dopóki pliki się nie ruszą |
| Zmiana zniknęła | katalog zniknął bez archiwum → zadanie zostaje otwarte z ostrzeżeniem w `list` („nie wiem” zamiast zgadywania); zamyka je człowiek |
| Hooki | `SessionStart` i `Stop` pluginu w projektach z `ai/docs/` wołają `regent task sync` z `session_id` i `transcript_path` z JSON-a hooka. Nic na stdout (stdout `SessionStart` trafia do kontekstu), zawsze kod 0, błąd do logu obok bazy; brak zbudowanego CLI → hook milczy |

## Taski

- [ ] T1: pakiet `tools/regent/` (Node 24, TS, Vitest, bin `regent`), warstwa bazy w jednym pliku
  (ścieżka, WAL, `busy_timeout`, migracje przez `user_version`, wyciszone `ExperimentalWarning`
  z `node:sqlite`); testy na bazie w katalogu tymczasowym
- [ ] T2: model zadań — stany, tabela przejść, właściciel, log tylko do dopisywania, powód przy
  zamknięciu; testy dozwolonych i odrzuconych przejść
- [ ] T3: polecenia `add`, `take`, `handoff`, `done`, `drop`, `list`, `show` (tekst i `--json`, kody
  wyjścia: 0 — ok, 1 — odrzucone przejście, 2 — błędne użycie); testy
- [ ] T4: utknięcie przy odczycie (mtime transkryptu ostatniej sesji, próg `--stuck`) i sekcja Uwaga
  w `list`; testy z podmienionym zegarem
- [ ] T5: `sync` — mapa SDD → stan, sygnatura artefaktów, ostrzeżenie o zniknięciu; w skillu
  `archive` przy `--abandon` zapis `Status: Abandoned` w `proposal.md` (jawny znacznik zamiast
  zgadywania z tabeli History); testy na fixture'ach `ai/changes/`
- [ ] T6: hooki `SessionStart` i `Stop` w `hooks/hooks.json` + skrypt `scripts/hooks/task-sync.sh`
  (zakres `ai/docs/`, cisza na stdout, kod 0, log błędów, brak CLI → cisza); testy w bashu 3.2 i z PATH
- [ ] T7: dokumentacja — `docs/tasks.md` (instalacja jak `regent-watch`, polecenia, mapa stanów SDD,
  utknięcie), wpis w README; bramka: `framework-lint.sh`, `claude plugin validate .`, `npm test`
  i `npm run typecheck` w `tools/regent/`
- [ ] T8: smoke — zmiana SDD w projekcie testowym przechodzi propose → apply → verify → archive,
  każdy krok widać w `regent task show` bez ręcznych poleceń; porzucenie przez `--abandon`;
  ręczne `add` → `take` → `handoff me` → `done`; pomiar czasu hooka `Stop`
- [ ] T9: merge `feat/task-core` → `main`, push; start tygodnia sprawdzenia (data w Przebiegu)

## Ryzyka

- **`node:sqlite` jest eksperymentalne w Node 24** — API może się zmienić. Cała baza za jednym
  modułem, więc podmiana (np. na `better-sqlite3`) dotyka jednego pliku.
- **Koszt hooka `Stop` przy każdej turze** — start Node to dziesiątki milisekund. Pomiar w T8; gdy
  za drogo, sync tylko przy zmianie mtime `ai/changes/` (sprawdzane w bashu przed startem Node).
- **Dwa miejsca stanu SDD** — faza zmiany żyje w plikach, a baza tylko rejestruje przejścia
  wyliczone z plików. Baza nigdy nie pisze do `ai/`.
- **Nowa maszyna bez zbudowanego CLI** — hook milczy, więc `list` na innej maszynie nic nie wie.
  Uczciwy stan: `list` pokazuje czas ostatniego sync, a brak bazy to komunikat, nie pusta lista.

## Poza zakresem

Seaty i wstrzykiwanie kontekstu (etap 2), priorytety, limit i wstrzymanie do resetu (etap 3),
proces demona (etap 3 — o ile zapadnie decyzja wyżej), worktree i praca bez nadzoru (etap 4), TUI
w `regent-watch`, push i connector MCP (etap 5), klasy zadań „przy okazji”.

## Sprawdzenie etapu

Tydzień realnej pracy z pluginem na jednej maszynie. Na koniec `regent task list --all` i historia
pokazują, że:
- każda zmiana z `ai/changes/` z tego tygodnia ma zadanie;
- każde zamknięte zadanie ma powód;
- żadne zadanie w toku nie wisi bez właściciela ani bez wyjaśnionego utknięcia.
