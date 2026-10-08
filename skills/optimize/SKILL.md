---
description: Pętla optymalizacji skilla wg autoresearch — zmiana jednego pliku, stały eval, keep albo discard; szybciej i taniej bez straty jakości
disable-model-invocation: true
argument-hint: <skill> [--agent <nazwa>] [--limit N] [--budget USD] [--resume]
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, AskUserQuestion
---

# /regent:optimize — Pętla optymalizacji skilla

**Cel:** Obniż koszt tokenów i czas skilla przy niezmienionej jakości. Pętla wzorowana na
`karpathy/autoresearch`:
- zmieniasz jeden plik kandydata;
- stały zestaw evali daje jedną linię wyniku;
- skrypt rozstrzyga `keep` albo `discard`;
- pętla trwa do limitu.

Opis dla użytkownika: `docs/optimize.md`.

```
/regent:optimize <skill> [opcje]

Opcje:
  --agent <nazwa>   także agents/<nazwa>.md jako kandydat (jeden plik na eksperyment)
  --limit N         liczba eksperymentów (domyślnie 10)
  --budget USD      łączny limit kosztu evali (domyślnie: limit × 1,5 × koszt baseline train)
  --resume          kontynuacja ostatniej pętli tego skilla (worktree, gałąź, tsv)

Przykład:
/regent:optimize apply --agent backend-dev
```

Skrót `score` = `bash ${CLAUDE_PLUGIN_ROOT}/scripts/optimize-score.sh` (opis pól i reguły
w nagłówku skryptu).

---

## Krok 0: Warunki

```
□ bieżący katalog to repo pluginu (.claude-plugin/plugin.json) na czystym git status
□ skills/<skill>/SKILL.md istnieje
□ evals/<skill>/ ma przypadki z tagami <skill>-train i <skill>-holdout
□ jq oraz claude plugin eval (na Linuksie także bwrap i socat — sandbox Basha w evalu)
```

Brak zestawu evali → zatrzymaj się. Pokaż, jak go dopisać (`docs/optimize.md`, sekcja „Nowy
zestaw”, oraz `claude plugin eval init`).

## Krok 1: Start (jedyne pytanie)

Jednym `AskUserQuestion` pokaż:
- **co uruchomisz:** eval ładuje plugin z worktree i wykonuje przypadki na tej maszynie, jako
  użytkownik (`--trust-plugin`), z sandboksem Basha;
- **pliki kandydata:** `skills/<skill>/SKILL.md` (+ agent z `--agent`);
- **limit i budżet.**

Bez wyraźnego „tak” nie uruchamiasz evali. Po zgodzie nie zadajesz już pytań aż do raportu.

Przygotowanie:
1. Tag: `<skill>-<RRRR-MM-DD>` (zajęty → sufiks `-2`, `-3`). Worktree:
   `git worktree add ../<katalog-repo>-optimize-<tag> -b perf/optimize-<tag> HEAD`. Całą pracę
   robisz w worktree. Plugin działa na żywo z klonu (`--plugin-dir`), więc zmiana w klonie
   zmieniłaby skill we wszystkich sesjach.
2. CLI zadań w worktree (`dist` jest poza gitem):
   - skopiuj `tools/regent/dist` z klonu;
   - brak w klonie → `npm ci && npm run build` w `tools/regent` worktree.
3. `evals/results/optimize-<tag>.tsv` w worktree, nagłówek (tabulatory):
   `nr	commit	status	quality	cost	tokens	seconds	prompt	opis	powód`.

## Krok 2: Baseline

```bash
score run <wt> <skill>-train <wt>/evals/results/<tag>-000.json --runs 3 --files <kandydaci>
score run <wt> <skill>-holdout <wt>/evals/results/<tag>-holdout-base.json --files <kandydaci>
```

Linia train jest pierwszym `best`. Próg szumu: `noise` = max(0,05, `spread` z baseline).
Do tsv trafia wiersz `0` ze statusem `baseline`. Domyślny `--budget` liczysz z baseline:
łączny koszt to `jq .costUsd <json>`.

## Krok 3: Eksperyment (powtarzaj do limitu albo budżetu)

1. **Pomysł:** jedna hipoteza z listy „Pomysły”. Najpierw sprawdź tsv, żeby nie powtórzyć
   odrzuconej zmiany. Pomysły bierz z treści kandydata, z linii wyniku i z nazw oblanych
   oceniaczy (`failed=`).
