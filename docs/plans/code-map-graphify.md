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
- [x] Pomiar notes-app (`code-map-compare.sh` na `wiki` i `explore`), dwa przebiegi — wynik niżej.
- [x] Pomiar na repo publicznym (po reset limitu sesji) — wynik niżej.
- [x] Smoke ręczny: hook bez grafu (0 B) / z grafem (treść wstrzyknięta sesji i subagentowi
  `regent:architect`) sprawdzony bezpośrednio; realne wywołanie `graphify` przez architekta i
  brak aktualizacji grafu przez subagenta potwierdzone przez oceniacze w przebiegach evali.
- [x] Werdykt wg kryterium utrzymania — niżej (**spełniony na repo średnim dla `explore`**).
  Commity gotowe, **bez merge do `main`**.

## Wyniki

### notes-app — `scripts/code-map-compare.sh` (realne przebiegi, `claude plugin eval`, `--runs 3`)

| Przypadek | quality (bez→z) | cost USD (bez→z) | tokens (bez→z) | seconds (bez→z) | werdykt |
|---|---|---|---|---|---|
| `explore-impact` | 1 → 1 (+0%) | 0.304 → 0.363 (**+19,4%**) | 154 816 → 171 955 (+11,1%) | 72 → 73 (+1,4%) | `discard` — koszt powyżej progu szumu (5%) |
| `wiki-holdout-sync` (po poprawce oceniacza, 2. przebieg) | 1 → 0,905 (−9,5%) | 0,148 → 0,173 (+16,9%) | 224 147 → 274 106 (+22,3%) | 29 → 33 (+13,8%) | `discard` — jakość niżej |

**Czytanie wyników:** na projekcie 3–7-plikowym koszt wywołania `graphify` i wstrzyknięcia
`context/code-map.md` **przewyższa** to, co dałoby się zaoszczędzić na Grep/Read — zgodnie
z przewidywaniem w `docs/code-map.md` („małe, znane repo”). W `wiki` resztkowy spadek jakości
to nie błąd integracji: w 1 z 3 przebiegów model w ogóle nie sięgnął po `graphify` (oceniacze
`uzywa-grafu` i `nazwana-zaleznosc-posrednia` oblały razem, w tym samym przebiegu) — na vaulcie
z 7 stronami przeczytanie wszystkiego naraz bywa tańsze niż jedno zapytanie do grafu, więc model
czasem słusznie z niego nie korzysta. **Oba wyniki na `notes-app` są oczekiwane na tej skali**,
nie regresje.

### Repo publiczne — `domain-driven-hexagon`

