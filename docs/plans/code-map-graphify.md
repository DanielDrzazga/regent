# Plan: code-map-graphify

> Opcjonalna integracja z Graphify (lokalizowanie plików i zależności przez graf kodu zamiast
> Grep/Glob) + pomiar, czy to oszczędza tokeny bez straty jakości. Lekka ścieżka: gałąź
> `feat/code-map-graphify`, ten plan, bramka i smoke. Mechanikę robi sesja główna, bez subagentów.
> Decyzje 1–7 z briefu zadania są zamknięte (opcjonalność, bez hooków Graphify, tylko kod/zero LLM,
> graf lokalizuje, buduje tylko sesja główna/user, wiki/docs zostają, prywatność) — nieotwierane
> ponownie tutaj.

## Krok 0 — Ustalenia o Graphify (zweryfikowane na zainstalowanej wersji)

Instalacja izolowana: `uv venv` (Python 3.12 pobrany przez `uv`, bo w tym środowisku nie ma
Pythona systemowo) + `uv pip install graphifyy` w `/tmp/graphify-verify/venv` — **nie globalnie**.

| Pytanie | Ustalenie |
|---|---|
| Nazwa paczki | `graphifyy` (PyPI) potwierdzona: `project_urls.Repository = github.com/Graphify-Labs/graphify`, `Homepage = graphify.com`. Wersja zweryfikowana: **0.9.97**. |
| Licencja | **Apache-2.0** (metadata PyPI: `License-Expression: Apache-2.0`, pliki `LICENSE`/`NOTICE`) — bez wątpliwości. |
| Budowa z kodu, zero LLM, zero sieci | `graphify extract <path> --code-only --out <dir>` — flaga `--code-only` explicite: „index code (local AST, no API key) and skip doc/paper/image files". Zweryfikowane offline: zablokowane `HTTP(S)_PROXY`/`ALL_PROXY` na nieistniejący port + brak kluczy API w env → budowa i inkrementalna aktualizacja przechodzą bez błędu, bez połączenia sieciowego. `graphify update <path>` też nie wywołuje LLM („no LLM needed" we własnym komunikacie), ale **nie ma `--code-only`** i **domyślnie wciąga Markdown jako węzły** (nagłówki jako `node_kind: heading`) — patrz niżej. |
| ⚠️ Pułapka: `cluster-only` / `label` | Bez `--no-label`, `graphify cluster-only` przy braku klucza API **shelluje do lokalnego `claude -p`** („no API key found; naming communities via the `claude` CLI") — w teście zawisło do timeoutu. Regent **nigdy nie wywołuje `cluster-only`/`label` bez `--no-label`**, a najprostsza bezpieczna ścieżka to ich wcale nie wywoływać — `extract --code-only` sam liczy społeczności (numeryczne `community`, bez `community_name`) bez LLM i bez tej pułapki. |
| Wykluczenie dokumentów | `--code-only` na `extract` skipuje pliki doc/paper/image **całkowicie** (potwierdzone: `.md` nie trafia do grafu — 0 węzłów). `update` **bez** `--code-only` wciąga nagłówki Markdown jako węzły (bez LLM, ale to wciąż dotyk dokumentów wbrew decyzji #3) — `.graphifyignore` z `*.md` to naprawia (zweryfikowane: 0 węzłów `.md` po dodaniu). Regent używa `extract --code-only`, więc `.graphifyignore` nie jest wymagany, ale `/regent:init` i tak go proponuje jako zabezpieczenie przed ręcznym `graphify update` przez użytkownika (patrz Krok 1e). |
| Katalog wyjściowy | `extract` ma `--out DIR` → zapisuje do `<DIR>/graphify-out/`. `update` **nie ma** takiej flagi (zawsze `<path>/graphify-out/`). Stąd wybór `extract --code-only --out ai/graph` — graf trafia do `ai/graph/graphify-out/graph.json` (nie `ai/graph/graph.json` — ścieżka ma dodatkowy segment `graphify-out/`, trzeba ją wszędzie pisać w całości). |
| Sieć i telemetria | Brak — oba testy offline (proxy na nieistniejący port) przeszły: budowa pierwsza i inkrementalna. |
| Aktualność grafu | Graf **nie zapisuje commita ani znacznika czasu porównywalnego z HEAD** — tylko `mtime` per plik w `graphify-out/manifest.json` i `graph_mtime_ns` w `.graphify_build_state.json`. Sprawdzanie świeżości: `find . -newer ai/graph/graphify-out/graph.json -type f …` (patrz `context/code-map.md`) — heurystyka, nie dowód; `find -newer` jest przenośne (GNU/BSD), w przeciwieństwie do `stat -f`/`stat -c` (por. komentarz w `scripts/statusline.sh`). |
| Koszt wyjścia | Na projekcie-zabawce (3 pliki TS): `explain` ~390 B, `path` ~100 B, `query` ~440 B. `query` ma `--budget N` (domyślnie 2000 tokenów) — twardy sufit niezależny od rozmiaru repo. Rząd wielkości dużo mniejszy niż seria Grep+Read. |
| Języki | TS/JS z dekoratorami NestJS: węzły i krawędzie sensowne (`@Controller`/`@Injectable` jako `references`, metody jako `.method()`, `imports`/`contains`/`calls`). **Ograniczenie zaobserwowane:** DI przez parametr konstruktora (`constructor(private x: FooService)`) **nie daje krawędzi wywołania** — `graphify path` między kontrolerem i serwisem wstrzykiwanym w konstruktorze spada do wspólnego `contains` pliku, nie realnej zależności DI. Do odnotowania w `docs/code-map.md`, bez blokady. |

**Werdykt Kroku 0: brak warunku STOP.** Budowa nie wymaga LLM/sieci (z `--code-only`), dokumenty
da się wykluczyć całkowicie, wyjście zapytań jest małe i ograniczone budżetem, paczka i licencja
nie budzą wątpliwości. Jedna korekta projektu z brief'u: polecenie budowy/aktualizacji to
**`graphify extract <ścieżka> --code-only --out ai/graph`** (nie `graphify update .` z brief'u —
`update` nie ma `--code-only` ani `--out`; patrz tabela wyżej), a społeczności zostają numeryczne
(bez `cluster-only`/`label`, żeby nie ryzykować sheli do `claude -p`).

## Krok 1 — Integracja

| Plik | Zmiana |
|---|---|
| `context/code-map.md` (nowy) | Reguła: kiedy obowiązuje, polecenia `path`/`explain`/`affected` z `--graph ai/graph/graphify-out/graph.json`, sprawdzenie świeżości (`find -newer`), fallback Grep/Glob + linia w raporcie, barierka „subagent nie buduje/aktualizuje" i pułapka `cluster-only`/`label`. Cel < 1500 B. |
| `scripts/hooks/session-context.sh` | Nowy zakres `graph`: `[ "$scope" = graph ] && [ ! -f "$PROJECT/ai/graph/graphify-out/graph.json" ] && exit 0` (analogicznie do `sdd`). |
| `hooks/hooks.json` | `SessionStart` + `SubagentStart`: `session-context.sh session graph code-map.md` / `subagent graph code-map.md`. |
| `scripts/tests/session-context.test.sh` | Przypadki: graf jest / grafu nie ma / (reużywa istniejących dla błędnego użycia). |
| `agents/architect.md` | Jedno zdanie w „Kolejność poznawania wzorców": gdy w kontekście jest `context/code-map.md`, lokalizuj przez jej polecenia zamiast Grep/Glob. |
| `agents/code-reviewer.md`, `agents/security-auditor.md` | Jedno zdanie: zasięg zmienionych symboli (kto jeszcze woła) przez mapę kodu, gdy jest w kontekście. |
| `agents/backend-dev.md` | Checklist „przed nowym helperem" — najpierw mapa kodu (gdy jest), inaczej Grep. |
| `scripts/hooks/git-guard.sh` | Bez zmian — sprawdzone: hook dopasowuje wyłącznie `git`/`gh pr`, `graphify` nie jest blokowane. |
| `skills/explore/SKILL.md`, `skills/code-review/SKILL.md`, `skills/wiki/SKILL.md` | `allowed-tools` += `Bash(graphify query:*), Bash(graphify path:*), Bash(graphify explain:*), Bash(graphify affected:*)` — tylko odczyt; budowę/aktualizację (`extract`) te skille nie wołają. |
| `skills/init/SKILL.md` | Nowy „Krok 0.75": CLI jest + grafu nie ma → `AskUserQuestion` (zbuduj/pomiń) `graphify extract . --code-only --out ai/graph` + `.graphifyignore` z `*.md` (jeśli brak); CLI jest + graf jest → architekt w Kroku 1 zaczyna od `graphify god-nodes`; CLI brak → pomiń po cichu. Już ma generyczny `Bash` w `allowed-tools` — bez zmiany uprawnień. |
| `skills/wiki/SKILL.md` Krok 1 (`init`) | Partie według społeczności z grafu (`community` w `graph.json`), gdy jest `context/code-map.md`; inaczej po ≤5 modułów (bez zmian). |
| `skills/wiki/SKILL.md` Krok 5 (`sync`) | Dopasowanie po prefiksie `obszar:` rozszerzone: dla zmienionych plików sprawdź `graphify affected`, strony z `obszar:` zależnego modułu → dopisz z adnotacją „zależność pośrednia przez {plik}". |
| `skills/propose/SKILL.md` | Bez zmian — sprawdzone: prompt do architekta już odsyła do reguły lokalizowania (nie duplikuje), zgodny z nową regułą. |
| `README.md` | Sekcja „Mapa kodu — Graphify (opcjonalnie)" (styl Observability, 3–5 linii) + wpis w spisie treści. |
| `docs/code-map.md` (nowy) | Instalacja izolowana, budowa/aktualizacja, dlaczego bez hooków Graphify, prywatność, kiedy się opłaca/nie, ograniczenie DI z Kroku 0. |
| `docs/README.md` | Wiersz dla `scripts/code-map-compare.sh`. |
| `scripts/framework-lint.sh` | Sekcja 7: `forbid` `graphify install`/`hook install`/`--strict` w `skills/`+`agents/`; `require` że `context/code-map.md` opisuje powrót do Grep/Glob. |

`context/sdd-map.md` — bez zmian (nie dodajemy skilla/agenta, tabele się nie zmieniają).

## Krok 2 — Evale i pomiar

| Element | Zmiana |
|---|---|
| `evals/wiki/scaffold.sh` | Drugi parametr `graph` (domyślnie puste): po ustawieniu projektu buduje graf (`graphify extract . --code-only --out ai/graph`); brak `graphify` w PATH → `exit 1` z komunikatem (jawna oblana, nie cicha). W trybie `sync` + `graph`: dodatkowy plik `cli/print-notes.js` (zależny od `web/note-list.js`) + commit, **tylko w wariancie graph** — hash `2ff82e9` istniejącego trybu `sync` (bez `graph`) zostaje nietknięty. |
| `evals/wiki/holdout-sync-graph/` (nowy przypadek) | `scaffold.sh` → `../scaffold.sh sync graph` + dopisanie strony „Wydruk konsolowy" (`obszar: cli/`) do vaulta i `index.md` (poza gitem — `ai/` jest wyłączone, więc bez wpływu na hash). `case.yaml`: tag `wiki-holdout`, `wiki-code-map-graph`; oceniacz na wzmiankę „Wydruk konsolowy"/„zależność pośrednia" w odpowiedzi. |
| `evals/wiki/holdout-sync/case.yaml` | `+tags: wiki-code-map-nograph` (metadane do wyboru przez `code-map-compare.sh`, bez zmiany scaffoldu/graderów/promptu — przypadek przechodzi identycznie jak dotąd). |
| `evals/explore/` (nowy katalog) | `scaffold.sh` (notes-app + opcjonalny graf, drugi parametr jak w wiki), dwa przypadki: `explore-graph` (tag `explore-code-map-graph`) i `explore-nograph` (tag `explore-code-map-nograph`) — ten sam prompt o wpływie zmiany `web/html.js` (import w `web/note-list.js`), `runs: 3`. |
| `scripts/code-map-compare.sh` (nowy) | `run <plugin> <tag-bez> <tag-z> <out-prefix> [opcje optimize-score.sh]`: dwa przebiegi `optimize-score.sh run`, dwie linie wyniku, różnice `quality/cost/tokens/seconds`, werdykt `optimize-score.sh decide` (bez grafu = best/baseline, z grafem = kandydat). `--no-bash` przepuszczony z ostrzeżeniem, że graf nie zadziała (zapytania idą przez Bash). |
| `scripts/tests/code-map-compare.test.sh` (nowy) | Tryb na sztucznych JSON-ach (dwa `score`), bez prawdziwego evala; bash 3.2. |
| `docs/optimize.md` | Zostaje bez zmian — `code-map-compare.sh` dokumentuje się sam (nagłówek) + wpis w `docs/README.md`; nie jest częścią pętli `/regent:optimize`. |

## Krok 2c — Pomiar

- **notes-app:** `scripts/code-map-compare.sh . wiki-code-map-nograph wiki-code-map-graph` (wiki)
  i `scripts/code-map-compare.sh . explore-code-map-nograph explore-code-map-graph` (explore) —
  wynik w sekcji „Wyniki" niżej po przebiegu.
- **Repo publiczne:** wybór i wynik — sekcja „Wyniki" niżej (commit przypięty w tabeli).
- **Repo firmowe:** poza zakresem tej sesji — robi użytkownik sam, liczby nie trafiają do repo
  (`.claude/rules/privacy.md`).

## Checklista

- [x] Gałąź `feat/code-map-graphify`, ten plan.
- [x] Krok 0: Graphify zweryfikowane (instalacja izolowana, polecenia, offline, `.graphifyignore`,
  katalog wyjściowy, pułapka `cluster-only`, DI w NestJS) — bez warunku STOP.
- [x] `context/code-map.md` + hook (`session-context.sh` zakres `graph`) + `hooks.json` + testy.
- [x] Agenci: `architect.md`, `code-reviewer.md`, `security-auditor.md`, `backend-dev.md`.
- [x] Skille: uprawnienia (`explore`, `code-review`, `wiki`), `init` Krok 0.75, `wiki init`/`sync`.
- [x] `README.md`, `docs/code-map.md`, `docs/README.md`, `scripts/framework-lint.sh` sekcja 7.
- [x] Bramka: `bash scripts/framework-lint.sh` → 0 ERROR; `claude plugin validate .` (OK, jedyne
  ostrzeżenie: brak `version`).
- [x] Evale: `evals/wiki/scaffold.sh` tryb graph, `holdout-sync-graph`, tag na `holdout-sync`,
  `evals/explore/` (`explore-graph`, `explore-nograph`).
- [x] `scripts/code-map-compare.sh` + test.
- [x] Pomiar notes-app (`code-map-compare.sh` na `wiki` i `explore`) — wynik niżej; wiki
  do potwierdzenia ponownie po limicie sesji (poprawka oceniacza już scommitowana, niepotwierdzona).
- [ ] Pomiar na repo publicznym — **nie dokończony**: limit sesji konta przerwał oba warianty
  przed wykonaniem jakiejkolwiek pracy (zero danych). Polecenie do powtórzenia niżej.
- [x] Smoke ręczny: hook bez grafu (0 B) / z grafem (treść wstrzyknięta sesji i subagentowi
  `regent:architect`) sprawdzony bezpośrednio; realne wywołanie `graphify` przez architekta i
  brak aktualizacji grafu przez subagenta potwierdzone przez oceniacze w przebiegach evali.
- [x] Werdykt wg kryterium utrzymania — niżej (**nie potwierdzony**, nie odrzucony: brakuje
  danych z repo średniego). Commity gotowe, **bez merge do `main`**.

## Wyniki

### notes-app — `scripts/code-map-compare.sh` (realne przebiegi, `claude plugin eval`)

| Przypadek | quality (bez→z) | cost USD (bez→z) | tokens (bez→z) | seconds (bez→z) | werdykt |
|---|---|---|---|---|---|
| `explore-impact` (`--runs 3`) | 1 → 1 (+0%) | 0.304 → 0.363 (**+19,4%**) | 154 816 → 171 955 (+11,1%) | 72 → 73 (+1,4%) | `discard` — koszt powyżej progu szumu (5%) |
| `wiki-holdout-sync` (`--runs 3`, przebieg sprzed poprawki oceniacza) | 1 → 0,857 (−14,3%) | 0,154 → 0,177 (+14,9%) | 229 260 → 335 950 (+46,5%) | 30 → 40 (+33,3%) | `discard` — jakość niżej |

**Czytanie wyników:**
- `explore`: jakość identyczna, ale wariant z grafem jest **droższy** o ~19% — zgodnie z
  przewidywaniem z `docs/code-map.md` („małe, znane repo — koszt bywa porównywalny lub wyższy”):
  na projekcie 3-plikowym koszt wywołania `graphify` i wstrzyknięcia `context/code-map.md`
  przewyższa to, co by zaoszczędził na Grep/Read. **To jest oczekiwany wynik na tej skali**,
  nie regresja.
- `wiki sync`: spadek jakości **nie jest problemem z użyciem grafu** — oceniacz `uzywa-grafu`
  przeszedł (model realnie wywołał `graphify affected`), a `strona-zaleznosci-posredniej`
  przeszedł we wszystkich 3 przebiegach (model znalazł właściwą stronę „Wydruk konsolowy”
  przez zależność pośrednią, czego dopasowanie po prefiksie `obszar:` nie łapie — to jest clou
  tego przypadku). Oblewał tylko oceniacz `nazwana-zaleznosc-posrednia`: zbyt literalny wzorzec
  (`"zależność pośrednia"`) nie złapał innej, poprawnej parafrazy modelu. Poprawka (wzorzec
  `"zależn"`, commit w tej gałęzi) nie została ponownie zmierzona — limit sesji przerwał
  powtórny przebieg trzema błędami API (`You've hit your session limit`), nie błędem w kodzie.
  **Do zrobienia po reset limitu:** `bash scripts/code-map-compare.sh . wiki-code-map-nograph
  wiki-code-map-graph /tmp/wiki-recheck --runs 3`.

### Repo publiczne — nie dokończone

Wybrane repo: [`Sairyss/domain-driven-hexagon`](https://github.com/Sairyss/domain-driven-hexagon)
(commit `5c2d15a7e2d69e83dfddf28468ee9f30e02c30de`, 95 plików TS, 3121 linii, architektura
DDD/hexagonal — moduły `user`/`wallet` z realną zależnością międzymodułową przez zdarzenie
domenowe `UserCreated`, konsumowane przez handler w module `wallet`
(`src/modules/wallet/application/event-handlers/create-wallet-when-user-is-created.domain-event-handler.ts`) —
nieoczywiste bez przeszukania, dobry test lokalizowania przez graf).

Próba uruchomienia bezpośredniego `claude -p --dangerously-skip-permissions` dla headless sesji
z `--plugin-dir` została **zablokowana przez klasyfikator auto-mode** („Create Unsafe Agents”) —
zgodnie z zasadą „nie obchodź odmów”, przerzucono pomiar na tymczasowy, nie-commitowany przypadek
`claude plugin eval` (sandboks już zatwierdzony przez wcześniejsze przebiegi notes-app) z promptem
`/regent:explore impact of changing the UserCreated domain event payload — which files would need
to change?`. Oba warianty (bez/z grafem) oblały z błędem `You've hit your session limit · resets
1:50am (Europe/Warsaw)` **przed wykonaniem jakiejkolwiek pracy** — zero realnych danych, nie
porównanie 0 z 0.

**Do zrobienia po reset limitu** (odtworzenie, graf już zbudowany lokalnie w `/tmp/ddh-graph`,
patrz przebieg sesji poniżej, albo od nowa: sklonować repo, `graphify extract . --code-only
--out ai/graph` w kopii „z grafem”, tymczasowy katalog `evals/<nazwa>/{nograph,graph}/` z
`scaffold.sh` kopiującym repo i `case.yaml` jak w Kroku 2b, `scripts/code-map-compare.sh`, potem
usunąć tymczasowy katalog przed commitem — nie wchodzi do zestawu stałego).

### Werdykt wg kryterium utrzymania

> Kryterium: *na `notes-app` jakość bez spadku i koszt w granicach szumu; na repo średnim spadek
> kosztu `init --detect` i `explore` o co najmniej 15% przy tej samej jakości.*

**Nie potwierdzony, nie odrzucony — brakuje decydujących danych.** Na `notes-app` pierwsza część
kryterium **nie jest spełniona dla `explore`** (koszt wyżej o 19%, nie w granicach szumu) — ale to
zgodne z dokumentacją: ta sama sekcja `docs/code-map.md` mówi wprost, że mały projekt nie pokazuje
oszczędności. Druga, decydująca część kryterium (repo średnie) nie ma żadnego pomiaru — limit
sesji przerwał próbę zanim padł pierwszy token odpowiedzi. Bez tego pomiaru nie da się ani
potwierdzić integracji, ani jej wycofać z czystym sumieniem: koszt na `notes-app` jest dokładnie
tym, czego oczekiwano (reguła dodaje stałą narzutę niezależną od rozmiaru repo — `context/
code-map.md` to ~1,8 kB w kontekście plus 1+ wywołanie Bash), a to, czy ta narzuta się opłaca,
rozstrzyga rozmiar repo, nie coś, co już wiadomo.

**Rekomendacja:** zostać na gałęzi (nie merge do `main`, zgodnie z zasadą), dokończyć pomiar na
repo publicznym i ponowić pomiar `wiki` po resecie limitu sesji (~1:50 w nocy czasu Warszawy),
dopiero potem decyzja keep/discard.
