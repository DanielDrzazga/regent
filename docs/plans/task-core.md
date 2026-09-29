# Plan: task-core

> Etap 1 planu produktu (poza repo): rdzeń zadań warstwy runtime Regenta. Lekka ścieżka: gałąź
> `feat/task-core`, ten plan, bramka i smoke. Wzór: kolejka OpenRig 0.5.17 (`queue_items` +
> `queue_transitions`), przycięta do jednego agenta i Ciebie. Podział na sesje i prompty:
> `docs/plans/task-core-sessions.md`.

## Cel

1. **Żadne zadanie nie ginie bez śladu.** Każde ma dokładnie jednego właściciela i log przejść.
   Kończy się jawnym zamknięciem z powodem albo przekazaniem. Zadania z cyklu SDD zakładają się
   i przesuwają same: liczy je skrypt z artefaktów w `ai/changes/`, nie model.
2. **Agent dostaje jedno zadanie, nie całe pliki.** `regent task next` zwraca rekord z bazy
   z paczką: task, jego AC i potrzebne sekcje designu. Pomiar 2026-09-29 (31 zmian z dwóch
   projektów prywatnych, mediany): agent implementujący czyta dziś na starcie `tasks.md` ~2 tys.
   tokenów, `design.md` ~6 tys. i delta specs ~5,6 tys.; paczka szacunkowo 1,5–3 tys. Każdy token
   przeczytany na starcie wraca w każdej kolejnej turze sesji.

## Decyzje (2026-09-29, potwierdzone)

