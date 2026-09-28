---
description: Przegląd stanu projektu SDD — konfiguracja, aktywne zmiany, „gdzie jestem" po przerwanej sesji, archiwum, specyfikacje
argument-hint: [--drift]
allowed-tools: Read, Grep, Glob, Bash(ls:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh:*)
---

# /regent:status — Przegląd stanu projektu

**Cel:** Pokaż aktualny stan projektu: konfiguracja, aktywne zmiany (z etapem cyklu — „gdzie jestem"),
archiwum, specyfikacje.

```
/regent:status            # przegląd
/regent:status --drift    # + audyt: kod zmieniony poza cyklem SDD po archiwizacji
```

---

## Agent (delegacja)

Bez delegacji — świadomie. To czysty odczyt: sprawdzenie istnienia plików `ai/docs/`,
`ls` aktywnych zmian/archiwum/speców i heurystyczne sugestie. Brak rozumowania, które
model agenta mógłby ulepszyć; ma być natychmiastowy. Działa w głównej sesji.

---

## Krok 1: Konfiguracja

```
## Konfiguracja SDD

### ai/docs/ (wymagane):
✅ / ❌ ai/docs/stack/technology.md
✅ / ❌ ai/docs/patterns/architecture.md
✅ / ❌ ai/docs/conventions/naming.md
✅ / ❌ ai/docs/conventions/code-style.md
✅ / ❌ ai/docs/conventions/git-workflow.md

### ai/docs/ (opcjonalne):
✅ / ⬜ ai/docs/patterns/di-patterns.md
✅ / ⬜ ai/docs/patterns/testing-patterns.md
✅ / ⬜ ai/docs/patterns/exception-patterns.md
✅ / ⬜ ai/docs/patterns/logging-patterns.md
✅ / ⬜ ai/docs/patterns/frontend-patterns.md (tylko projekty z frontendem)
✅ / ⬜ ai/docs/adr/ (opcjonalne — ADR-y architekta; nie z /regent:init)
✅ / ⬜ ai/docs/observability/ (autorskie — dashboardy/alerty Kibany; nie z /regent:init)

### Status: CONFIGURED / PARTIALLY CONFIGURED / NOT CONFIGURED

Jeśli NOT CONFIGURED → "Uruchom /regent:init"
```

---

## Krok 2: Aktywne zmiany

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh status      # jedna linia na aktywną zmianę: Status, taski x/y, werdykt weryfikacji
```
Liczby w tabeli bierz z wyniku skryptu — nie licz checkboxów sam.

```
## Aktywne zmiany

| Zmiana | Typ | Tasks | Status |
|--------|-----|-------|--------|
| user-registration | feature | 4/5 done | 🟡 In Progress |

Szczegóły:
### user-registration (4/5 tasks)
- [x] T-01: Create user entity
- [x] T-02: Create user repository
- [ ] T-05: [BE] E2E rejestracji — REQ-001, REQ-002 — weryfikacja: test E2E zielony

→ /regent:apply user-registration --tasks 5
```

Jeśli brak aktywnych zmian:
```
Brak aktywnych zmian.
→ /regent:propose — utwórz nową zmianę
```

---

## Krok 3: Archiwum

```bash
ls ai/changes/archive/
```
(pokaż 5 najnowszych — sortowanie po prefiksie daty w nazwie katalogu)

```
## Archiwum (ostatnie 5)

| Data | Zmiana | Typ |
|------|--------|-----|
| 2025-03-18 | setup-project-structure | feature |
| 2025-03-15 | initial-auth | feature |
```

---

## Krok 3.7: Gdzie jestem? (wykrywanie stanu zmiany)

Dla KAŻDEJ aktywnej zmiany ustal etap cyklu **z plików na dysku** — bez osobnego pliku stanu.
To ratunek po przerwanej sesji: użytkownik nie musi pamiętać, na czym skończył.

| Sygnał na dysku | Etap | Następny krok |
|---|---|---|
| brak `proposal.md` | zmiana niekompletna | `/regent:propose {nazwa}` od nowa (lub usuń katalog) |
| `Status: Draft` | propozycja czeka na akceptację | przeczytaj pliki → `zatwierdzam` w `/regent:propose` |
| `Status: Rejected` | odrzucona na etapie propozycji | `/regent:archive {nazwa} --abandon` lub `/regent:propose` z nowym podejściem |
| `Status: Approved`, 0 tasków `[x]` | gotowe do implementacji | `/regent:apply {nazwa}` |
| część tasków `[x]` | implementacja w toku | `/regent:apply {nazwa} --tasks {pierwszy nieodhaczony}` |
| wszystkie `[x]`, brak `verification.md` | zaimplementowane, niezweryfikowane | `/regent:verify {nazwa}` |
| `verification.md` = FAIL | weryfikacja oblana | patrz „Ścieżka FAIL" w `/regent:verify` (rezygnacja → `/regent:archive {nazwa} --abandon`) |
| `verification.md` = PASS | gotowe do zamknięcia | `/regent:archive {nazwa}` |

**Dryf kodu wobec weryfikacji (miękkie ostrzeżenie):** gdy `verification.md` ma PASS,
uruchom `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh drift {nazwa}`. WARN (plik z Affected Files zmieniony od `Commit HEAD`) →
„⚠️ kod zmiany ruszył się po weryfikacji — rozważ re-run `/regent:verify {nazwa}`".

**Przerwany task (najczęstszy przypadek po przerwanej sesji):** task odhaczasz dopiero po
commicie (`/regent:apply` 4c), więc dla pierwszego nieodhaczonego taska sprawdź dwa stany:
```
⚠️ {nazwa}: T-04 — jest commit po ostatnim zapisanym (commit: …), który dotyka plików taska
   → commit się udał, brakuje śladu: dopisz ✅ (commit: … · testy: …) zamiast powtarzać task.
⚠️ {nazwa}: T-04 — niezacommitowane zmiany w plikach z Affected Files (git status)
   → praca w toku: dokończ task (testy zielone) i commit, zamiast zaczynać od nowa.
```

---

## Krok 3.8: Rozjazd speców z kodem (tylko `/regent:status --drift`)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh stale      # commity ruszające pliki zarchiwizowanych zmian, nieobecne w żadnym tasks.md
```
Każdy WARN to kod zmieniony poza Twoim cyklem SDD — hotfix bez follow-upu, ręczna poprawka
albo praca kolegi (`ai/` jest osobisty, więc ich commity też tu trafią). Twój main spec domeny
mógł przestać opisywać prawdę → zaktualizuj go (`/regent:propose` na zmianę zachowania,
`/regent:bugfix` na błąd). Squash bez klucza ticketu skrypt rozpoznaje po zawartości plików —
gdy lokalne hashe cyklu zniknęły (gc, inna maszyna), WARN bywa fałszywy. Bez flagi `--drift`
pomiń ten krok (to audyt, nie odczyt).

## Krok 4: Specyfikacje

```bash
ls ai/specs/ 2>/dev/null
```

```
## Specyfikacje

| Domena | Plik | Ostatnia zmiana |
|--------|------|----------------|
| Users | ai/specs/users.md | 2025-03-18 |
| Auth | ai/specs/auth.md | 2025-03-15 |
```

---

## Krok 5: Sugestie

```
## Sugestie

Na podstawie stanu projektu:
1. [sugestia — np. "user-registration ma 1 pending task → /regent:apply"]
2. [sugestia — np. "ai/docs/patterns/testing-patterns.md puste → uzupełnij"]
```

---

Timeline: 1-2 minuty
