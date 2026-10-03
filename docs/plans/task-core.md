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
- [x] T2: model zadań — dwa poziomy, stany, tabela przejść, właściciel, log tylko do dopisywania,
  powód przy zamknięciu; testy dozwolonych i odrzuconych przejść
- [x] T3: polecenia `add`, `take`, `handoff`, `done`, `drop`, `list`, `show` (tekst i `--json`; kody:
  0 — ok, 1 — odrzucone przejście, 2 — błędne użycie); testy
- [x] T4: utknięcie przy odczycie i sekcja Uwaga w `list`; testy z podmienionym zegarem
- [x] T5: `sync` poziomu zmiany — mapa SDD → stan, sygnatura plików, ostrzeżenie o zniknięciu;
  w skillu `archive` przy `--abandon` zapis `Status: Abandoned` w `proposal.md`; testy na
  fixture'ach `ai/changes/`
- [x] T6: import tasków z `tasks.md` (grupy, `T-NN`, tag, REQ/AC, pliki, weryfikacja, zależności,
  starszy format), ponowny import po zmianie pliku, wygrana pliku przy ręcznej zmianie; testy
- [x] T7: `next` i `packet` (gotowość wg zależności, reguły paczki, `--stats`), `done --commit
  --tests` przepisuje linię taska w `tasks.md` w formacie z `apply` Krok 4c; testy na fixture'ach
- [x] T8: `scripts/regent.sh` + hooki `SessionStart` i `Stop` (`scripts/hooks/task-sync.sh`, zakres
  `ai/docs/`, cisza na stdout, kod 0, log błędów, brak CLI → cisza); testy w bashu 3.2 i z PATH
- [x] T9: skill `apply` — ścieżka z CLI (Krok 1, 3, 4a, 4c) i bez CLI (jak dziś), `BRAK W PACZCE`
  w raporcie subagenta; reguły w `framework-lint.sh` (skill wołający `regent.sh` ma `Bash`)
- [x] T10: dokumentacja — `docs/tasks.md` (instalacja jak `regent-watch`, polecenia, mapa stanów,
  paczka, utknięcie), wpis w README; bramka: `framework-lint.sh`, `claude plugin validate .`,
  `npm test` i `npm run typecheck` w `tools/regent/`
- [x] T11: smoke bez tokenów — projekt testowy: zmiana przechodzi Draft → Approved → taski →
  weryfikacja → archiwum przez edycje plików i JSON hooków, każdy krok widać w `show`; porzucenie
  przez `Status: Abandoned`; `packet --stats` na zarchiwizowanej zmianie z projektu prywatnego
  (tylko odczyt, wynik poza repo); pomiar czasu hooka `Stop`
- [x] T12: merge `feat/task-core` → `main`, push; start tygodnia sprawdzenia (data w Przebiegu)

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
  transkrypty `apply` z projektów prywatnych sprzed zmiany), suma i największy kontekst całego
  agenta nie rosną przez kontynuacje (`SendMessage`), a raporty `BRAK W PACZCE` nie powtarzają się
  dla tej samej sekcji. Wszystko liczy `regent-apply-tokens` (`docs/tasks.md`, plany
  `docs/plans/task-core-check.md`, `docs/plans/apply-tokens-detekcja.md`
  i `docs/plans/apply-kontynuacje.md`). Transkrypty sesji usuniętych w aplikacji desktop znikają
  z pomiaru — sesji `apply` nie usuwaj do końca tygodnia.

## Przebieg (2026-09-29) — sesja 1

- T1–T4 na `feat/task-core`: 47 testów Vitest zielonych, `npm run typecheck` czysty. Smoke
  zbudowanego CLI w osobnym procesie: `add` → `take` → `handoff me` → `done --reason`, kod 1
  z listą możliwych, kod 2 bez `--reason`, Uwaga z zadaniem wziętym 45 min temu; bez
  `ExperimentalWarning` (test wyciszenia uruchamia `src/db.ts` w osobnym procesie).
- Rozstrzygnięte w sesji (pytanie do Ciebie): zadanie w toku bez sesji jest utknięte dopiero po
  progu od wzięcia (`claimed_at`), nie od razu; `list --all` dokłada zamknięte z powodem, zakres
  to zawsze bieżący projekt.
