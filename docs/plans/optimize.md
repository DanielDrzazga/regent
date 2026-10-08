# Plan: optimize

> Pętla optymalizacji skilli Regenta na wzór `karpathy/autoresearch`, jako skill `/regent:optimize`.
> Osobny tor przed planem etapu 2: dokłada `evals/`, skrypt i skill, rdzenia zadań nie zmienia.
> Lekka ścieżka: gałąź, ten plan, bramka i smoke.
>
> Decyzje użytkownika z 2026-10-08:
> - pilot to `apply`;
> - pętla jest skillem w pluginie;
> - działa sama, z limitem;
> - miejsce w planie produktu wybiera sesja (do potwierdzenia z planem produktu, bez przenoszenia
>   jego treści).

## Cel

1. **Szybciej i taniej bez straty jakości.** Pętla zmienia jeden plik promptu i uruchamia stałą ocenę
   o stałym budżecie. Lepszy wynik zostaje jako commit, gorszy cofa `git reset`. Wyniki trafiają do
   pliku tsv, a pętla działa bez nadzoru aż do limitu. Pilot `apply` wybrany, bo to najdroższy skill:
   punkt odniesienia z etapu 1 (`docs/plans/task-core.md`, Przebieg sesji 4) to ~5 mln tokenów
   wejścia pierwszej tury w 28 subagentach.
2. **Prosto dla użytkownika.** Jedna komenda `/regent:optimize <skill>` z domyślnymi ustawieniami.
   Na starcie jedno pytanie, na końcu raport. Merge do `main` przechodzi zwykłą ścieżką.

## Autoresearch → Regent

| autoresearch | Regent |
|---|---|
| `train.py`, jedyny edytowany plik | **kandydat**: `skills/<skill>/SKILL.md` (opcjonalnie `--agent <nazwa>` → `agents/<nazwa>.md`). Jeden plik na eksperyment |
| `prepare.py` + `evaluate_bpb`, zamrożone | **wyrocznia**: `evals/<skill>/` (przypadki `claude plugin eval` + projekt testowy) i `scripts/optimize-score.sh`. Pętla ich nie zmienia |
| `program.md`, edytowany przez człowieka | `skills/optimize/SKILL.md`. Heurystyki promptów są w jednym źródle: `CONTRIBUTING.md` → „Jak pisać prompty” |
| stałe 5 minut na eksperyment | stały budżet przypadku: `max_turns`, `timeout_seconds`, `runs`, `--max-cost-usd` |
| `val_bpb` | bramka jakości + koszt ważony cennikiem, czas pomocniczo (sekcja Metryka) |
| `results.tsv` poza gitem | `evals/results/optimize-<skill>-<tag>.tsv` w `.gitignore` |
| gałąź `autoresearch/<tag>` | gałąź `perf/optimize-<skill>-<data>` w **osobnym worktree** |
| crash → log i dalej | lint albo eval padł → `crash`, cofnięcie, następny pomysł |
| „simpler is better” | przy remisie w granicach szumu wygrywa krótszy prompt. Usunięcie tekstu bez straty jakości to wygrana |
| NEVER STOP | działa do limitu eksperymentów lub kosztu. W trakcie o nic nie pyta |

Worktree jest obowiązkowy. Plugin działa na żywo z klonu (alias `--plugin-dir`), więc eksperymenty
w klonie zmieniałyby `apply` we wszystkich sesjach z terminala.

## Analiza wstępna: co bierzemy, co zmieniamy

