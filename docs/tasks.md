# Zadania Regenta — `regent task`

Rdzeń zadań warstwy runtime Regenta (etap 1). Dwie rzeczy:

1. **Żadne zadanie nie ginie bez śladu.** Każde ma jednego właściciela i log przejść, a kończy się
   jawnym zamknięciem z powodem albo przekazaniem. Zmiany SDD z `ai/changes/` i ich taski zakładają
   się i przesuwają same: stan liczy skrypt z artefaktów, nie model.
2. **Agent dostaje jedno zadanie, nie całe pliki.** `/regent:apply` pobiera gotowe taski z bazy
   i przekazuje subagentowi paczkę: linie tasków, ich AC i potrzebne sekcje designu — zamiast
   całych `tasks.md`, `design.md` i delty.

Decyzje i zakres: [plans/task-core.md](plans/task-core.md).

## Zanim zaczniesz

- **Bez procesu w tle.** Stan zmienia CLI i sync wołany przez hooki `SessionStart` i `Stop`;
  utknięcie liczy się przy odczycie. Wszystko przechodzi przez jeden moduł, który zmienia bazę.
- **Opcjonalne.** Bez zbudowanego CLI plugin działa jak dotąd: `scripts/regent.sh` zwraca kod 3,
  hook milczy, a `/regent:apply` pracuje na plikach.
- **Node 24.** Baza to wbudowane `node:sqlite` (bez natywnej kompilacji). W Node 24 moduł jest
  eksperymentalny — CLI wycisza tylko jego `ExperimentalWarning`.

## Instalacja

Pakiet: [`tools/regent/`](../tools/regent/) (Node 24, TypeScript) — poza komponentami pluginu,
instalowany osobno, jak `regent-watch`:

```bash
cd <klon repo regent>/tools/regent
npm install        # zależności + build do dist/
npm link           # opcjonalnie: polecenie regent w PATH
```

Bez `npm link` uruchamiasz `node <klon repo regent>/tools/regent/dist/cli.js`. Plugin znajduje CLI
sam: `scripts/regent.sh` szuka najpierw `${CLAUDE_PLUGIN_ROOT}/tools/regent/dist/cli.js`, potem
`regent` w PATH. `dist/` nie jest w gicie — po `git pull` ze zmianami w `tools/regent/` zbuduj
ponownie (`npm install` albo `npm run build`).

## Polecenia

Zakres to zawsze projekt z bieżącego katalogu: korzeń gita (pierwszy katalog z `.git` w górę),
a poza repo — sam katalog. `<id>` to numer zadania z `list` (`7` albo `#7`), `<zmiana>` — nazwa
katalogu w `ai/changes/` (także z prefiksem `sdd:`).

| Polecenie | Działanie |
|---|---|
| `regent task add <tytuł> [--owner me\|agent]` | ręczne zadanie, oczekuje |
| `regent task take <id>` | biorę: w toku, właścicielem zostaje biorący |
| `regent task handoff <id> <me\|agent> [--reason …]` | do `me` — czeka na Ciebie, do `agent` — przekazane, aż ktoś je weźmie |
| `regent task done <id> --reason …` | zakończone |
| `regent task done <id> --commit <hash> [--tests <mapa>]` | task zmiany (`T-NN`): zakończone, a jego linia w `tasks.md` dostaje `[x]` i ślad z `apply` Krok 4c |
| `regent task drop <id> --reason …` | porzucone |
| `regent task list [--all] [--stuck <min>]` | otwarte zadania z sekcją Uwaga i czasem ostatniego sync; `--all` dokłada zamknięte z powodem |
| `regent task show <id>` | zadanie i historia przejść |
| `regent task sync` | zmiany SDD i ich taski z artefaktów `ai/changes/` |
| `regent task next <zmiana> [--layer BE\|FE\|DB]` | gotowe taski zmiany: niezrobione, z zamkniętymi zależnościami |
| `regent task packet <zmiana> <T-NN>… [--stats]` | paczka dla agenta; `--stats` — jej rozmiar wobec plików, które zastępuje |

