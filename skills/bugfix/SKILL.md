---
description: Strukturalna naprawa buga w dev/staging — reprodukcja, root cause, test regresji
argument-hint: <opis-buga>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:bugfix — Regularna naprawa buga

**Cel:** Strukturalna naprawa buga z reprodukcją, root cause analysis, i testem regresji.

```
/regent:bugfix <opis-buga>

Przykład:
/regent:bugfix "users can register with duplicate email"
/regent:bugfix "login redirect loop on expired session"
```

---

## Agent (delegacja — WYMAGANE)

Analizę root cause, test regresji i minimalny fix deleguj do dev-agenta **wg obszaru buga**:
kod backendu → `regent:backend-dev`, kod frontendu → `regent:frontend-dev` (wymaga `frontend-patterns.md`);
bug na styku → najpierw ustal, po której stronie jest root cause i napraw po JEDNEJ stronie;
gdy naprawdę obie → dwie delegacje, BE najpierw. Subagent sam uruchamia testy (wąsko)
i zwraca raport — **commituje sesja główna**. Opcjonalny `/regent:verify` deleguje własnych subagentów.

---

## Krok 1: Analiza buga

```
## Bug Analysis

### Opis
[Co się dzieje vs co powinno się dziać]

### Severity
- 🔴 CRITICAL — system down, data loss, security breach
- 🟡 HIGH — feature broken, workaround exists
- 🟢 MEDIUM — minor issue, edge case
- 🔵 LOW — cosmetic, minor inconvenience

### Impact
- Users affected: [all/some/few]
- Frequency: [always/sometimes/rare]
- Workaround: [exists/none]

### Root Cause Hypothesis
[Wstępna hipoteza — co może być przyczyną]
```

---

## Krok 2: Zlokalizuj plik z bugiem (celowo, nie przez skan)

Użyj precyzyjnych narzędzi zamiast szerokiego skanu:

```bash
# Szukaj po słowie kluczowym z opisu buga (rozszerzenia plików wg stacku z technology.md)
grep -r "registerUser\|duplicate.*email" src/ -l

# Lub przez historię git
git log --oneline --all -20
git log --oneline -- src/modules/users/

# Następnie: Read tylko znaleziony plik — NIE skanuj całego src/
```

**Reprodukcja:**
```
Kroki:
1. [Step 1]
2. [Step 2]

Expected: [co powinno się stać]
Actual: [co się dzieje]
```

> **Wejście z `/regent:debugging`:** gdy diagnoza szła tamtędy, masz już komendę pętli czerwoną
> na tym bugu — użyj jej zamiast budować reprodukcję od nowa.

**Napisz failing test reprodukujący buga:**
```bash
# Test MUSI failować — potwierdza bug
make test-unit
```

**Zminimalizuj go, zanim przejdziesz dalej.** Tnij po jednym elemencie (pole payloadu, krok
setupu, zależność); gotowe, gdy **każdy pozostały element jest nośny** — usunięcie
któregokolwiek sprawia, że test przechodzi. Minimalny test celuje w przyczynę zamiast
w scenariusz, w którym bug został zauważony, i to on zostaje w repo jako test regresji.

---

## Krok 3: Minimalne artefakty

Utwórz lekką propozycję (uproszczone wersje szablonów z `${CLAUDE_PLUGIN_ROOT}/templates/`):

```
ai/changes/fix-{nazwa}/
├── proposal.md (uproszczony — tylko: problem, root cause, fix; Status: Approved po zgodzie usera)
├── specs/{domena}.md (delta — MODIFIED pełnym blokiem REQ z AC na poprawne zachowanie;
│                      zachowanie bez specyfikacji w ai/specs/ → ADDED)
├── design.md (uproszczony — root cause, Affected Files, podejście; wymagany przez /regent:verify)
└── tasks.md (2-5 tasków max)
```

---

## Krok 4: Implementacja

```bash
# Branch
git checkout -b fix/{KEY}-{short-description}

# Fix (deleguj → backend-dev LUB frontend-dev — wg obszaru root cause z Kroku 2):
# 1. Napisz failing test (reprodukcja) i uruchom — musi failować
# 2. Napraw bug (minimalnie!)
# 3. Verify: test przechodzi
# 4. Verify: testy modułu nadal przechodzą

# Commit (SESJA GŁÓWNA, po raporcie z potwierdzonym GREEN) — tylko kod i testy (ai/ jest lokalny);
# po commicie ślad przy tasku jak w /regent:apply 4c: (commit: <hash> · testy: <test regresji>)
git add [specific files]
git commit -m "fix: (KEY) prevent duplicate email registration"
```

---

## Krok 5: Weryfikacja

```bash
make check   # brak Makefile → natywny odpowiednik ze stacku (kontrakt `make` w CLAUDE.md)
```

**Odtwórz oryginalny symptom** — kroki reprodukcji z Kroku 2 wykonane na kodzie po fixie.
Test regresji sprawdza przyczynę; reprodukcja sprawdza, że użytkownik przestał widzieć błąd.

| Wynik | Kiedy | Verdict w verification.md |
|---|---|---|
| **verified** | symptom nie występuje, test regresji i `make check` zielone | PASS |
| **partial** | symptom zniknął, ale reprodukcji nie dało się wykonać w pełni albo wyszły niezwiązane regresje | FAIL + czego nie potwierdzono |
| **failed** | symptom wciąż występuje albo fix psuje testy | FAIL → wróć do Kroku 2 z nowymi obserwacjami |

Zielone testy bez wykonanej reprodukcji to najwyżej **partial**. Archiwizacja przy partial
to decyzja użytkownika (`/regent:archive --force`, wpis UNVERIFIED).

Zapisz `ai/changes/fix-{nazwa}/verification.md` (wymagane przez /regent:archive):
- uproszczony: verdict + wynik reprodukcji (verified/partial/failed) + test regresji (plik:linia)
  + data + commit HEAD
- dla ważniejszych bugów (HIGH/CRITICAL): pełny `/regent:verify fix-{nazwa}`

---

## Krok 6: Archive

Po merge — **przez `/regent:archive fix-{nazwa}`** (NIE gołe `mv`!):
delta spec z Kroku 3 musi zostać zmergowana do `ai/specs/{domena}.md`,
inaczej main specs rozjeżdżają się z kodem przy każdym bugu.

---

## WAŻNE

- **Reproduce first** — failing test PRZED fixem
- **Minimal fix** — napraw bug, nie refaktoruj
- **Root cause** — nie łataj symptomów
- **Regression test** — test musi zostać na zawsze
- **Zamknięcie przez /regent:archive** — merge delty do main specs to sens SDD

Timeline: 30-60 minut