| Analiza wstępna | W planie | Dlaczego |
|---|---|---|
| Wyrocznia zamrożona, kandydat to jeden plik, pętla na git + tsv | bierzemy | rdzeń autoresearch |
| `/regent:optimize <cel>` | bierzemy nazwę | jedna komenda dla użytkownika |
| Metryka A: `(in + 4×out) / jakość` | **bramka jakości + koszt ważony cennikiem** | Iloraz pozwala oddać jakość za tokeny (0,8 jakości przy −30% tokenów wygrywa), a nieudany task kosztuje więcej niż oszczędność. „4×” pomija cache, a w `apply` dominuje odczyt cache (kontekst rośnie z ~18 do ~125 tys.). Cennik z `tools/watch/src/parse/pricing.ts` waży wejście, zapis i odczyt cache oraz wyjście tak, jak liczy się limit |
| 20–30 przypadków ocenianych przez LLM | **3 przypadki treningowe × 2 przebiegi + 4 przypadki kontrolne (holdout)**, najpierw oceny deterministyczne | Jeden przypadek `apply` to pełna sesja z subagentami: kilka minut i realny koszt. 30 przypadków razy 3 przebiegi to godziny na jeden eksperyment. Zasada repo: „Liczy skrypt, nie model”. Sędzia LLM tylko do kolejności TDD |
| `eval/run.sh` + `eval/score.py` | `claude plugin eval` + `scripts/optimize-score.sh` (bash 3.2 + jq) | Gotowy harness ma przypadki, oceniacze, przebiegi, sędziego z 3 głosami, sandbox, koszt i limit `--max-cost-usd`. Pythona nie ma w stacku repo |
| „Agent nie widzi evala, widzi tylko score” | Pętla **nie może zmienić** wyroczni (sprawdza to `git diff`). Dostaje jedną linię wyniku i nazwy oblanych oceniaczy. **Holdout widzi dopiero na końcu** | W Claude Code nie da się ukryć plików przed Read. Autoresearch też pozwala czytać `prepare.py`, zakazuje tylko zmian. Przed dopasowaniem do evala chroni holdout |
| Zacząć od promptów agentów | pilot `apply` z kandydatem `SKILL.md` i `--agent backend-dev` | Tokeny siedzą w subagentach, a `backend-dev` używa 6 skilli (apply, bugfix, hotfix, refactor, verify, dependency-update). Dlatego holdout ma przypadek `bugfix` |
| Metryka B (czas) | metryka pomocnicza | rozstrzyga przy równym koszcie |
| Metryka C | pomijamy | mnożenie sukcesów przez tokeny nie ma sensownej interpretacji |
| Warstwa 3: skrypty i `tools/` | poza pętlą autonomiczną | to kod z testami; zmiany idą zwykłą ścieżką, np. reguły paczki wg `BRAK W PACZCE` |

## Decyzje