- Doprecyzowania w kodzie:
  - tabela przejść (`src/model.ts`): stany końcowe bez wyjścia; przekazane i zablokowane nie kończą
    się bez wzięcia; przejścia bez polecenia CLI (w toku → oczekuje, → zablokowane) zostają dla
    sync. Jeśli T6 (wygrana pliku przy ręcznym odznaczeniu) potrzebuje wyjścia ze stanu
    końcowego — rozszerzyć tabelę tam;
  - „wstrzymane do resetu” poza listą stanów do etapu 3 (stan to tekst, bez migracji);
    „zablokowane” jest w modelu, ale bez polecenia CLI — plan nie wymienia `block`;
  - wykonawca: `CLAUDECODE` w środowisku → `agent`, inaczej `me`; `take` ustawia właściciela na
    wykonawcę, `add --owner` nadpisuje. Hooki dziedziczą `CLAUDECODE`, więc sync (T5, T8) podaje
    własny `actor`/`source`;
  - `take` zapisuje `session_id` z `CLAUDE_CODE_SESSION_ID` (jest w środowisku Bash sesji Claude
    Code, nieudokumentowana). `transcript_path` dopisuje sync z hooka (T8), łącząc po `session_id`;
  - utknięcie liczy się od późniejszego z: zapisu transkryptu i wzięcia; brak pliku transkryptu →
    od wzięcia; ponowne wejście w „w toku” zeruje sesję poprzedniego wzięcia;
  - kod 4 — błąd bazy lub środowiska (plan zna 0/1/2, a 3 zajmuje `regent.sh`);
  - triggery w bazie blokują UPDATE i DELETE na `transitions` oraz DELETE na `tasks`;
  - `list` i `show` nie zakładają bazy; brak bazy → komunikat (`--json`: `db: null`);
  - projekt: korzeń gita szukany po `.git` w górę od `realpath(cwd)`, bez wołania `git`; poza
    repo — sam katalog.
- Pomiar: `regent task list` ~130 ms, z czego sam start Node (`node -e 0`) ~120 ms na tej
  maszynie — koszt hooka `Stop` w T11 to głównie start Node.
- Sesja 2 (T5–T7) może ruszać.

## Przebieg (2026-09-29) — sesja 2

