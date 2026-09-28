---
description: Inicjalizacja projektu SDD — wypełnienie ai/docs/ (stack, wzorce, konwencje) + Makefile
argument-hint: [--detect | --manual]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:init — Inicjalizacja projektu SDD

**Cel:** Skonfiguruj projekt do pracy z SDD Framework — wypełnij `ai/docs/` na podstawie istniejącego kodu lub wywiadu.

> Nie mylić z wbudowanym `/init` Claude Code (generuje `CLAUDE.md`) — ta komenda wypełnia `ai/docs/`.

```
/regent:init [--detect | --manual]

Przykład:
/regent:init --detect        (auto-skanowanie repo)
/regent:init --manual        (interaktywny wywiad)
/regent:init                 (domyślnie: --detect)
```

---

## Agent (delegacja — WYMAGANE)

Skanowanie repo i przygotowanie treści `ai/docs/` deleguj do subagenta `regent:architect`
(model: opus, uruchom narzędziem Task). Nie rób tego „w miejscu" w głównej sesji —
inaczej model z `agents/architect.md` nie zostanie użyty.

**Kontrakt:** `regent:architect` jest read-only — **zwraca treść plików `ai/docs/` w raporcie**;
sesja główna prezentuje wyniki (Krok 4) i po zatwierdzeniu zapisuje pliki. Wywiad
w trybie `--manual` prowadzi sesja główna i przekazuje odpowiedzi w prompcie.

---

## Krok 0: Sprawdź czy ai/docs/ już istnieje

```
Jeśli ai/docs/stack/technology.md istnieje i nie jest pusty:
  → "Projekt już zainicjalizowany. Użyj /regent:revise aby zaktualizować ai/docs/."
  → STOP (chyba że user potwierdzi reinicjalizację)
```

---

## Krok 0.5: `ai/` poza repo produktu

`ai/` to osobisty warsztat pracy z AI — każdy ma swój styl, więc katalog nie trafia do repo
produktu (konwencja frameworka). Sprawdź: `git check-ignore -q --no-index ai/` (`--no-index`:
wynik zależy od reguł ignore, nie od tego, czy coś w `ai/` jest już śledzone)
- ignorowany (exit 0) → dalej;
- nieignorowany → zaproponuj (`AskUserQuestion`) dopisanie `/ai/` do globalnego excludes:
  plik z `git config --global core.excludesfile` (brak → utwórz `~/.gitignore_global` i ustaw
  go tą komendą). `/ai/` kotwiczy do korzenia repo — katalogi `ai/` w kodzie (np. `src/ai/`)
  zostają śledzone. Pliki już śledzone w `ai/` git śledzi dalej; ich wyjęcie (`git rm --cached`)
  zmienia repo całego zespołu, więc to osobna decyzja użytkownika.

---

## Krok 1: Wykryj istniejące pliki (--detect)

Deleguj do subagenta `regent:architect` — skanuje repo i w raporcie proponuje też 3 małe (S)
kandydatów na pierwszą zmianę: TODO/FIXME/HACK, moduły bez testów, połknięte wyjątki:

```bash
# Package manager & dependencies
cat package.json 2>/dev/null || cat requirements.txt 2>/dev/null || cat go.mod 2>/dev/null || cat Cargo.toml 2>/dev/null

# TypeScript config
cat tsconfig.json 2>/dev/null

# Linter / Formatter
cat .eslintrc* 2>/dev/null || cat .prettierrc* 2>/dev/null

# Docker
cat Dockerfile 2>/dev/null || cat docker-compose.yml 2>/dev/null

# Existing structure
find src/ -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" \) 2>/dev/null | head -50

# Frontend? (deps UI w package.json, config bundlera, pliki komponentów, monorepo workspaces)
grep -E '"(react|vue|svelte|@angular/core|solid-js)"' package.json 2>/dev/null
ls index.html vite.config.* next.config.* nuxt.config.* astro.config.* 2>/dev/null
find src apps packages -maxdepth 4 \( -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" \) 2>/dev/null | head -10

# CI/CD / deployment? (pipeline, konteneryzacja)
ls .github/workflows/ .gitlab-ci.yml Jenkinsfile .circleci/ 2>/dev/null

# Git history (last 20 commits for context)
git log --oneline -20 2>/dev/null

# Existing tests
find . \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | head -20

# Kandydaci na pierwszą zmianę (onboarding)
grep -rnE "TODO|FIXME|HACK" src/ 2>/dev/null | head -20
```