| Decyzja | Wartość |
|---|---|
| Proces demona | w etapie 1 bez procesu w tle. Jedno źródło stanu to baza i jeden moduł, który ją zmienia; CLI, hooki, skille i później TUI tylko przez niego. Utknięcie liczy się przy odczycie. Proces w tle wchodzi z akcją w czasie: wznowienie po resecie (etap 3) albo push (etap 5) |
| Technologia | Node 24 + TypeScript jak `regent-watch`, baza przez wbudowane `node:sqlite` (bez natywnej kompilacji), testy Vitest; pakiet `tools/regent/`, polecenie `regent` |
| Baza | jedna na maszynę, jak w OpenRig: `${XDG_STATE_HOME:-~/.local/state}/regent/regent.db`, kolumna `project` (korzeń gita). WAL, `busy_timeout` (równoległe hooki kilku sesji), wersja schematu w `user_version`. Nie w projekcie: `ai/` bywa w gicie (w jednym z projektów 172 pliki), więc baza trafiałaby do commitów |
| Dwa poziomy | zmiana SDD (rodzic, `sdd:<zmiana>`) i jej taski `T-NN` (dzieci); ręczne zadania bez rodzica |
| Źródło prawdy | treść (taski, AC, design) zostaje w Markdown. Po `Status: Approved` o statusie tasków decyduje baza, a checkboxy i ślad w `tasks.md` przepisuje skrypt (lustro, jak markdown w OpenRig). Ręczna zmiana w `tasks.md` wygrywa, bo sync widzi zmianę pliku |
| Schemat | `tasks(id, project, parent_id, key, kind, tag, title, owner, state, refs JSON, closure_reason, session_id, transcript_path, file_sig, claimed_at, created_at, updated_at)` i `transitions(id, task_id, at, state, owner, actor, source, reason)` — tylko INSERT. Priorytet dopiero w etapie 3 |
| Właściciel | `me` albo `agent`; od etapu 2 adres seatu. Przekazanie do `me` = stan „czeka na Ciebie” |
| Stany | oczekuje, w toku, czeka na Ciebie, wstrzymane do resetu (od etapu 3), zablokowane, przekazane, zakończone, porzucone. Zakończone i porzucone wymagają powodu; tabela dozwolonych przejść w kodzie, niedozwolone → błąd z listą możliwych |
| Utknięcie | przy odczycie: zadanie w toku, którego ostatnia sesja nie zmieniła transkryptu od progu (domyślnie 30 min, `--stuck <min>`), albo zadanie w toku bez sesji |
| Mapa SDD → stan zmiany | z `sdd-check.sh status` i `ai/changes/archive/`: `Draft` → czeka na Ciebie; `Approved`, nic nie zrobione → oczekuje; część tasków → w toku; wszystkie, bez weryfikacji → oczekuje (do weryfikacji); `BLOCK` → w toku; `PASS`/`WARN` → czeka na Ciebie; `Rejected` → porzucone; w archiwum → zakończone, z `Status: Abandoned` → porzucone. Katalog zniknął bez archiwum → ostrzeżenie w `list`, bez zgadywania |
| Import tasków | przy `Approved` i przy każdej zmianie `tasks.md`: linia `- [ ] T-NN: [TAG] tytuł — REQ-…/AC-… — pliki: … — weryfikacja: … (po T-XX)` → rekord z `refs` (REQ/AC, pliki, weryfikacja, zależności). Dopasowanie po `T-NN`; task usunięty z pliku → porzucone z powodem. Starszy format bez `T-NN` → klucz `#<n>` wg kolejności |
| Paczka | składana przy odczycie z aktualnych plików. Zawsze: linie tasków, wskazane bloki REQ z AC z delty, `INVARIANTS`, z `design.md`: Overview, Affected Files, Decyzje techniczne, Odstępstwa od zasad, Testing Strategy. `[BE]`/`[FE]`: + API / Interface Contract, Error Handling. `[DB]`: + Database Changes. `— design: <sekcja>` w linii taska dokłada sekcję. `--stats`: paczka vs pliki, które zastępuje |
| Polecenia | `regent task add`, `take`, `handoff <właściciel> --reason`, `done --reason` (dla `T-NN`: `--commit`, `--tests`), `drop --reason`, `list [--all]` (sekcja Uwaga: utknięte, bez artefaktów, czas ostatniego sync), `show` (historia), `sync`, `next <zmiana> [--layer BE\|FE\|DB]` (gotowe taski: niezrobione, zależności zamknięte, z paczką), `packet <zmiana> <T-NN>…`; `--json` przy odczycie |
| Wywołanie ze skilli i hooków | `scripts/regent.sh` szuka zbudowanego CLI (`tools/regent/dist/cli.js` w pluginie albo `regent` w PATH); brak → kod 3 i skill pracuje jak dziś, na plikach |
| Hooki | `SessionStart` i `Stop` w projektach z `ai/docs/` wołają `sync` z `session_id` i `transcript_path`. Nic na stdout (stdout `SessionStart` trafia do kontekstu), zawsze kod 0, błąd do logu obok bazy |
| Skill `apply` | z CLI: wybór tasków przez `next`, subagent dostaje w prompcie paczkę zamiast listy plików do przeczytania (dalej czyta `technology.md`, `code-style.md` i pliki kodu), `take` przed delegacją, `done --commit --tests` zamiast ręcznej edycji `tasks.md`. Gdy paczki brakuje, subagent doczytuje plik i zgłasza `BRAK W PACZCE: …` — sygnał do poprawy reguły paczki |

## Taski

- [x] T1: pakiet `tools/regent/` (Node 24, TS, Vitest, bin `regent`), warstwa bazy w jednym pliku
  (ścieżka, WAL, `busy_timeout`, migracje przez `user_version`, wyciszone `ExperimentalWarning`
  z `node:sqlite`); testy na bazie w katalogu tymczasowym
- [ ] T2: model zadań — dwa poziomy, stany, tabela przejść, właściciel, log tylko do dopisywania,
  powód przy zamknięciu; testy dozwolonych i odrzuconych przejść
- [ ] T3: polecenia `add`, `take`, `handoff`, `done`, `drop`, `list`, `show` (tekst i `--json`; kody:
  0 — ok, 1 — odrzucone przejście, 2 — błędne użycie); testy
- [ ] T4: utknięcie przy odczycie i sekcja Uwaga w `list`; testy z podmienionym zegarem
- [ ] T5: `sync` poziomu zmiany — mapa SDD → stan, sygnatura plików, ostrzeżenie o zniknięciu;
  w skillu `archive` przy `--abandon` zapis `Status: Abandoned` w `proposal.md`; testy na
  fixture'ach `ai/changes/`