- T5–T7 na `feat/task-core`: 91 testów Vitest zielonych (po sesji 1: 47), `npm run typecheck`
  czysty, `framework-lint.sh` bez uwag, `claude plugin validate .` tylko z ostrzeżeniem o `version`.
  Smoke zbudowanego CLI na kopii fixture'ów: `sync` zakłada 3 zmiany z taskami, `next note-tags
  --layer BE` zwraca T-02 i T-05 (T-03 i T-06 czekają na zależności), `packet note-tags T-02
  --stats` — 2240 B wobec 4819 B plików (46%), `done --commit --tests` przepisuje tylko linię T-02.
- Rozstrzygnięte w sesji (pytanie do Ciebie):
  - ponowne otwarcie w tabeli przejść: zakończone/porzucone → oczekuje. Woła je tylko sync
    i zawsze z powodem. Przekazane i zablokowane dalej nie kończą się bez wzięcia — sync zostawia
    stan, a `list` pokazuje w Uwadze rozjazd z artefaktami;
  - sync przestawia stan tylko wtedy, gdy zmienił się stan wynikający z plików (`refs.implied`
    zmiany, sygnatura linii taska). Ręczna zmiana przez CLI zostaje do następnej zmiany plików.
- Doprecyzowania w kodzie:
  - werdykt: `verification.md` ma `PASS / FAIL` (skill `verify`), plan używa słownika subagentów
    `PASS / WARN / BLOCK` — mapa przyjmuje oba (`FAIL` jak `BLOCK`). Nieznany werdykt → oczekuje
    (do weryfikacji); Status spoza Draft/Approved/Rejected albo brak `proposal.md` → czeka na
    Ciebie; `Status: Abandoned` w aktywnej zmianie → porzucone;
  - właściciel zmiany wynika ze stanu: czeka na Ciebie → `me`, oczekuje i w toku → `agent`; taski
    z importu mają `agent`;
  - archiwum: sync zamyka tylko zmiany znane bazie, historii sprzed pierwszego sync nie odtwarza.
    Katalog archiwum przetwarza raz (`refs.archive`). Przy zamknięciu zmiany robi ostatni import
    jej `tasks.md`, a otwarte taski porzuca z powodem;
  - `Status: Abandoned` z zarchiwizowanego `proposal.md` czyta odpowiednik `meta_field` w TS, bo
    `sdd-check.sh` nie ma trybu dla archiwum. Stan aktywnych zmian liczy zawsze `sdd-check.sh status`;
  - `file_sig` zmiany to hash treści `proposal.md`, `tasks.md` i `verification.md`; bez zmian
    skrypt nie jest wołany. Import tasków po zmianie hasha `tasks.md` (`refs.tasksSig`), a wygrana
    pliku liczy się per linia (`file_sig` taska);
  - migracja 2: tabela `syncs` z czasem ostatniego sync. `list` pokazuje go stopką „Ostatni sync:”
    (przed pierwszym — „nigdy”); Uwaga dostała „bez artefaktów” i „rozjazd z artefaktami”;
  - zmiana SDD w toku bez sesji nie jest utknięta — jej stan wynika z artefaktów, pracę niosą taski;
  - `sync --session-id --transcript-path --source` (pod hooki T8) dopina transkrypt do zadań w toku
    tej sesji; zagnieżdżone transakcje w `db.ts` przez SAVEPOINT;
  - parser: ID taska jak w awk (pierwsze `T-NN` w linii), NOBOX pomijany (skrypt go nie liczy),
    powtórzone `T-NN` dostaje `#<n>`. Klucz `#<n>` `list` pokazuje jako `<n>.`, żeby nie mylił się
    z id zadania;
  - `next`: gotowe to oczekuje, przekazane i w toku (przerwane), bez „czeka na Ciebie” i zablokowanych.
    Zależność, której nie ma w pliku, blokuje. `next` robi sync przed odczytem, a `--json` daje paczkę
    każdego gotowego taska;
  - paczka: bloki REQ w całości (Given/When/Then i wszystkie AC) z nazwą sekcji delty, INVARIANTS ze
    wszystkich plików delty, bez komentarzy HTML. Brakujące sekcje i REQ są wypisane na końcu paczki
    („Brak w design.md: …”, „Brak w delcie: …”). `packet` czyta też zmianę z archiwum (pod T11);
  - `done` taska zmiany: samo `--commit` wystarcza (powód `commit: <hash>`). Każde zamknięcie daje
    `[x]` w linii, ślad tylko z `--commit`/`--tests`. Kolejność: najpierw plik, potem baza — gdy zapis
    do bazy padnie, zmieniona linia wygra przy sync. Brak linii → zamknięcie tylko w bazie
    i komunikat na stderr;
  - fixture'y: `tools/regent/test/fixtures/ai/changes/` (nowy format, starszy, szkic, archiwum).
    Test zgodności z `sdd-check.sh status` obejmuje przypadki brzegowe: bloki ``` i ~~~, CRLF, `[✓]`,
    NOBOX.
- Dla sesji 3: hook woła `regent task sync --source hook --session-id … --transcript-path …`.
  `next` zwraca też taski w toku — `apply` wznawia je bez `take` (`take` na zadaniu w toku to kod 1).
- Luka do decyzji: `drop` taska zmiany nie zmienia `tasks.md`. Linia zostaje `[ ]`, więc
  `sdd-check.sh status` liczy task jako niezrobiony i zmiana nie dojdzie do „wszystkie taski”.
  Plan nie przewiduje lustra porzucenia.
- Sesja 3 (T8–T9) może ruszać.

## Przebieg (2026-09-29) — sesja 3

- T8–T9 na `feat/task-core`. `framework-lint.sh` bez uwag: składnia i testy skryptów w `/bin/bash`
  3.2.57 i w bashu z PATH 5.3.9; nowe `regent.test.sh` (9) i `task-sync.test.sh` (36) zielone
  w obu. `claude plugin validate .` tylko z ostrzeżeniem o `version`; 91 testów Vitest bez zmian.
  Pluginu nigdzie nie włączałem — hooki testowane JSON-em na stdin.
- T8:
  - `scripts/regent.sh`: `${CLAUDE_PLUGIN_ROOT}/tools/regent/dist/cli.js` przez `node`, potem
    `regent` w PATH. `dist/cli.js` bez `node` w PATH też przechodzi do PATH. Brak obu → kod 3
    i jedna linia na stderr; kod CLI przechodzi bez zmian;
  - `scripts/hooks/task-sync.sh` w `SessionStart` (po `sync-bin.sh`) i w nowym `Stop`. Korzeń
    projektu: pierwszy katalog z `.git` w górę od `cwd` z JSON-a (jak w CLI). Fallback przy braku
    `cwd`: `CLAUDE_PROJECT_DIR`, potem `PWD`. Bez `ai/docs/` w korzeniu Node nie startuje.
    Woła `task sync --source hook --session-id … --transcript-path …` (bez `session_id` — sam sync);
  - log błędów: `hook.log` w katalogu bazy (`REGENT_DB` albo `${XDG_STATE_HOME:-~/.local/state}/regent/`),
    jedna linia na błąd. Powyżej 256 KB poprzedni log przechodzi do `hook.log.1`. Kod 3 (brak CLI)
    nie trafia do logu;
  - pola JSON-a czyta `awk` na wzór `extract` z `git-guard.sh`, z parametrem klucza; test obejmuje
    JSON wielolinijkowy i escaping w ścieżce;
  - `docs/README.md`: wiersze `regent.sh` i `task-sync.sh` w tabeli Skrypty (wymaga tego lint).
    Wpis w README i `docs/tasks.md` zostają na T10 — README nadal wymienia hooki bez sync zadań.
- T9:
  - `skills/apply/SKILL.md`: wyłącznie dopisane bloki (diff: 0 linii usuniętych, 4 wstawki),
    więc ścieżka bez CLI jest słowo w słowo dzisiejsza. Wybór ścieżki raz, na początku Kroku 1:
    `regent.sh task next {nazwa} --json` — kod 0 → bloki „Z CLI” w Krokach 1, 3, 4a, 4c; kod 3
    albo inny błąd → bez CLI. Routing po tagach, budżet i commit per task bez zmian;
  - Z CLI: taski z `next` (`--tasks`/`--group` filtrują gotowe; task w toku wznawiany bez `take`),
    `take` przed delegacją, jedna paczka (`packet`) na uruchomienie agenta, a w prompcie polecenie:
    nie czytać `tasks.md`/`design.md`/`specs/*.md` i zgłaszać `BRAK W PACZCE: <plik> › <sekcja> —
    <po co>`. Braki trafiają do raportu końcowego, a `done --commit --tests` zastępuje ręczną edycję;
  - odstępstwo: `agents/dba.md` dostał jedną wstawkę — przy paczce z `apply` czyta paczkę zamiast
    trzech plików zmiany. Bez niej agent miałby w definicji polecenie sprzeczne z promptem.
    `backend-dev` i `frontend-dev` nie wymieniają plików zmiany, więc zostały bez zmian;
  - `framework-lint.sh` sekcja 2: skill wołający `regent.sh` ma `Bash` (albo wzorzec `regent.sh`)
    w `allowed-tools` — sprawdzone na chwilowo zepsutym `apply`.
- Pomiar orientacyjny (hook z prawdziwym CLI na kopii fixture'ów): `Stop` bez zmian w plikach
  ~170 ms, po zmianie `tasks.md` ~250 ms (dochodzi `sdd-check.sh`), poza projektem SDD ~10 ms.
  Właściwy pomiar i decyzja z Ryzyk — T11.
- Sesja 4 (T10–T12) może ruszać.

## Przebieg (2026-09-29) — sesja 4

- T10: `docs/tasks.md` (instalacja jak `regent-watch`, polecenia, stany, mapa SDD, import i lustro
  `tasks.md`, paczka, utknięcie, hooki, baza, ograniczenia — w tym luka `drop` z sesji 2). Wpisy
  w README: spis treści, zdanie o hookach (dotąd bez sync zadań), drzewo repo, sekcja „Zadania
  i regent task”, miejsce bazy w „Bezpieczeństwie danych”, dokumentacja rozszerzona; w `docs/README.md`
  wiersze w Przewodnikach i Narzędziach. Bramka: lint bez uwag, validate tylko `version`, 91 testów,
  typecheck czysty.
- T11 smoke bez tokenów — projekt testowy w scratchpadzie (`git init`, `ai/docs/`, baza przez
  `REGENT_DB`), po każdej edycji JSON na stdin `scripts/hooks/task-sync.sh` z `CLAUDE_PLUGIN_ROOT`
  = repo. 16 asercji stanu zielonych, 14 wywołań hooka z kodem 0 i pustym stdout, `hook.log` pusty:
  - zmiana przez cały cykl: Draft → czeka na Ciebie; Approved → oczekuje, import T-01 i T-02;
    T-01 odhaczony w pliku → zmiana w toku; T-02 przez `take` w sesji i `done --commit --tests`
    (linia dostaje `[x]` i ślad, reszta pliku bez zmian) → oczekuje (do weryfikacji); `Verdict: FAIL`
    → w toku; `PASS` → czeka na Ciebie; przeniesienie do archiwum → zakończone. `show` zmiany
    pokazuje wszystkie 7 przejść z powodami;
  - porzucenie: `Status: Abandoned` → porzucone; po przeniesieniu do archiwum stan bez zmian,
    otwarty task porzucony z powodem;
  - katalog usunięty bez archiwum → Uwaga „bez artefaktów”. Hook dopina transkrypt do taska w toku
    (`show`: sesja z transkryptem), a `list --stuck 0.02` po 2 s pokazuje go jako utknięty;
  - `packet --stats` na zarchiwizowanej zmianie z projektu prywatnego (22 taski `T-NN`: 12 `[BE]`,
    10 bez tagu), tylko odczyt: baza w scratchpadzie, `git status` projektu czysty przed i po. Paczka
    na task: mediana ~3,4 tys. tokenów (3,3–5,2 tys.) wobec ~15 tys. w trzech plikach, czyli 22%;
  - braki w paczce: każda z 22 paczek zgłasza dwa — „Odstępstwa od zasad” (sekcji nie ma w żadnym
    z 29 designów tego projektu; szablon dostał ją później) i „API / Interface Contract”. Kontrakt ma
    nazwę z szablonu w 13 designach, a w 5 — „Kontrakt API↔UI”, bo tak nazywa go checklista
    w `agents/architect.md`. Kandydat do poprawki (alias w regule paczki albo jedna nazwa w agencie),
    do decyzji po tygodniu sprawdzenia: tam wyjdzie w `BRAK W PACZCE`;
  - czas hooka `Stop` (15 uruchomień, mediana): projekt testowy bez zmian 177 ms, po zmianie
    `tasks.md` 208 ms, poza projektem SDD 14 ms; projekt prywatny: pierwszy sync 257 ms, bez zmian
    182 ms. Nie jest wyraźnie ponad 200 ms, więc warunek mtime z Ryzyk zostaje niewdrożony; ~120 ms
    z tego to sam start Node;
  - punkt odniesienia (transkrypty sprzed zmiany): 28 subagentów implementujących z promptem
    o `ai/changes/` (20 `frontend-dev`, 6 `backend-dev`, 2 `dba`) z dwóch projektów prywatnych
    (20 i 8), 2026-09-14…26. Definicja: tura jak w `tools/watch/src/parse/` (do `end_turn` albo
    `turn_duration`), tokeny wejścia = wejście + zapis i odczyt cache z `usageFromRecord`,
    deduplikacja po `message.id`. Mediany: **suma tokenów wejścia pierwszej tury ~5,0 mln**
    (51 wywołań API); kontekst pierwszego wywołania ~18 tys., przy pierwszej edycji ~80 tys.,
    maksymalny ~125 tys.; wyniki `Read` plików zmiany (`tasks.md`, `design.md`, `specs/`) ~22 tys.
    tokenów (bajty / 3,5) — czytało je 28 z 28. W tygodniu sprawdzenia porównać tę samą sumę,
    a pomocniczo kontekst przy pierwszej edycji i odczyt plików zmiany (z paczką powinien spaść
    prawie do zera). Skrypt pomiaru został w scratchpadzie sesji, poza repo.
- Odstępstwa: w `docs/tasks.md` dodałem akapit o dopasowaniu sekcji designu po nazwie (fakt z T11).
- T12: fast-forward `feat/task-core` → `main` po zielonej bramce, push. **Tydzień sprawdzenia
  etapu 1: od 2026-09-29 do 2026-10-06** — kryteria w sekcji „Sprawdzenie etapu”, punkt odniesienia
  powyżej. W `.claude/rules/project.md` „Następny krok” → tydzień sprawdzenia, potem plan etapu 2.
- Etap 1 zamknięty w repo. Do decyzji po tygodniu sprawdzenia: nazwa sekcji kontraktu (T11), lustro
  `drop` w `tasks.md` (sesja 2), warunek mtime dla hooka `Stop`, jeśli koszt zacznie przeszkadzać.