### Wykrywane elementy:

| Element | Źródło | Cel |
|---------|--------|-----|
| Runtime & language | package.json, tsconfig | `stack/technology.md` |
| Framework | dependencies | `stack/technology.md` |
| Architecture | folder structure, imports | `patterns/architecture.md` |
| Reference implementations | egzemplarze kluczowych wzorców w kodzie (consumer, event+handler, repo) | `patterns/architecture.md` (sekcja Reference Implementations) |
| Naming | existing files, code | `conventions/naming.md` |
| Code style | eslint, prettier config | `conventions/code-style.md` |
| Git workflow | git log, branches | `conventions/git-workflow.md` |
| Testing | test files, jest config | `patterns/testing-patterns.md` |
| DI patterns | imports, constructors | `patterns/di-patterns.md` |
| Logging | logger imports (pino/winston/CustomLoggerService), LoggerModule | `patterns/logging-patterns.md` |
| Frontend | deps UI, config bundlera, pliki `*.tsx/*.vue/*.svelte`, workspaces, narzędzie testów UI | `stack/technology.md` (sekcja Frontend) + `patterns/frontend-patterns.md` |

---

## Krok 1-alt: Wywiad (--manual)

Jeśli `--manual` lub repo jest puste:

### Runda 1: Stack
```
1. Jaki runtime i język? (Node.js + TypeScript, Python, Go, ...)
2. Jaki framework backend? (NestJS, Express, FastAPI, ...)
3. Jaka baza danych? (PostgreSQL, MySQL, MongoDB, ...)
4. Package manager? (npm, pnpm, yarn)
5. Czy projekt ma frontend? Jaki framework i bundler? (React+Vite, Next, Vue, ... / brak)
```

Jeśli frontend = tak — mini-runda uzupełniająca:
```
1. State management? (server-state + globalny klient)
2. Styling i biblioteka komponentów?
3. Testy komponentowe / E2E przeglądarkowe? (narzędzia)
```

### Runda 2: Architecture
```
1. Typ architektury? (Modular Monolith, Microservices, Monolith)
2. Struktura warstw? (Domain/Application/Infrastructure/Interface)
3. DI container? (NestJS built-in, InversifyJS, manual)
4. Error handling pattern? (custom exceptions, HTTP errors)
```

### Runda 3: Conventions
```
1. Nazewnictwo plików? (kebab-case, camelCase, PascalCase)
2. Nazewnictwo w kodzie? (camelCase vars, PascalCase classes)
3. Formatter/Linter? (Prettier, ESLint, ...)
4. Git branching? (trunk-based, gitflow, ...)
5. Commit format? (conventional commits, custom)
```

**Wywiad prowadzi SESJA GŁÓWNA — czekaj na odpowiedzi użytkownika po każdej rundzie,
potem przekaż komplet odpowiedzi subagentowi `regent:architect`.**

---

## Krok 2: Generuj ai/docs/

Na podstawie detekcji lub wywiadu, wypełnij:

### WYMAGANE (zawsze generowane):
1. `ai/docs/stack/technology.md` — stos technologiczny
2. `ai/docs/patterns/architecture.md` — wzorce architektoniczne
   (w tym sekcja **Reference Implementations**: dla każdego wzorca z tabeli Key Patterns
   architekt wskazuje 1-2 realne, wzorcowe implementacje w kodzie — pełne ścieżki od `src/`
   + 1 zdanie. To pozwala późniejszym komendom czytać wskazany plik zamiast skanować `src/`.
   Sekcja **Zasady nienegocjowalne**: tylko reguły już egzekwowane — reguły lintera, bramki CI,
   ADR-y; nic takiego nie wykryto → sekcję usuń.)
