# `/regent:optimize` — pętla optymalizacji skilli

Pętla wzorowana na [`karpathy/autoresearch`](https://github.com/karpathy/autoresearch). Agent
zmienia jeden plik i uruchamia stałą ocenę o stałym budżecie. Lepszy wynik zostaje jako commit,
gorszy cofa `git reset`, a pętla działa sama do limitu. W Regencie zmieniany plik to prompt skilla
albo agenta. Oceną jest zestaw evali (`claude plugin eval`) na syntetycznym projekcie testowym.
Cel: mniej tokenów i krótszy czas przy niezmienionej jakości. Plan i decyzje:
[plans/optimize.md](plans/optimize.md).

## Szybki start

W klonie repo pluginu, na czystym `git status`:

```text
/regent:optimize apply                      # 10 eksperymentów, budżet z baseline
/regent:optimize apply --agent backend-dev  # kandydatem także agents/backend-dev.md
/regent:optimize apply --limit 20 --budget 30
/regent:optimize apply --resume             # kontynuacja po przerwanej sesji
```

Na starcie odpowiadasz na jedno pytanie: zgoda na uruchomienie evali (`--trust-plugin`),
pliki kandydata, limit i budżet. Potem pętla działa sama. Na końcu dostajesz raport:
- tabelę eksperymentów;
- zysk wobec baseline;
- werdykt przypadków kontrolnych;
- polecenia do przeglądu diffu.

Merge robisz Ty, zwykłą ścieżką repo: bramka, smoke, `main`.

**Wymagania:**
- Claude Code z `claude plugin eval`;
- `jq`;
- na Linuksie `bubblewrap` i `socat`, bo eval uruchamia Bash tylko w sandboksie (macOS ma
  sandbox wbudowany);
- dla `apply` zbudowane CLI `tools/regent` (pętla kopiuje `dist` do worktree).

## Jak to działa

| autoresearch | Regent |
|---|---|
| `train.py` — jedyny edytowany plik | kandydat: `skills/<skill>/SKILL.md` (opcjonalnie `agents/<nazwa>.md`), jeden plik na eksperyment |
| `prepare.py` + `evaluate_bpb` — zamrożone | wyrocznia: `evals/<skill>/` i `scripts/optimize-score.sh` |
| `program.md` | `skills/optimize/SKILL.md` |
| 5 minut na eksperyment | stały budżet przypadku: `max_turns`, `timeout_seconds`, `runs`, limit kosztu |
| `val_bpb` | bramka jakości + koszt, czas pomocniczo, długość promptu przy remisie |
| `results.tsv` | `evals/results/optimize-<tag>.tsv` (poza gitem) |
| gałąź `autoresearch/<tag>` | gałąź `perf/optimize-<tag>` w osobnym worktree |

**Worktree jest obowiązkowy.** Plugin działa na żywo z klonu (`--plugin-dir`), więc eksperyment
w klonie zmieniałby skill we wszystkich sesjach.

## Metryka i decyzja

`optimize-score.sh run` uruchamia eval i wypisuje jedną linię:

```text
quality=0.95 cost=1.21 tokens=1840522 seconds=268 prompt=14106 spread=0.18 cases=train-two-tasks:1,… failed=- errors=0
```

- `quality` — średni wynik przypadków.
- `cost` — suma median kosztu przypadków w USD: tokeny ważone cennikiem, razem z subagentami.
  Ta liczba najlepiej oddaje zużycie limitu, bo odczyt cache kosztuje 0,1 wejścia, a wyjście
  ~5 razy więcej.
- `tokens` — surowe tokeny do raportu.
- `seconds` — czas.
- `prompt` — bajty plików kandydata.

`optimize-score.sh decide` rozstrzyga `keep` albo `discard` (liczy skrypt, nie model).

**Bramka jakości** jest pierwsza: `quality` nie spada, a żaden przypadek, który miał 1,00, nie
zaczyna oblewać. Dopiero po niej zmiana zostaje, gdy spełnia jeden z warunków:
1. koszt spada o więcej niż próg szumu;
2. czas spada o więcej niż próg, a koszt nie rośnie ponad próg;
3. koszt i czas mieszczą się w progu, a prompt jest krótszy (kryterium prostoty).

Próg to max(5%, `spread`), gdzie `spread` to rozrzut kosztu zestawu w trzech przebiegach baseline:
Σ(max − min) / Σ median przypadków. To w przybliżeniu 2σ różnicy dwóch pomiarów. Największy rozrzut
pojedynczego przypadku byłby za ostry, bo jeden niestabilny przypadek blokowałby każdą poprawę.

Jakość nie wchodzi do ilorazu z tokenami („tokeny / jakość”), bo wtedy pętla mogłaby oddać
jakość za tańszy przebieg. Nieudany task kosztuje w realnej pracy więcej, niż wynosi oszczędność.

## Ochrona przed dopasowaniem do evala

- **Zestaw kontrolny.** Przypadki z tagiem `<skill>-holdout` pętla uruchamia tylko przy baseline
  i na końcu. Wynik, który poprawia train, a psuje holdout, nie nadaje się do merge'a.
- **Wyrocznia jest zamrożona.** Pętla zmienia wyłącznie pliki kandydata. `evals/`, `scripts/`
  i reguły `require`/`forbid` w lincie zostają bez zmian, a lint przed każdym evalem pilnuje
  chronionych reguł promptów.
- **Przegląd diffu i sprawdzenie na żywo.** Po merge'u `regent-apply-tokens` porównuje prawdziwe
  sesje `apply` z punktem odniesienia ([tasks.md](tasks.md)).

## Zestaw `apply`

Projekt testowy `evals/apply/fixtures/notes-app/`:
- Node bez zależności, testy `node --test`, `Makefile` z celami agentów;
- minimalne `ai/docs/`;
- cztery zmiany `Approved` i celowy bug dla `bugfix`.

`evals/apply/scaffold.sh` kopiuje go do sandboksu evala i robi commit startowy z `/ai/` poza
gitem, jak w prawdziwym projekcie.

| Przypadek | Tag | Co sprawdza |
|---|---|---|
| `train-two-tasks` | `apply-train` | dwa niezależne taski `[BE]`: delegacja, paczka z CLI, commit i ślad na task, RED przed GREEN, testy pokrywają AC |
| `train-dependency` | `apply-train` | `(po T-01)`: dwie rundy, nowy subagent na rundę, bez `SendMessage` |
| `train-tasks-filter` | `apply-train` | `--tasks 2`: tylko wskazany task, reszta nietknięta |
| `holdout-db-be` | `apply-holdout` | `[DB]` do `regent:dba`, potem `[BE]` |
| `holdout-no-cli` | `apply-holdout` | ścieżka bez CLI (`EVAL_REGENT_NO_CLI=1`) |
| `holdout-bugfix` | `apply-holdout` | `/regent:bugfix` na tym samym projekcie — chroni agenta `backend-dev`, którego używa 6 skilli |
| `holdout-four-tasks` | `apply-holdout` | cztery taski z dwiema zależnościami |

Oceniacze są najpierw deterministyczne:
- `tool_used`: delegacja (`Agent` z `regent:<agent>`), `SendMessage` 0 razy, `task packet`,
  liczba `git commit`;
- regex po `tasks.md` (`[x] T-NN` ze śladem `commit:`);
- regex po śladzie: test oblany przed zielonym;
- `file_exists`.

Sędzia LLM ocenia tylko zawartość krótkich plików, na podstawie twierdzeń do sprawdzenia
(„PASS if … Otherwise FAIL”). Domyślny sędzia to haiku: inny model niż agent.

Przypadki działają bez użytkownika. `append_system_prompt` mówi, że każda zgoda brzmi „tak”,
a pytanie przez `AskUserQuestion` dostaje opcję rekomendowaną. Model sesji jest przypięty
(`sonnet`), żeby wynik nie zależał od domyślnego modelu maszyny.

## Nowy zestaw dla innego skilla

1. Katalog `evals/<skill>/` z projektem testowym w `fixtures/` i wspólnym `scaffold.sh`. Każdy
   przypadek ma własny `scaffold.sh`, który woła wspólny. Eval przyjmuje tylko skrypt z katalogu
   przypadku, a scaffold dostaje `HOME` sandboksu i bezwzględne `$0`.
2. 3 przypadki z tagiem `<skill>-train` (runs 2) i 3–4 z tagiem `<skill>-holdout` (runs 3).
   Train ma być tani i szybki, bo idzie przy każdym eksperymencie.
3. Oceniacze deterministyczne tam, gdzie się da. Sędzia LLM tylko na krótkich plikach,
   z kryterium sprawdzonym na prawdziwym wyniku (`claude -p --model haiku`).
4. Pilot: `bash scripts/optimize-score.sh run . <skill>-train /tmp/x.json --runs 1`. Przejrzyj
   oblane oceniacze: błąd oceniacza poprawiasz w zestawie, nie w skillu.

Pomocniczo: `claude plugin eval init` prowadzi przez projekt przypadków.

## Ograniczenia

- Eval kosztuje: każdy przebieg to pełna sesja z subagentami. Koszt eksperymentu podaje baseline
  (pole `cost` i `.costUsd` w JSON-ie). Limit ustawiają `--limit` i `--budget`.
- Przebiegi LLM się różnią. Próg szumu chroni przed fałszywym `keep`, ale mała poprawa może
  zostać odrzucona.
- Eval ocenia skill na małym projekcie. O tym, czy zysk przenosi się na prawdziwe projekty,
  rozstrzyga pomiar po merge'u.
- Nazwa narzędzia delegacji w śladzie to `Agent`. Starsze wersje Claude Code używały `Task`
  i wtedy trzeba poprawić oceniacze `tool_used`.