| Decyzja | Wartość |
|---|---|
| Metryka | Liczy `optimize-score.sh` z wyniku `claude plugin eval --json`:<br>• **Q, jakość:** średni ważony wynik przypadków po przebiegach;<br>• **K, koszt:** suma median kosztu przypadków; koszt to tokeny ważone cennikiem, w praktyce `total_cost_usd`, surowe tokeny obok, do raportu;<br>• **T, czas:** suma median czasu przypadków;<br>• **P, prompt:** tokeny kandydata przy wywołaniu z `claude plugin details`; liczy się bez sesji, więc nic nie kosztuje.<br>Jedna linia: `quality=… cost=… tokens=… seconds=… prompt=… failed=<oceniacze>` |
| Reguła `keep` | Eksperyment zostaje tylko po bramce jakości: Q nie spada poniżej najlepszego zachowanego, a żaden przypadek ze 100% nie zaczyna oblewać. Do tego jeden z warunków:<br>• K spada o więcej niż próg szumu;<br>• T spada o więcej niż próg, a K nie rośnie ponad próg;<br>• K i T w szumie, a P spada (kryterium prostoty).<br>Każdy inny wynik to `discard`. Próg szumu: max(5%, rozrzut trzech przebiegów baseline) |
| Komenda | `/regent:optimize <skill> [--agent <nazwa>] [--limit N] [--budget USD] [--resume]`. Domyślnie 10 eksperymentów, limit kosztu z baseline. Na starcie jedno pytanie: zaufanie do pluginu (`--trust-plugin`) i akceptacja limitów |
| Pętla | Setup:<br>• `evals/<skill>/` musi istnieć (brak → `claude plugin eval init`);<br>• worktree z gałęzią;<br>• CLI `tools/regent` zbudowane w worktree (`dist` jest w `.gitignore`);<br>• baseline: train ×3, holdout ×1;<br>• nagłówek tsv.<br>Eksperyment:<br>• pomysł i edycja jednego pliku;<br>• `git diff --name-only` musi pokazać tylko ten plik;<br>• `framework-lint.sh` (błąd → `crash`);<br>• P;<br>• commit `perf: <opis>`;<br>• `optimize-score.sh` w tle: wynik eval do pliku, na ekran jedna linia;<br>• `keep` albo `discard` (`git reset --hard <ostatni keep>`);<br>• wiersz w tsv.<br>Koniec: holdout na najlepszym commicie wobec baseline, raport (tabela, zysk K/T/P, werdykt holdoutu, `git diff --stat`, polecenia przeglądu i merge'u). Worktree zostaje |
| Pomysły | W kolejności:<br>• skasować to, co model robi sam, i duplikaty skill↔agent;<br>• zastąpić opis pojęciem;<br>• zawęzić listę „czytaj zawsze” subagenta;<br>• skrócić format raportu (tokeny wyjścia);<br>• mniej tur (odczyty w jednej turze);<br>• rzadkie gałęzie do pliku w `skills/<skill>/` czytanego na żądanie;<br>• przy braku pomysłów: łączyć bliskie trafienia, próbować usunięć |
| Barierki | • edytuje tylko pliki kandydata;<br>• nie zmienia `evals/`, `scripts/` ani reguł `require`/`forbid` lintu (lint to twarda bramka);<br>• bez push i bez merge'a;<br>• projekty testowe syntetyczne (`.claude/rules/privacy.md`) |
| Wyrocznia `apply` | Projekt testowy `evals/apply/fixtures/notes-app/`:<br>• Node bez zależności, `node --test`, `Makefile` z `check`;<br>• minimalne `ai/docs/`;<br>• zmiany `Approved`, wzorowane na `tools/regent/test/fixtures/ai/changes/note-tags/`.<br>`scaffold_script`: kopia i `git init` z commitem, `/ai/` w `.git/info/exclude`, `REGENT_DB` w sandboksie (`execution.env`). Zgoda z Kroku 3 udzielona w prompcie z góry |
| Przypadki | **Train** (tag `train`):<br>• (a) dwa niezależne taski `[BE]`;<br>• (b) zależność `(po T-01)`: dwie rundy, nowy subagent na rundę;<br>• (c) `--tasks 2`.<br>**Holdout** (tag `holdout`):<br>• (d) `[DB]` + `[BE]`;<br>• (e) ścieżka bez CLI;<br>• (f) `/regent:bugfix` (ochrona `backend-dev`);<br>• (g) 4 taski |
| Oceniacze | Najpierw deterministyczne:<br>• delegacja do `regent:backend-dev` (`tool_used`);<br>• `SendMessage` max 0;<br>• użycie paczki (`task packet`);<br>• w `tasks.md` są `[x] T-0N` i `commit:`;<br>• testy zielone w śladzie;<br>• commit na każdy task;<br>• przy (c) nietknięty T-03.<br>Jeden sędzia LLM na kolejność Red → Green → Refactor, ze stałym modelem sędziego innym niż model agenta |

## Taski

- [x] T1: spike na jednym tanim przypadku `claude plugin eval` (`status`). Sprawdzić:
  - czy prompt `/regent:<skill>` działa przy `disable-model-invocation: true`;
  - co jest w `--json` (koszt, tokeny, czas);
  - czy `--keep-temp` zostawia transkrypty (zapas: tokeny przez `usageFromRecord`);
  - czy eval działa z wnętrza sesji Claude Code (`--trust-plugin`, w tle);
  - ścieżki `scaffold_script`;
  - nazwę narzędzia delegacji (`Task` czy `Agent`);
  - izolację `HOME` i `REGENT_DB`;
  - wersję CLI na maszynie pilota.

  Wyniki do Przebiegu.
- [x] T2: wyrocznia `apply`: projekt testowy, 7 przypadków, oceniacze; `evals/results/` w `.gitignore`
- [x] T3: `scripts/optimize-score.sh` (bash 3.2 + jq), test `scripts/tests/optimize-score.test.sh` na
  fixture JSON, wiersz w tabeli Skrypty w `docs/README.md`
- [x] T4: baseline na `main`: train ×3, holdout ×1 → próg szumu, koszt i czas eksperymentu, domyślny
  `--budget`. Do Przebiegu trafiają same liczby
- [x] T5: skill `skills/optimize/SKILL.md`:
  - frontmatter: `disable-model-invocation: true`, `argument-hint`, `allowed-tools: Read, Edit, Write,
    Grep, Glob, Bash`;
  - wiersze w `README.md` (Komendy, Która komenda kiedy) i `context/sdd-map.md`;
  - regresje w lincie, np. `require` „worktree” i „holdout”
- [x] T6: `docs/optimize.md`: jak używać i jak dopisać zestaw evali dla innego skilla; wpis w `docs/README.md`
- [x] T7: bramka (`framework-lint.sh`, `claude plugin validate .`) i smoke: `/regent:optimize apply --limit 2`
- [ ] T8 (pilot wykonany 2026-10-08, czeka merge do `main`): pilot:
  - `/regent:optimize apply --agent backend-dev`, 10–20 eksperymentów;
  - przegląd tsv i diffu, holdout zielony;
  - bramka + smoke, merge, potem `claude plugin marketplace update regent && claude plugin update regent@regent`
- [ ] T9: tydzień sprawdzenia na żywo: `regent-apply-tokens` wobec punktu odniesienia z etapu 1
- [ ] T10: kolejne skille: `propose` (oceniacz `sdd-check.sh`), `verify`, `archive`. Ten sam skill,
  nowy `evals/<skill>/`

## Ryzyka

- **Dopasowanie do evala (Goodhart):** pętla może wyciąć regułę, której eval nie sprawdza. Chronią
  przed tym holdout, reguły `require` w lincie, przegląd diffu przed merge'em i T9 na prawdziwych sesjach.
- **Szum LLM:** przebiegi się różnią. Pomaga próg z baseline, 2 przebiegi na przypadek w train i 3
  przy holdout.
- **Koszt i limity subskrypcji:** każdy eksperyment to kilka pełnych sesji. Koszt poznamy w T4,
  a ograniczają go `--max-cost-usd`, `--limit` i `-j`.
- **Rosnący kontekst sesji pętli:** wynik evala idzie do pliku, na ekran jedna linia, stan w tsv
  i w gicie, więc `--resume` zaczyna w nowej sesji.
- **Założenia o `claude plugin eval`:** rozstrzyga je T1, zanim cokolwiek zbudujemy.

## Poza zakresem

- autonomiczne zmiany kodu w `scripts/` i `tools/`;
- zestawy evali dla innych skilli przed pilotem (T10);
- publikacja pluginu;
- uruchamianie pętli na danych lub projektach z pracy etatowej.

## Sprawdzenie

- Bramka: `framework-lint.sh` → `RESULT: OK` (z testem `optimize-score.test.sh`).
  `claude plugin validate .` → jedyne ostrzeżenie: brak `version`.
- Smoke: `/regent:optimize apply --limit 2` powinien:
  - założyć worktree i gałąź;
  - dopisać do tsv baseline i 2 wiersze;
  - przy `discard` zostawić w `git log` gałęzi tylko commity `keep`;
  - zostawić klon główny na `main`, z czystym `git status`;
  - pokazać raport z holdoutem.
- Pilot: holdout zielony na najlepszym commicie, zysk K lub T ponad próg szumu.
- Na żywo (T9): w `regent-apply-tokens` niższa suma pierwszej tury i całego agenta niż w punkcie
  odniesienia etapu 1, bez nowych `BRAK W PACZCE`.

## Przebieg (2026-10-08)

- T1 spike (`claude plugin eval` 2.1.294, sesja chmurowa Linux, Node 22.22):
  - prompt `/regent:commit` rozwija skill z `disable-model-invocation: true`;
  - JSON evala ma per przebieg `score`, `turns`, `costUsd`, `durationSeconds`, oceniacze
    z wyjaśnieniem i `tracePath`. Tokenów nie ma, ale `result.modelUsage` w `out/trace.jsonl`
    obejmuje subagentów, a `--keep-temp` zostawia ślad i transkrypty;
  - eval działa z wnętrza sesji Claude Code. Bash w evalu wymaga sandboksu: na Linuksie
    `bubblewrap` i `socat`, bez nich przebieg kończy się odmową;
  - `scaffold_script`: tylko plik z katalogu przypadku (`..` odrzucone). Uruchamiany jako
    `bash <ścieżka bezwzględna>` z `cwd` i `HOME` sandboksu;
  - sandbox pozwala pisać tylko w `HOME` i `TMPDIR` sandboksu i nie ma sieci, więc projekt
    testowy jest bez zależności, a baza `regent` trafia do `HOME` sandboksu sama;
  - narzędzie delegacji w wywołaniach to `Agent` (init wypisuje `Task`); `count:N` w regexie
    oznacza dokładnie N;
  - CLI `tools/regent` buduje się i działa na Node 22.22 (`node:sqlite`).
- T2 wyrocznia `apply`:
  - `evals/apply/`: projekt `notes-app` (4 zmiany `Approved`, każda bez ERROR w `sdd-check.sh
    change`), 7 przypadków (3 `apply-train`, 4 `apply-holdout`);
  - `EVAL_REGENT_NO_CLI=1` w `regent.sh` do przypadku bez CLI, test w `regent.test.sh`.
  - Pierwszy przebieg `train-two-tasks`: 87 s, 0,385 USD, 592 tys. tokenów (526 tys. to odczyt
    cache). Dwa oceniacze okazały się błędne:
    - sędzia haiku z nieostrym kryterium („osobnymi asercjami”) oblał poprawny plik; kryteria
      przepisane na twierdzenia „PASS if … Otherwise FAIL”, nowe sprawdzone na tym pliku (3× PASS,
      stare 2× FAIL);
    - wzorzec `RED→GREEN:` nie pasował do raportu; zastąpiony sygnałem ze śladu (test oblany przed
      zielonym).
  - Ślad sesji głównej: 9 wywołań API po ~30–38 tys. kontekstu. Trzy do uniknięcia:
    - `take T-01` zamiast id z `next`;
    - powtórne `make test` po raporcie GREEN;
    - commit ze stopką `Co-Authored-By` zablokowany przez git-guard.

    To pierwsze hipotezy pętli.
- T3: `scripts/optimize-score.sh` (`run`, `score`, `decide`), 14 testów w mawk i w bashu z PATH.
  Wiersz w `docs/README.md`.
- T5–T6:
  - `skills/optimize/SKILL.md`, `docs/optimize.md`;
  - wiersze w `README.md` i `context/sdd-map.md`;
  - 3 reguły `require` w lincie (worktree, holdout, `score decide`).

  Bramka: lint OK, `claude plugin validate .` tylko `version`.
- T4 baseline (wyrocznia z `aed230a`, `apply` bez zmian):
  - train ×3: `quality=1 cost=1.223 tokens=4235058 seconds=228`;
  - koszt per przypadek: `dependency` 0,47–0,50, `tasks-filter` 0,31–0,32, `two-tasks` 0,35–0,48 USD;
  - maksimum rozrzutu z przypadków (29%) blokowałoby każdą poprawę, więc `spread` liczy się teraz
    z sumy (13%);
  - holdout ×1: `holdout-no-cli` padł, bo eval przyjmuje w `execution.env` tylko klucze `EVAL_*`;
    wyłącznik nazywa się teraz `EVAL_REGENT_NO_CLI`.
- Pętla pilota (worktree `perf/optimize-apply-2026-10-08`, kandydaci `apply` i `backend-dev`,
  próg 13%):
  - eksperyment 1 (`take` z numerycznym `id`, `take` + `packet` w jednym wywołaniu): koszt −11%,
    tokeny −17% → `discard` (w szumie);
  - eksperyment 2 (do tego commit + `done` w jednym wywołaniu, commit bez stopki):
    jakość 0,958 → `discard`. Oblał `commit-na-task`, który liczył wywołania Bash z `git commit`,
    więc karał dwa commity w jednym wywołaniu. Oceniacz zastąpiony regexem po `tasks.md` (różne
    hashe przy kolejnych taskach), a baseline zmierzony od nowa.
- Nowy baseline (wyrocznia `25aa88d`):
  - train ×3: `quality=1 cost=1.249 tokens=5134355 seconds=238 spread=0.09`;
  - holdout ×3: `quality=1 cost=1.866 seconds=378`, wszystkie 4 przypadki 1,00 (dawne oblania „commit
    na task” były w dużej części artefaktem oceniacza).
- Eksperymenty 3–8 (próg kosztu 9%):
  - 3: powtórka 2 → **keep**: koszt −9%, tokeny −49% (5,13 → 2,62 mln), czas −12%;
  - 4: jedna checklista w `backend-dev` → `discard` (koszt −4%, czas +13%, prompt −544 B);
  - 5: kroki 0–2 `apply` jednym wywołaniem Bash → `discard` (koszt −8%, czas +10%);
  - 6: subagenci rundy na pierwszym planie → `discard`: tokeny −42% i koszt −7%, ale czas +35%,
    bo subagenci szli po kolei, nie równolegle;
  - 7: krótszy raport `backend-dev` i Edit → `discard` (koszt +3%, czas +17%);
  - 8: `apply` bez powtórzonych reguł → `discard` (koszt −1%, czas +14%, prompt −670 B).
- Diagnoza po 3 (przebieg z zachowanym śladem):
  - sesja główna to 9 wywołań i 300 tys. tokenów odczytu cache, subagenci 13 wywołań i 234 tys.;
  - koszt najbardziej podbijają zapis do cache i tokeny wyjścia (~1/3 kosztu), a nie tani odczyt
    cache.
- Wniosek z 4, 5, 7 i 8: czas najlepszego wyniku (209 s) był szczęśliwym losowaniem, bo baseline i 8
  mają po 238 s. Rozrzut czasu w baseline'ie to 21%, a kosztu 9%. Wspólny próg odrzucał zmiany za czas
  mieszczący się w szumie, dlatego `optimize-score.sh` liczy teraz `tspread`, a `decide` ma osobny
  `--tnoise`. Pomiary się nie zmieniają, więc 8 rozstrzygam od nowa nową regułą, a 4 testuję ponownie
  na nowej bazie.
- Eksperymenty 9–10 (próg kosztu 9%, czasu 21%):
  - 9: 4 na nowej bazie → `discard` (koszt +5%, czas +22%);
  - 10: spójna reguła liczby subagentów w `apply` ("Budżet" i "Podział ról" mówiły co innego) →
    **keep** (prostszy prompt, koszt −6%, czas +9%).
- Holdout na najlepszym commicie (×3) wobec baseline'u (×3): **PASS**:
  - `quality=1`, wszystkie 4 przypadki 1,00 w 12 przebiegach;
  - koszt −12% (1,866 → 1,635 USD), tokeny −22% (8,78 → 6,87 mln), czas +15% (w progu).
- Smoke (T7) na przebiegu pilota:
  - worktree i gałąź `perf/optimize-apply-2026-10-08` założone;
  - tsv: baseline + 10 eksperymentów;
  - na gałęzi tylko commity `keep`;
  - klon główny na swojej gałęzi z czystym `git status`.
- Raport pilota:

  | nr | status | zmiana | koszt | tokeny | czas |
  |---|---|---|---|---|---|
  | 0 | baseline | wyrocznia `25aa88d` | 1,249 | 5,13 mln | 238 s |
  | 3 | keep | `take` z `id`, `take`+`packet` i commit+`done` razem, commit bez stopki | 1,135 | 2,62 mln | 209 s |
  | 4 | discard | jedna checklista w `backend-dev` | 1,095 | 3,05 mln | 236 s |
  | 5 | discard | kroki 0–2 jednym wywołaniem Bash | 1,045 | 2,76 mln | 229 s |
  | 6 | discard | subagenci na pierwszym planie | 1,054 | 1,53 mln | 283 s |
  | 7 | discard | krótszy raport `backend-dev`, Edit | 1,171 | 3,22 mln | 244 s |
  | 8 | keep | `apply` bez powtórzonych reguł | 1,128 | 3,08 mln | 238 s |
  | 9 | discard | 4 na nowej bazie | 1,184 | 3,52 mln | 290 s |
  | 10 | keep | spójna reguła liczby subagentów | 1,063 | 2,56 mln | 260 s |

  Wynik train wobec baseline'u: koszt −15%, tokeny −50%, czas +9% (w progu), prompt −430 B, jakość
  1,0. Zmiany obejmują tylko `skills/apply/SKILL.md` (+9/−17); żadna zmiana `backend-dev` nie
  przeszła. Koszt pilota według cennika API: ~48 USD, z czego ~25 USD to baseline'y i dwie
  poprawki wyroczni. Eksperyment kosztował ~2,2 USD i ~5 min.
- Wnioski dla kolejnych pętli:
  - najpierw przebieg pilota zestawu z przejrzeniem oblanych oceniaczy (tu dwa błędy oceniaczy
    wyszły dopiero w pętli);
  - próg czasu osobno od kosztu;
  - zyski 4–8% leżą w szumie przy 2 przebiegach; mniejsze zmiany wymagają więcej przebiegów albo
    ponownego pomiaru najlepszego commita;
  - subagenci na pierwszym planie oszczędzają tokeny kosztem czasu. To decyzja użytkownika, nie
    reguły `keep`.
- Rekomendacja poza zakresem pętli: `SubagentStart` wstrzykuje każdemu subagentowi `sdd.md`
  i `sdd-map.md` (~3,5 tys. tokenów zapisu do cache na subagenta). Mapa skilli jest zbędna agentom
  implementującym, a ich zakres zmienia wszystkie skille, więc decyzja idzie zwykłą ścieżką.
- T8: trzy commity `keep` przeniesione na gałąź sesji, bramka zielona. Merge do `main`
  i `claude plugin marketplace update regent && claude plugin update regent@regent` czekają na Twój
  przegląd. T9 (tydzień na żywo) i T10 (kolejne skille) są otwarte.