3. `ai/docs/conventions/naming.md` — konwencje nazewnictwa
4. `ai/docs/conventions/code-style.md` — styl kodu
5. `ai/docs/conventions/git-workflow.md` — git workflow

### OPCJONALNE (generowane jeśli wykryto):
6. `ai/docs/patterns/di-patterns.md` — wzorce DI
7. `ai/docs/patterns/testing-patterns.md` — wzorce testowania
8. `ai/docs/patterns/exception-patterns.md` — obsługa wyjątków
9. `ai/docs/patterns/logging-patterns.md` — wzorzec logowania (źródło prawdy dla `/regent:logging`)
10. `ai/docs/patterns/frontend-patterns.md` — wzorce frontendu (źródło prawdy dla `regent:frontend-dev`;
    generowany TYLKO gdy wykryto frontend; wtedy też wypełnij sekcję Frontend w technology.md —
    w projektach backend-only sekcję usuń)
11. `ai/docs/domain/glossary.md` — słownik języka domeny (terminy, relacje, rozstrzygnięte
    niejednoznaczności). Generuj, gdy z nazw modułów/encji w `src/` wyłania się **realne
    słownictwo domenowe** (min. 3 terminy, których znaczenia nie da się odgadnąć z samej nazwy),
    albo gdy użytkownik podał je w wywiadzie. W projekcie czysto technicznym (biblioteka, CLI,
    narzędzie) pomiń — **pusty glosariusz szkodzi bardziej niż jego brak**: kosztuje kontekst
    przy każdym czytaniu i zachęca do wrzucania tam decyzji implementacyjnych.

**Wypełniaj z szablonów** `${CLAUDE_PLUGIN_ROOT}/templates/docs/` (jeden szablon = jeden plik `ai/docs/`) — podmieniaj placeholdery wykrytymi wartościami, nie kopiuj placeholderów.

> ❗ `logging-patterns.md`: NIE scaffolduj kodu loggera (to zakres `/regent:logging`, nie `/regent:init`).
> Gdy wykryto logger → opisz jego ścieżkę i API w szablonie. Gdy NIE wykryto → wygeneruj plik
> ze statusem „do wdrożenia”, aby `/regent:logging` wiedział, że brak standardu.

### NIE generowane przez /regent:init (opcjonalne, autorskie):
- `ai/docs/observability/` (dashboardy/alerty Kibany, `maintenance.md`) — zbyt środowiskowe
  (index patterns, webhooki Slacka). Tworzone ręcznie w razie potrzeby. Jeśli istnieje,
  `logging-patterns.md` powinien do niego linkować (sekcja „Synchronizacja z observability”).

---

## Krok 3: Generuj Makefile

Na podstawie wykrytego stacku skopiuj i wypełnij odpowiedni szablon:

| Stack | Szablon |
|---|---|
| Node.js / TypeScript | `${CLAUDE_PLUGIN_ROOT}/templates/Makefile.node.template` |
| Inny stack (Python, Go, Rust, …) | brak szablonu → wygeneruj Makefile ręcznie z tym samym zestawem celów: `install`, `lint`, `type-check`, `format`, `test`, `test-unit`, `test-integration`, `test-coverage`, `check`, `build`, `deps-outdated`, `deps-audit` — używając narzędzi wykrytego stacku (np. `pytest`, `ruff`, `go test`, `cargo test`) |

Cele Makefile to **kontrakt frameworka** — komendy (`/regent:apply`, `/regent:verify`, `/regent:commit`,
`/regent:dependency-update`) wołają `make …`, nie surowe narzędzia stacku.

Podmień w szablonie:
- `PKG_MANAGER` — wykryty package manager (`npm` / `pnpm` / `yarn`)
- Sekcja Database — odkomentuj blok pasujący do wykrytego ORM (Prisma / TypeORM / inne)
- Sekcja Frontend — odkomentuj cel `test-component`, gdy wykryto frontend

