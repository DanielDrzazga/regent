---
description: Refactoring bez zmiany zachowania — pełny cykl propose → apply → verify → archive z INVARIANTS
disable-model-invocation: true
argument-hint: <opis>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:refactor — Refaktoryzacja i redukcja długu technicznego

**Cel:** Refaktoring kodu BEZ zmiany zachowania. INVARIANTS obowiązkowe.

```
/regent:refactor <opis>

Przykład:
/regent:refactor "extract auth service from user module"
/regent:refactor "replace raw SQL with repository pattern"
/regent:refactor "simplify order validation logic"
```

---

## Agenci (delegacja — WYMAGANE)

- Krok 2 (`/regent:propose --type refactor`) deleguje `regent:spec-writer` + `regent:architect` sam z siebie.
- Krok 4 (implementacja kroków refactoru) deleguj do dev-agenta wg obszaru:
  backend → `regent:backend-dev`, frontend → `regent:frontend-dev` (sonnet, Task).
- Krok 6 (`/regent:verify`) deleguje `regent:code-reviewer`/`regent:qa-engineer`/… sam.

Nie refaktoruj „w miejscu" w głównej sesji — inaczej modele agentów nie zostaną użyte.

---

## Krok 1: Zdefiniuj zakres

```
## Refactor Scope

### Target
[Co refaktorujemy — plik, moduł, pattern]

### Current Problem
[Dlaczego obecny kod jest problematyczny]
- [np. Code duplication, high complexity, tight coupling]

### Proposed Solution
[Jak powinno wyglądać po refactorze]

### Behavior Change: NONE ❗
[Refactor NIE zmienia zachowania — to fundamentalna zasada]
```

---

## Krok 2: Utwórz /regent:propose --type refactor

```
/regent:propose {nazwa} --type refactor
```

**KLUCZOWE:** Delta spec (`specs/{domena}.md`) MUSI zawierać sekcję INVARIANTS —
tam sprawdza ją `/regent:verify` Etap 2 (zgodnie ze `spec-template.md`):

```markdown
## INVARIANTS (obowiązkowe!)

- INV-1: All existing API endpoints return same responses
- INV-2: All existing tests pass without modification
- INV-3: Database schema unchanged
- INV-4: [specific behavior that must not change]
```

---

## Krok 3: Strategia implementacji

**Wzorzec docelowy z docs, nie ze skanu src/:** kształt do którego refaktorujesz (Repository,
Service Layer, Factory itd.) bierz z `ai/docs/patterns/architecture.md` + sekcji Reference
Implementations (wskazane, wzorcowe pliki — `Read`). Do `src/` sięgaj przez `Grep`/`Glob`
**tylko żeby ZLOKALIZOWAĆ** target refactoru i jego callsites — NIE żeby uczyć się wzorca
docelowego przez szerokie skanowanie. Brak wzorca w Reference Implementations → kandydat do
dopisania przez `/regent:revise`.

```
Zasady:
1. Małe kroki — każdy krok = working code + passing tests
2. Atomic commits — każdy commit = complete refactor step
3. Testy ZAWSZE przechodzą po każdym kroku
4. Jeśli testy failują = cofnij krok, nie naprawiaj test

Typowa sekwencja:
Step 1: Dodaj nową strukturę (obok starej)
Step 2: Przenieś logikę do nowej struktury
Step 3: Update callsites do nowej struktury
Step 4: Usuń starą strukturę
Step 5: Cleanup (imports, exports)
```

---

## Krok 4: Implementacja

```bash
# Branch
git checkout -b refactor/{JIRA-KEY}-{short-description}

# Dla każdego kroku (implementacja: backend-dev — sam uruchamia testy;
# commit: sesja główna po raporcie z potwierdzonym PASS):
# 1. Zmień kod
# 2. make test → PASS ✅
# 3. git add [specific files]
# 4. git commit -m "refactor: (KEY) step X - description"
# 5. ślad przy tasku jak w /regent:apply 4c: ✅ (commit: <hash> · testy: INV-1 → <test>)
```

---

## Krok 5: Weryfikacja

```
Checklist:
□ WSZYSTKIE istniejące testy przechodzą (nie zmodyfikowane!)
□ Zachowanie niezmienione (INVARIANTS)
□ Coverage taka sama lub lepsza
□ Performance taka sama lub lepsza
□ No new dependencies introduced (chyba że uzasadnione)
```

```bash
# Porównaj pokrycie przed i po
make test-coverage

# Porównaj zachowanie
make test  # Wszystkie testy MUSZĄ przejść BEZ modyfikacji
```

---

## Krok 6: Review & merge

```
/regent:verify {nazwa-refactora}

Dodatkowe sprawdzenie:
□ INVARIANTS zachowane?
□ Testy NIE zmodyfikowane (chyba że test był na implementację, nie zachowanie)?
□ Kod czytelniejszy po refactorze?
```

---

## Krok 7: Zamknięcie

```
/regent:archive {nazwa-refactora}
```

Refactor przechodzi PEŁNY cykl — bez archiwizacji delta spec (z INVARIANTS w archiwum)
zmiana formalnie nie istnieje. Wpis w History trafia do main spec domeny, gdy ten istnieje;
refactor z samymi INVARIANTS w domenie bez main spec zostawia ślad w archiwum i w gicie.

Taski refactoru odwołują się do INVARIANTS, które chronią: `T-02: [BE] wydziel serwis — INV-1, INV-2 — …`.

---

## Red Flags 🚩

```
🚩 Behavior change → To NIE jest refactor → użyj /regent:propose --type feature
🚩 Without tests → Ryzykowne → napisz testy NAJPIERW, potem refaktoruj
🚩 Code less clear after → Odrzuć refactor
🚩 Tests modified to pass → Prawdopodobnie zmieniłeś zachowanie
🚩 Too many files → Podziel na mniejsze refactory
```

---

## WAŻNE

- **INVARIANTS** — obowiązkowe, weryfikowane w /regent:verify
- **Testy first** — jeśli brak testów, napisz je PRZED refactorem
- **Small steps** — testy przechodzą po KAŻDYM kroku
- **No behavior change** — jedyna zasada, która jest absolutna

Timeline: 1-4 godziny
