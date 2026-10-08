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

- [ ] T1: spike na jednym tanim przypadku `claude plugin eval` (`status`). Sprawdzić:
  - czy prompt `/regent:<skill>` działa przy `disable-model-invocation: true`;
  - co jest w `--json` (koszt, tokeny, czas);
  - czy `--keep-temp` zostawia transkrypty (zapas: tokeny przez `usageFromRecord`);
  - czy eval działa z wnętrza sesji Claude Code (`--trust-plugin`, w tle);
  - ścieżki `scaffold_script`;
  - nazwę narzędzia delegacji (`Task` czy `Agent`);
  - izolację `HOME` i `REGENT_DB`;
  - wersję CLI na maszynie pilota.

  Wyniki do Przebiegu.
- [ ] T2: wyrocznia `apply`: projekt testowy, 7 przypadków, oceniacze; `evals/results/` w `.gitignore`
- [ ] T3: `scripts/optimize-score.sh` (bash 3.2 + jq), test `scripts/tests/optimize-score.test.sh` na
  fixture JSON, wiersz w tabeli Skrypty w `docs/README.md`
- [ ] T4: baseline na `main`: train ×3, holdout ×1 → próg szumu, koszt i czas eksperymentu, domyślny
  `--budget`. Do Przebiegu trafiają same liczby
- [ ] T5: skill `skills/optimize/SKILL.md`:
  - frontmatter: `disable-model-invocation: true`, `argument-hint`, `allowed-tools: Read, Edit, Write,
    Grep, Glob, Bash`;
  - wiersze w `README.md` (Komendy, Która komenda kiedy) i `context/sdd-map.md`;
  - regresje w lincie, np. `require` „worktree” i „holdout”
- [ ] T6: `docs/optimize.md`: jak używać i jak dopisać zestaw evali dla innego skilla; wpis w `docs/README.md`
- [ ] T7: bramka (`framework-lint.sh`, `claude plugin validate .`) i smoke: `/regent:optimize apply --limit 2`
- [ ] T8: pilot:
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
