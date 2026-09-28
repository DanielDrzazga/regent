---
description: Atomic commity zgodnie z git workflow (format, pre-commit checks, zatwierdzenie)
argument-hint: [description]
allowed-tools: Read, Grep, Glob, Bash
---

# /regent:commit — Przygotuj i wykonaj commity

**Cel:** Przygotuj i wykonaj atomic commit(y) zgodnie z git workflow.

```
/regent:commit [description]

Przykład:
/regent:commit
/regent:commit "add user registration"
```

---

## Agent (delegacja)

Bez delegacji — świadomie. To operacja git (lint/format, `git add`, format i wykonanie
commita) i żaden z subagentów jej nie ulepsza. Higienę kodu pokrywają `/regent:code-review`
i Etap 3 w `/regent:verify`. Cała komenda działa w głównej sesji, z zatwierdzeniem użytkownika.

---

## Krok 1: Pobierz Jira key z brancha

```bash
git branch --show-current
```

Format brancha: `<type>/<JIRA-KEY>-<nazwa>`
Przykład: `feat/PROJ-123-http-error-handling`

**Jeśli branch nie zawiera klucza:**
→ Weź pole `Ticket` z `proposal.md` zmiany, której dotyczy commit (`ai/changes/{nazwa}/`).
→ Brak i tam → zapytaj: "Jaki Jira key dla tego commita? (lub NONE jeśli brak)"

---

## Krok 2: Pre-commit checks

### 2a. Linting
```bash
make lint
```

Jeśli failuje → napraw, potem retry.

### 2b. Code quality
```bash
make type-check
make format
make test        # ← twarda bramka: CLAUDE.md „Nie commituj bez testów — nawet w hotfixie"
```

Brak `Makefile` / celu → natywny odpowiednik ze stacku (kontrakt `make` w CLAUDE.md);
powiedz jawnie, czego użyłeś. `make test` failuje → **STOP**, nie commituj.

### 2c. Manual review checklist
```
□ No console.log left (debug code)?
□ No commented code?
□ No hardcoded secrets?
□ No .env files staged?
□ No generated files staged?
□ Każdy staged plik z kodem produkcyjnym ma test w TYM commicie?
   → nie ma: powiedz to użytkownikowi i uzasadnij wyjątek (config, docs, czysta
     zmiana formatowania) albo dopisz test. Nie przemilczaj braku.
```

---

## Krok 3: Show status

```bash
git status
git diff --stat
```

---

## Krok 4: Zaproponuj atomic commits

**Jeden commit = jedna logiczna zmiana:**

```
Zamiast:
  git commit -m "feat: add user management"
  (50 changed files)

Rozbij na:
  1. feat: (PROJ-123) add user entity and repository
  2. feat: (PROJ-123) add registration use case
  3. test: (PROJ-123) add user registration tests
  4. docs: (PROJ-123) update API documentation
```

Pokaż plan commitów użytkownikowi. **Czekaj na zatwierdzenie.**

---

## Krok 5: Commit format

Przeczytaj `ai/docs/conventions/git-workflow.md` jeśli istnieje.

**Format:**
```
<type>: (<JIRA-KEY>) <opis, imperatyw>
```

**Twarde limity:**
- **Cała linia commita: max 100 znaków** (łącznie z `type`, kluczem i opisem).
- **Jedna linia — BEZ body.** Nie dodawaj bloku opisu/detali pod tematem.
- Jeśli zmiana wymaga długiego opisu → to sygnał, że commit jest za duży → rozbij na atomic commits.

**Typy:**
| Type | Usage |
|------|-------|
| feat | Nowa funkcjonalność |
| fix | Naprawa buga |
| hotfix | Emergency fix na produkcji (tylko z /regent:hotfix) |
| refactor | Refactoring (bez zmiany zachowania) |
| test | Dodanie/poprawka testów |
| chore | Zależności, konfiguracja, CI |
| docs | Dokumentacja |
| perf | Optymalizacja wydajności |

Gdy brak ticketu (Krok 1 → NONE): pomiń `(KEY)` — format `<type>: <opis>`.

**Przykłady:**
```
feat: (PROJ-123) add global error handling middleware
fix: (PROJ-124) prevent duplicate user registration
refactor: (PROJ-125) extract auth service to separate module
```

---

## Krok 6: Wykonaj commity

**Po zatwierdzeniu przez użytkownika:**

```bash
# Dodaj KONKRETNE pliki — wymienione z nazwy
git add src/modules/users/domain/user.entity.ts tests/users/user.entity.test.ts

# Sprawdź co dodałeś
git diff --cached --stat

# Commit
git commit -m "feat: (PROJ-123) add user entity with validation"

# Powtórz dla każdego atomic commita
```

---

## Krok 7: Verify

```bash
git log --oneline -10
```

---

## Krok 8: Push (TYLKO jeśli user prosi)

```bash
# ONLY after explicit user request
git push origin {branch-name}
```

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Atomic commits (1 commit = 1 logiczna zmiana)
- **Jedna linia, max 100 znaków**: `type: (KEY) opis` — opisowa, w formacie
- Zielony `make test` przed commitem — także w hotfixie (CLAUDE.md)
- Zgoda użytkownika przed `git commit`
  (wyjątek: per-taskowe commity w `/regent:apply` — zgoda udzielana raz, w Kroku 3 /regent:apply)
- `git push` po jawnej prośbie użytkownika

❌ **Barierki** (bez pozytywnego odpowiednika):
- `git add .` / `git add -A` — dodawaj wskazane pliki
- `git commit --no-verify` — pre-commit hooks zostają włączone

Timeline: 5-15 minut