- [ ] T6: import tasków z `tasks.md` (grupy, `T-NN`, tag, REQ/AC, pliki, weryfikacja, zależności,
  starszy format), ponowny import po zmianie pliku, wygrana pliku przy ręcznej zmianie; testy
- [ ] T7: `next` i `packet` (gotowość wg zależności, reguły paczki, `--stats`), `done --commit
  --tests` przepisuje linię taska w `tasks.md` w formacie z `apply` Krok 4c; testy na fixture'ach
- [ ] T8: `scripts/regent.sh` + hooki `SessionStart` i `Stop` (`scripts/hooks/task-sync.sh`, zakres
  `ai/docs/`, cisza na stdout, kod 0, log błędów, brak CLI → cisza); testy w bashu 3.2 i z PATH
- [ ] T9: skill `apply` — ścieżka z CLI (Krok 1, 3, 4a, 4c) i bez CLI (jak dziś), `BRAK W PACZCE`
  w raporcie subagenta; reguły w `framework-lint.sh` (skill wołający `regent.sh` ma `Bash`)
- [ ] T10: dokumentacja — `docs/tasks.md` (instalacja jak `regent-watch`, polecenia, mapa stanów,
  paczka, utknięcie), wpis w README; bramka: `framework-lint.sh`, `claude plugin validate .`,
  `npm test` i `npm run typecheck` w `tools/regent/`
- [ ] T11: smoke bez tokenów — projekt testowy: zmiana przechodzi Draft → Approved → taski →
  weryfikacja → archiwum przez edycje plików i JSON hooków, każdy krok widać w `show`; porzucenie
  przez `Status: Abandoned`; `packet --stats` na zarchiwizowanej zmianie z projektu prywatnego
  (tylko odczyt, wynik poza repo); pomiar czasu hooka `Stop`
- [ ] T12: merge `feat/task-core` → `main`, push; start tygodnia sprawdzenia (data w Przebiegu)

## Ryzyka

- **Paczka bez potrzebnego kontekstu** — agent zgaduje, a to dryf. Reguła paczki jest
  zachowawcza (decyzje, odstępstwa i invarianty zawsze), `design:` w tasku dokłada sekcję,
  a `BRAK W PACZCE` w raportach pokazuje, czego brakuje.
- **`node:sqlite` jest eksperymentalne w Node 24** — cała baza za jednym modułem, podmiana
  (np. na `better-sqlite3`) dotyka jednego pliku.
- **Koszt hooka `Stop` przy każdej turze** — start Node to dziesiątki milisekund. Pomiar w T11;
  gdy za drogo, sync tylko przy zmianie mtime `ai/changes/` (sprawdzane w bashu przed startem Node).
- **Lustro `tasks.md`** — skrypt przepisuje tylko linię taska, który zmienił stan; reszta pliku
  bez zmian. Równoległa ręczna edycja wygrywa przy następnym sync.
- **Nowa maszyna bez zbudowanego CLI** — `regent.sh` zwraca kod 3, skill pracuje na plikach,
  hook milczy. `list` pokazuje czas ostatniego sync, a brak bazy to komunikat, nie pusta lista.

## Poza zakresem

Seaty i wstrzykiwanie paczki po starcie i `/clear` (etap 2), priorytety, limit i wstrzymanie do
resetu (etap 3), proces demona (etap 3), worktree i praca bez nadzoru (etap 4), TUI
w `regent-watch`, push i connector MCP (etap 5), paczki dla `verify` i `archive` (recenzent
potrzebuje całych AC i diffu), budzenie agentów przez tmux, inbox/outbox, workflow specs z OpenRig.

## Sprawdzenie etapu

Tydzień realnej pracy z pluginem na jednej maszynie:
- każda zmiana z `ai/changes/` z tego tygodnia ma zadanie, a każde zamknięte zadanie ma powód;
- żadne zadanie w toku nie wisi bez właściciela ani bez wyjaśnionego utknięcia;
- tokeny wejścia pierwszej tury subagenta `apply` są niższe niż przed zmianą (punkt odniesienia:
  transkrypty `apply` z projektów prywatnych sprzed zmiany), a raporty `BRAK W PACZCE` nie
  powtarzają się dla tej samej sekcji.