Wybrane repo: [`Sairyss/domain-driven-hexagon`](https://github.com/Sairyss/domain-driven-hexagon)
(commit `5c2d15a7e2d69e83dfddf28468ee9f30e02c30de`, 95 plików TS, 3121 linii, architektura
DDD/hexagonal — moduły `user`/`wallet` z realną zależnością międzymodułową przez zdarzenie
domenowe `UserCreated`, konsumowane przez handler w module `wallet`
(`src/modules/wallet/application/event-handlers/create-wallet-when-user-is-created.domain-event-handler.ts`) —
nieoczywiste bez przeszukania, dobry test lokalizowania przez graf). Pomiar przez tymczasowy,
nie-commitowany przypadek `claude plugin eval` (nie wchodzi do zestawu stałego; pierwsza próba
trafiła w limit sesji konta, zero danych — powtórzona po resecie).

| Przypadek | quality (bez→z) | cost USD (bez→z) | tokens (bez→z) | seconds (bez→z) | werdykt |
|---|---|---|---|---|---|
| `explore` — wpływ zmiany zdarzenia domenowego | 1 → 1 (+0%) | 0,398 → 0,322 (**−19,1%**) | 166 314 → 178 019 (+7,0%) | 91 → 77 (−15,4%) | **`keep`** |
| `init --detect` | 1 → 1 (+0%) | 1,967 → 1,915 (−2,6%, w szumie) | n/d → 2 298 998* | 561 → 483 (**−13,9%**) | **`keep`** (przez czas) |
| `wiki init` | 1 → 1 (+0%) | 1,306 → 1,066 (**−18,4%**) | 1 884 946 → 1 680 650 (−10,8%) | 336 → 293 (−12,8%) | **`keep`** |

\* tokeny bez grafu dla `init --detect` niedostępne — ślad przebiegu usunięty zanim ponownie
policzyłem wynik po przerwaniu pierwszej próby (zbyt krótki limit tła); koszt (`costUsd`, z
JSON-a, niezależny od śladu) jest wiarygodny.

Wszystkie trzy przypadki poprawnie wykonały zadanie: `explore` wskazał handler dotknięty zmianą
zdarzenia w obu wariantach (oceniacz `wskazuje-wallet-handler`); `wiki init` zapisał vault z
`index.md` w obu wariantach, a wariant z grafem realnie wywołał `graphify` (oceniacz
`uzywa-grafu`) i partycjonował pracę według społeczności z grafu, jak zapisano w
`skills/wiki/SKILL.md` Krok 1. **Pełny protokół z briefu (3 prompty × 2 warianty) jest teraz
kompletny na repo publicznym — wszystkie trzy przypadki przechodzą kryterium `keep`.**

### Repo prywatne — sanity-check (liczby zagregowane, bez szczegółów projektu)

Na prośbę użytkownika dodatkowy pomiar na jego prywatnym repo (backend NestJS, ~500 plików TS,
~80 tys. linii, modularna architektura z wydzielonymi zdarzeniami domenowymi między modułami) —
**za zgodą użytkownika do repo trafiają tylko zagregowane liczby**, bez nazw plików/modułów
(`.claude/rules/privacy.md`).

| Przypadek | quality (bez→z) | cost USD (bez→z) | tokens (bez→z) | seconds (bez→z) | werdykt |
|---|---|---|---|---|---|
| `explore` — wpływ zmiany jednego zdarzenia domenowego, konsumowanego przez inny moduł | 1 → 1 (+0%) | 0,422 → 0,459 (**+8,8%**) | 235 240 → 285 686 (+21,4%) | 79 → 97 (+22,8%) | `discard` — koszt i czas powyżej progu szumu |

**To jest pouczający kontrprzykład**, nie szum: na tym repo (większym niż `domain-driven-hexagon`)
graf wyszedł **drożej**, bo pytanie miało unikalną, łatwo grepowalną nazwę symbolu — jeden dobry
Grep znajduje odpowiedź szybciej, niż agent zdąży sformułować i rozebrać zapytanie do grafu.
Rozmiar repo nie jest więc jedynym czynnikiem — liczy się też, czy Grep i tak by wystarczył.
Wniosek wpisany do `docs/code-map.md` → „Kiedy się opłaca”.

### Werdykt wg kryterium utrzymania

> Kryterium: *na `notes-app` jakość bez spadku i koszt w granicach szumu; na repo średnim spadek
> kosztu `init --detect` i `explore` o co najmniej 15% przy tej samej jakości.*

**Spełniony na repo średnim — dla wszystkich trzech promptów protokołu.** Na `notes-app` koszt
rośnie (+19% `explore`, +17% `wiki`) — pierwsza część kryterium formalnie nie przechodzi, zgodnie
z przewidywaniem w dokumentacji (mały projekt nie pokazuje oszczędności, zamierzone). Na repo
średnim (`domain-driven-hexagon`, 95 plików) **wszystkie trzy** zmierzone pary przechodzą próg
`keep`: `explore` −19,1% kosztu, `init --detect` −13,9% czasu (koszt w szumie), `wiki init`
−18,4% kosztu — kryterium „≥15% na `init --detect` i `explore`” jest więc spełnione, a `wiki
init` (poza formalnym kryterium) wypada tak samo dobrze.

**Ale nie bezwarunkowo:** na większym, prywatnym repo (~500 plików, tylko zagregowane liczby —
patrz niżej) ten sam `explore` wypadł **drożej** (+8,8% kosztu, +22,8% czasu) dla pytania, które
miało unikalną, łatwo grepowalną nazwę symbolu. Rozmiar repo nie jest więc jedynym czynnikiem —
liczy się też, czy pytanie wymaga przeskoku przez kilka zależności, czy jeden dobry Grep i tak
wygrywa. Ta zasada jest teraz wpisana do `docs/code-map.md` → „Kiedy się opłaca”.

**Rekomendacja:** integrację **zostawiam** (nie wycofuję promptów) — dowód na repo średnim jest
pełny (3 z 3 promptów `keep`), a kontrprzykład z większego repo nie jest wadą mechanizmu, tylko
potwierdzeniem, że graf pomaga selektywnie — co jest teraz udokumentowane dla użytkownika, nie
ukryte. Gałąź zostaje nie zmergowana do `main` do decyzji użytkownika.