- `--json` — wynik jako JSON (każde polecenie); `next --json` daje paczkę każdego gotowego taska.
- **Wykonawca** — w sesji Claude Code (zmienna `CLAUDECODE`) `agent`, poza nią `me`. Tak `take`
  ustawia właściciela i tak `add` zakłada zadanie bez `--owner`. `take` w sesji zapisuje też jej ID.
- **Kody wyjścia:** 0 — ok, 1 — odrzucone przejście (z listą możliwych), 2 — błędne użycie (np. brak
  `--reason`), 3 — brak CLI (tylko `regent.sh`), 4 — błąd bazy lub środowiska.
- `list` i `show` nie zakładają bazy; przed pierwszym zapisem `list` mówi „Brak bazy zadań”.

Przykład na syntetycznym projekcie z testów (`tools/regent/test/fixtures/`):

```
$ regent task list
~/projekty/notatki — otwarte: 12

  #1     czeka na Ciebie  me     sdd:draft-search
  #2     w toku           agent  sdd:legacy-export
    #4   oczekuje         agent  2. Eksport do Markdown
    #5   oczekuje         agent  3. Przycisk eksportu w UI
    #6   oczekuje         agent  4. Opis eksportu w pomocy
  #7     w toku           agent  sdd:note-tags
    #9   oczekuje         agent  T-02 [BE] Serwis tagów
    #10  oczekuje         agent  T-03 [BE] Filtr GET /notes?tag
    #11  oczekuje         agent  T-04 [FE] Tagi na liście notatek
    #12  oczekuje         agent  T-05 Indeks tagów
    #13  oczekuje         agent  T-06 [BE] E2E tagów
  #14    oczekuje         me     przejrzeć logi deployu

Ostatni sync: 2026-09-29 17:40 (cli)

$ regent task drop 3 --reason test
regent: #3 jest „zakończone” — drop niedozwolone. Możliwe: nic — stan końcowy.
```

Wcięte wiersze to taski zmiany; `2.` to klucz starszego formatu `tasks.md` (bez `T-NN`).

## Stany i przejścia

| Stan | Znaczenie |
|---|---|
| oczekuje | do wzięcia |
| w toku | ktoś pracuje (`take`); zadanie ma właściciela i zwykle sesję |
| czeka na Ciebie | przekazane do `me`: decyzja, akceptacja, przegląd |
| przekazane | przekazane agentowi, jeszcze niewzięte |
| zablokowane | jest w modelu, ale w etapie 1 nic go nie ustawia (brak polecenia `block`) |
| zakończone | zamknięte z powodem |
| porzucone | zamknięte z powodem |

- Tabela dozwolonych przejść jest w [`tools/regent/src/model.ts`](../tools/regent/src/model.ts).
  Przekazanego i zablokowanego nie da się zakończyć bez wzięcia; stan końcowy nie ma wyjścia przez
  CLI. Ponownie otwiera go tylko sync — gdy plik cofa zamknięcie (odznaczony task, zmiana wyjęta
  z archiwum) — i zawsze z powodem.
- Log przejść (`transitions`) jest tylko do dopisywania: triggery w bazie blokują jego UPDATE
  i DELETE oraz usuwanie zadań. Każde przejście zapisuje wykonawcę i źródło (`me/cli`, `sync/hook`).
- „Wstrzymane do resetu” dochodzi w etapie 3, razem z limitem.

## Zmiany SDD i ich taski

`sync` (ręcznie, z hooków i przed każdym `next`) czyta `ai/changes/`. Zmiana to zadanie-rodzic
`sdd:<zmiana>`; stan aktywnych zmian liczy `sdd-check.sh status` ([sdd-check.md](sdd-check.md)),
a archiwum sync czyta sam.