Zapisz jako `Makefile` w katalogu głównym projektu.

Jeśli `Makefile` już istnieje → NIE nadpisuj: zaproponuj brakujące cele jako diff do dopisania.

---

## Krok 3.5: Barierki git w projekcie

Reguły „`git add` wyłącznie z listą plików" i „bez `--no-verify`" żyją w promptach, a egzekwuje je
deterministycznie hook `scripts/hooks/git-guard.sh`, **rejestrowany przez plugin** (`hooks/hooks.json`):
blokuje `git add .` / `-A` / `--all` / `-u`, `git commit -a` i `--no-verify`, a agentowi mówi, co
zrobić zamiast tego. Działa w każdym projekcie z `ai/docs/`, więc od zapisu plików w Kroku 4 chroni
także ten projekt — bez wpisu w jego `.claude/settings*.json` i bez pytania o zgodę.

Sprawdź tylko, czy projekt nie ma starego wpisu hooka wskazującego `$HOME/.claude/scripts/hooks/`
(sprzed pluginu) w `.claude/settings.json` lub `.claude/settings.local.json`. Jest → zaproponuj
jego usunięcie (dubluje hook pluginu, a po usunięciu frameworka z `~/.claude` nic nie robi).

## Krok 4: Prezentacja i zatwierdzenie

```markdown
## Inicjalizacja SDD — Wyniki

### Wypełnione pliki:
✅ ai/docs/stack/technology.md
✅ ai/docs/patterns/architecture.md
✅ ai/docs/conventions/naming.md
✅ ai/docs/conventions/code-style.md
✅ ai/docs/conventions/git-workflow.md
⬜ ai/docs/patterns/di-patterns.md (opcjonalny — nie wykryto)
✅ ai/docs/patterns/testing-patterns.md
⬜ ai/docs/patterns/exception-patterns.md (opcjonalny — nie wykryto)
⬜ ai/docs/domain/glossary.md (opcjonalny — brak słownictwa domenowego)
✅ ai/docs/patterns/logging-patterns.md (wykryto: nestjs-pino)
⬜ ai/docs/patterns/frontend-patterns.md (opcjonalny — nie wykryto frontendu)
✅ Makefile (Node.js, pnpm, Prisma)
✅ git-guard — hook pluginu aktywny (projekt ma ai/docs/); stary wpis w .claude/settings*.json: brak / usunięty

### Podsumowanie:
- Runtime: Node.js 20 + TypeScript 5.3
- Framework: NestJS 10
- Database: PostgreSQL 16
- Architecture: Modular Monolith, 4 warstwy

### Kandydaci na pierwszą zmianę (do przećwiczenia cyklu):
| # | Kandydat | Źródło | Rozmiar | Komenda |
|---|----------|--------|---------|---------|
| 1 | [np. walidacja email w rejestracji] | [TODO w src/…:42] | S | `/regent:propose …` |
| 2 | [np. moduł bez testów] | [brak testów w src/…] | S | `/regent:testing …` |
| 3 | [np. połknięty wyjątek] | [pusty catch w src/…:88] | S | `/regent:bugfix …` |

Czy zatwierdzasz? (tak/nie/popraw [plik])
```

**Czekaj na zatwierdzenie.** Po `tak` → sesja główna zapisuje pliki `ai/docs/` + `Makefile`
z treści zwróconej przez `regent:architect`. `popraw [plik]` → kontynuuj tego samego subagenta
z poprawkami.

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Skanuj repo PRZED generowaniem
- Prezentuj wyniki DO zatwierdzenia
- Wypełniaj szablony konkretnymi wartościami (nie placeholderami)
- Oznacz co wykryto automatycznie, a co wymaga weryfikacji
- Wartości niepewne → zapytaj użytkownika
- Istniejący, wypełniony plik → potwierdzenie przed nadpisaniem

---

## Następne kroki po /regent:init

```
→ /regent:propose "pierwsza zmiana"
→ /regent:status (przegląd stanu)
```

Timeline: 10-20 minut