2. **Zmiana:** edytuj jeden plik kandydata. Plik czytany na żądanie w `skills/<skill>/` też się
   liczy. `git -C <wt> status --porcelain` pokazuje wyłącznie ten plik.
3. **Lint:** `bash <wt>/scripts/framework-lint.sh` → ERROR → `git -C <wt> checkout -- .`, wiersz
   `crash`, następny pomysł.
4. **Commit:** `git -C <wt> add <plik> && git -C <wt> commit -m "perf: <opis>"`. Opis po polsku,
   w trybie rozkazującym, jedna linia.
5. **Ocena:**
   - `score run <wt> <skill>-train <wt>/evals/results/<tag>-<nr>.json --files <kandydaci>`
     `--budget <2 × koszt baseline train>` w tle (`run_in_background`); czekasz na zakończenie;
   - na ekran trafia wyłącznie linia wyniku;
   - kod 3 (eval padł) → wiersz `crash`, `git -C <wt> reset --hard HEAD~1`.
6. **Decyzja:** `score decide "<best>" "<linia>" --noise <noise>`.
   - Kod 0 (`keep`) → `best` = linia.
   - Kod 1 (`discard`) → `git -C <wt> reset --hard HEAD~1`.
7. **Wiersz w tsv:** nr, krótki hash, status, pola z linii, opis, powód z `decide`. Doliczasz
   `.costUsd` do zużytego budżetu.

Pętla działa sama do limitu. Przy braku pomysłów:
- przeczytaj kandydata od nowa;
- połącz dwa bliskie trafienia (`discard` z małą stratą);
- spróbuj większego usunięcia.

## Pomysły (w tej kolejności)

Zasady pisania promptów: `CONTRIBUTING.md` → „Jak pisać prompty”. Najczęstsze źródła zysku:
1. Skasuj to, co model robi sam, i duplikaty między skillem a agentem (jedno źródło).
2. Zastąp opis pojęciem; zakaz zastąp pozytywem.
3. Zawęź listę „czytaj zawsze” subagenta. Każdy plik czytany na starcie wraca w każdej turze.
4. Skróć format raportu subagenta i sesji głównej (tokeny wyjścia).
5. Mniej tur: niezależne odczyty i polecenia w jednej turze, mniej sprawdzeń „na wszelki wypadek”.
6. Rzadką gałąź (wyjątek, tryb) przenieś do pliku w `skills/<skill>/` czytanego na żądanie.
7. Popraw niejasny krok, na którym model się potyka: ponowione polecenie albo błąd narzędzia
   w śladzie to koszt.

## Krok 4: Koniec i raport

1. Holdout na najlepszym commicie:
   `score run <wt> <skill>-holdout <wt>/evals/results/<tag>-holdout-best.json --files <kandydaci>`,
   potem `score decide "<holdout-base>" "<holdout-best>" --noise <noise>`. Liczy się bramka jakości.
   `discard` z powodem „jakość” albo „przypadek” oznacza, że holdout odrzuca wynik.
2. Raport:

```markdown
## Optimize: <skill> — <tag>

Eksperymenty: N (keep K, discard D, crash C) · koszt evali: X USD
Wynik vs baseline: koszt −A%, tokeny −B%, czas −C%, prompt −D B · jakość Q0 → Q1
Holdout: PASS / ODRZUCA (<powód>)

| nr | status | opis | koszt | czas | powód |

Worktree: <ścieżka> · gałąź perf/optimize-<tag>
Przegląd: git -C <wt> diff <base>..HEAD
Merge: zwykłą ścieżką repo (bramka + smoke), potem `git worktree remove <wt>`
```

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Jeden plik kandydata na eksperyment, jeden commit na eksperyment, w worktree.
- O `keep`/`discard` decyduje `score decide`. Linia wyniku jest jedynym źródłem liczb.
- Wynik evala zostaje w pliku. Do kontekstu trafia linia, a przy crashu tylko błędy przebiegów
  (`jq '.cases[].arms.with[].error'`).
- Usunięcie tekstu przy tej samej jakości to wygrana: przy remisie wygrywa krótszy prompt.
- Projekty testowe w `evals/` są syntetyczne. Kod i dane z pracy nie trafiają do evali.

❌ **Barierka:** zmieniasz tylko pliki kandydata. `evals/`, `scripts/` i reguły
`require`/`forbid` w lincie to wyrocznia: jej zmiana unieważnia porównanie z baseline.

❌ **Barierka:** bez push i bez merge. O merge'u decyduje użytkownik po przeglądzie raportu i diffu.