| Artefakty | Stan zmiany |
|---|---|
| `Status: Draft` | czeka na Ciebie |
| `Approved`, nic nie zrobione | oczekuje |
| `Approved`, część tasków zrobiona | w toku |
| wszystkie taski, bez `verification.md` | oczekuje (do weryfikacji) |
| werdykt `BLOCK` albo `FAIL` | w toku |
| werdykt `PASS` albo `WARN` | czeka na Ciebie (do archiwum) |
| `Status: Rejected` albo `Abandoned` | porzucone |
| w `ai/changes/archive/` | zakończone; z `Status: Abandoned` w `proposal.md` — porzucone |
| katalog zniknął bez archiwum | bez zmiany stanu, ostrzeżenie w Uwadze `list` |

Inny `Status` albo brak `proposal.md` → czeka na Ciebie; nieznany werdykt → oczekuje. Właściciel
wynika ze stanu: czeka na Ciebie → `me`, oczekuje i w toku → `agent`; zamknięcie go nie zmienia.
Archiwum zamyka tylko zmiany znane bazie — historii sprzed pierwszego sync nie odtwarza. `/regent:archive --abandon` zapisuje
`Status: Abandoned` w `proposal.md`, więc porzucenie jest widoczne także w archiwum.

**Taski.** Po `Approved` sync importuje `tasks.md` — przy pierwszym razie i przy każdej zmianie
pliku. Linia w formacie z `/regent:propose`:

```
- [ ] T-03: [BE] Filtr GET /notes?tag — REQ-005/AC-1 — pliki: src/notes/controller.ts — weryfikacja: test API REQ-005/AC-1 (po T-02)
```

daje rekord z tagiem, REQ/AC, plikami, weryfikacją i zależnościami (`po T-XX`); opcjonalne
`— design: <sekcja>` dokłada sekcję do paczki. Dopasowanie po `T-NN`, starszy format bez `T-NN`
dostaje klucz `#<n>` wg kolejności. Task usunięty z pliku → porzucone z powodem.

**Lustro `tasks.md`.** Po `Approved` o stanie tasków decyduje baza, a `done --commit --tests`
przepisuje wyłącznie linię tego taska: `[x]` i ślad `✅ (commit: … · testy: …)` jak w `apply`
Krok 4c. Reszta pliku zostaje bez zmian. Ręczna zmiana linii wygrywa: sync widzi inną sygnaturę
linii niż w bazie i przyjmuje stan z pliku. Odwrotnie — zmiana stanu przez CLI zostaje, dopóki
pliki się nie zmienią, a różnicę pokazuje Uwaga jako „rozjazd z artefaktami”.

## Paczka

`regent task packet` składa paczkę przy odczycie, z aktualnych plików zmiany (aktywnej albo
z archiwum):

| Tag taska | Zawartość |
|---|---|
| każdy | linie tasków; ich bloki REQ z delty w całości (Given/When/Then, wszystkie AC); `INVARIANTS` ze wszystkich plików delty; z `design.md`: Overview, Affected Files, Decyzje techniczne, Odstępstwa od zasad, Testing Strategy |
| `[BE]`, `[FE]`, bez tagu | + API / Interface Contract, Error Handling |
| `[DB]` | + Database Changes |
| `— design: <sekcja>` w linii | + ta sekcja |

Sekcje designu paczka znajduje po nazwie z szablonu (początek nagłówka, bez wielkości liter), więc
sekcja pod inną nazwą — np. „Kontrakt API↔UI” zamiast „API / Interface Contract” — do paczki nie
trafia. Komentarze HTML (instrukcje szablonów) paczka pomija. Sekcje i REQ, których pliki nie mają,
są wypisane na końcu („Brak w design.md: …”, „Brak w delcie: …”). `--stats` porównuje rozmiar paczki
z plikami, które zastępuje; tokeny szacuje jako bajty / 3,5:

```
$ regent task packet note-tags T-02 --stats
Paczka note-tags T-02: 2240 B (~640 tok.)
Pliki, które zastępuje (tasks.md, design.md, specs/notes.md): 4819 B (~1377 tok.)
Paczka to 46% plików.
```

W `/regent:apply` z CLI subagent dostaje paczkę w prompcie i nie czyta `tasks.md`, `design.md` ani
delty (dalej czyta `technology.md`, `code-style.md` i pliki kodu). Gdy czegoś mu brakuje, doczytuje
plik i zgłasza w raporcie `BRAK W PACZCE: <plik> › <sekcja> — <po co>`. Powtarzający się brak tej
samej sekcji to sygnał do poprawy reguły paczki.

## Utknięcie i Uwaga

Zadanie w toku jest **utknięte**, gdy transkrypt jego sesji nie zmienił się od progu (domyślnie
30 min, `list --stuck <min>`) albo gdy nie ma sesji ani transkryptu dłużej niż próg od wzięcia.
Czas liczy się od późniejszego z: ostatniego zapisu transkryptu i wzięcia. Zmiana SDD w toku bez
sesji nie utyka — jej stan wynika z artefaktów, pracę niosą taski.

Sekcja **Uwaga** w `list` pokazuje: utknięte, zmiany bez artefaktów (katalog zniknął bez archiwum)
i rozjazd stanu z artefaktami. Pod listą stoi czas ostatniego sync; przed pierwszym — „nigdy”.

## Hooki i `/regent:apply`

- **Hook `SessionStart` i `Stop`** ([`scripts/hooks/task-sync.sh`](../scripts/hooks/task-sync.sh)):
  w projekcie z `ai/docs/` woła `regent task sync` z `session_id` i `transcript_path` sesji — tak
  zadania w toku dostają transkrypt do liczenia utknięcia. Poza projektem SDD Node nie startuje.
  Nic na stdout (stdout `SessionStart` trafia do kontekstu), zawsze kod 0; błąd CLI to jedna linia
  w `hook.log` obok bazy, brak CLI — cisza.
- **`/regent:apply`** wybiera ścieżkę raz, na początku: `regent.sh task next <zmiana> --json`
  z kodem 0 → ścieżka z CLI (`next` → `take` → paczka w prompcie → `done --commit --tests`),
  kod 3 albo inny błąd → dotychczasowa praca na plikach. Routing po tagach, budżet subagentów
  i commit per task są w obu ścieżkach te same.

## Baza i prywatność

Jedna baza na maszynę: `${XDG_STATE_HOME:-~/.local/state}/regent/regent.db` (`REGENT_DB` ją
nadpisuje — testy, izolacja), z kolumną `project`. Tryb WAL i `busy_timeout` dla równoległych
hooków kilku sesji, wersja schematu w `user_version`. Baza nie leży w projekcie, bo `ai/` bywa
w gicie i trafiałaby do commitów.

Baza trzyma ścieżki projektów, tytuły tasków i ścieżki transkryptów — na maszynie mieszanej także
z projektów z pracy. Zostaje lokalnie: CLI niczego nie wysyła, a bazy i `hook.log` nie kopiuj do
repo ani na inne maszyny.

## Ograniczenia

- `drop` taska zmiany nie zmienia `tasks.md`: linia zostaje `[ ]`, więc `sdd-check.sh status`
  liczy task jako niezrobiony i zmiana nie dojdzie do „wszystkie taski”. Usuń linię albo odhacz ją
  ręcznie.
- Koszt hooka `Stop` to głównie start Node (ok. 120 ms): ok. 180 ms bez zmian w plikach, ok. 210 ms
  po zmianie `tasks.md` (dochodzi `sdd-check.sh`), ok. 15 ms poza projektem SDD.
- Paczki są tylko dla `apply`; `verify` i `archive` czytają całe pliki (recenzent potrzebuje całych
  AC i diffu).
- Seaty, wstrzykiwanie paczki po `/clear`, priorytety, limit i proces w tle — kolejne etapy planu.
