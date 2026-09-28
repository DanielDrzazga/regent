---
description: Pisanie testów (unit, integration, E2E) i weryfikacja pokrycia przez qa-engineer
argument-hint: [unit|integration|e2e|coverage] [target]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:testing — Pisanie i uruchamianie testów

**Cel:** Napisz testy (unit, integration, E2E) i zweryfikuj pokrycie.

```
/regent:testing [target]

Przykład:
/regent:testing src/modules/users/
/regent:testing unit src/services/auth.service.ts
/regent:testing integration api/users
/regent:testing e2e user-registration
/regent:testing coverage
```

---

## Agent (delegacja — WYMAGANE)

Pisanie testów, dobór helperów i analizę pokrycia deleguj do subagenta `regent:qa-engineer`
(model: sonnet, uruchom narzędziem Task). Nie rób tego „w miejscu" w głównej sesji —
inaczej model z `agents/qa-engineer.md` nie zostanie użyty.

---

## Krok 1: Przeczytaj strategię testów

```
Przeczytaj (kontekstowo):
- ai/docs/patterns/testing-patterns.md
- ai/docs/stack/technology.md (tylko sekcja Testing)
- ${CLAUDE_PLUGIN_ROOT}/templates/test-plan-template.md (dla złożonych zmian — sformalizuj plan
  testów, zapis do ai/changes/{nazwa}/test-plan.md)
```

---

## Krok 2: Napisz testy (subagent `regent:qa-engineer`)

Piramida testów, targety pokrycia, mocks-first, seamy, anty-wzorce, struktura `tests/helpers/`
i zasady testów UI są w definicji agenta `regent:qa-engineer` — **jedno źródło**. Narzędzia UI bierz
z `frontend-patterns.md`; brak tego pliku przy tasku UI → `OPEN QUESTIONS`.

Dla wskazanego target:
0. **Wypisz seamy pod testem** (definicja i kryteria: `regent:qa-engineer`) — niepewny seam trafia
   do `OPEN QUESTIONS`, zanim powstanie pierwszy test
1. Zidentyfikuj co testować (AC, edge cases, error paths)
2. Sprawdź istniejące helpers, ZANIM napiszesz nowy mock/factory
3. Napisz testy w odpowiednim typie (unit / integration / component / E2E)
4. Brakujące helpers utwórz w `tests/helpers/` — nie inline

---

## Krok 3: Uruchom testy (subagent `regent:qa-engineer`)

```
Subagent uruchamia sam:
→ make test-unit / make test-integration   # wąsko — to, co napisał/zmienił
→ make test-coverage                       # gdy weryfikuje pokrycie

Pełny make check to bramka /regent:verify — nie po każdej iteracji.
```

---

## Krok 4: Weryfikuj pokrycie

```
## Coverage Report

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Statements | ≥80% | 85% | ✅ |
| Branches | ≥75% | 72% | ⚠️ |
| Functions | ≥80% | 88% | ✅ |
| Lines | ≥80% | 84% | ✅ |

Uncovered:
- src/users/service.ts:45-52 (error handling path)
```

---

Timeline: 1-3 godziny
