---
description: 9-etapowa weryfikacja zmiany (testy, spec compliance, review, DB, security, smoke) + zapis verification.md
disable-model-invocation: true
argument-hint: <nazwa-zmiany>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:verify — Weryfikuj zmianę

**Cel:** 9-etapowa weryfikacja zmiany (etapy 5-8 warunkowe): testy automatyczne, spec compliance, code review, weryfikacja testów, DB, security, observability, smoke check, gotowość repo do wydania. Wynik utrwalany w `verification.md`.

```
/regent:verify <nazwa-zmiany>

Przykład:
/regent:verify user-registration
```

---

## Agenci (delegacja — WYMAGANE)

Ta komenda MUSI działać przez subagentów (uruchom je narzędziem Task), aby użyć ich modeli:

| Etap | Subagent (`name`) | Model |
|------|-------------------|-------|
| 2, 3 | `regent:code-reviewer` | opus |
| 4 | `regent:qa-engineer` | sonnet |
| 5 (jeśli DB) | `regent:dba` | sonnet |
| 6 (jeśli security) | `regent:security-auditor` | opus |

❗ Każdy etap deleguj do właściwego subagenta **po dokładnym `name`** — nie analizuj „w miejscu"
w głównej sesji, bo modele z `agents/*.md` nie zostaną wtedy użyte.

**Budżet:** S: 1-2 uruchomienia, M: 2-4, L: 4-6 (tabela w CLAUDE.md). Etapy 2 i 3 to ten sam
agent (`regent:code-reviewer`) → **jedno uruchomienie z obydwoma zadaniami**, nie dwa osobne.
Etapy warunkowe (5, 6, 8) uruchamiaj tylko przy spełnionym triggerze — nie „na wszelki wypadek".

Subagenci weryfikujący są **read-only** — nie naprawiają znalezionych problemów.

---

## Krok 0: Znajdź zmianę

Czytaj **bezpośrednio przez Read**:

```
ai/changes/{nazwa}/proposal.md
ai/changes/{nazwa}/specs/*.md
ai/changes/{nazwa}/design.md   (dla /regent:bugfix: design.md uproszczony — też wymagany)
ai/changes/{nazwa}/tasks.md

Jeśli brakuje → "Nie znaleziono zmiany. Użyj /regent:status aby zobaczyć aktywne zmiany."
```

Fakty dla Etapów 2-4 policz skryptem, zanim zdelegujesz:
```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {nazwa}   # taski x/y, AC bez taska — ERROR → Etap 9 ❌
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh diff {nazwa}     # usunięte/wyłączone testy, mniej asercji, pliki spoza Affected Files
```
`diff` bez bazy (ERROR „brak bazy") → podaj ją jawnie: `diff {nazwa} $(git merge-base HEAD <gałąź główna>)`.
Wynik `diff` przekaż w prompcie `regent:code-reviewer` i `regent:qa-engineer` jako **fakty do oceny**, nie
werdykt: edycja testu bywa uzasadniona, a plik spoza Affected Files to kandydat na `unrequested`.

**NIE skanuj src/** — pliki kodu czytaj tylko te wskazane w design.md → "Affected Files".

---

## Etap 1: Automatyczne testy (SESJA GŁÓWNA uruchamia)

```
Uruchom:
→ make lint
→ make type-check
→ make test
→ make test-coverage
```

**Jeśli COKOLWIEK failuje → STOP.**
```
❌ ETAP 1 FAILED — napraw błędy PRZED kontynuacją (patrz „Ścieżka FAIL").
```

---

## Etap 2: Spec Compliance (deleguj → `regent:code-reviewer`)

Mapowanie AC → implementacja → test (oraz tabela INVARIANTS dla refactorów) i reguła
„AC bez testu = maksymalnie ⚠️ PARTIAL" są w definicji agenta `regent:code-reviewer` —
**jedno źródło, nie duplikuj ich tutaj**. Agent zwraca obie tabele w raporcie.

---

## Etap 3: Code Review (deleguj → `regent:code-reviewer`)

Checklista (architektura, jakość, wydajność, git hygiene) jest w definicji agenta
`regent:code-reviewer` — **jedno źródło, nie duplikuj jej tutaj**. W prompcie przekaż dodatkowo
elementy zależne od projektu:

```
□ Logi wg wzorca — kluczowe operacje/błędy zalogowane (logging-patterns.md), bez PII
  (opcjonalne — tylko jeśli projekt ma ai/docs/patterns/logging-patterns.md ze statusem „wdrożony")
□ Observability sync — jeśli zmiana dodaje/zmienia/usuwa `action`, sprawdź maintenance.md
  (warunkowe — tylko jeśli istnieje ai/docs/observability/; patrz Etap 7)
```

---

## Etap 4: Test Verification (deleguj → `regent:qa-engineer`)

Checklista (piramida testów, pokrycie AC, mocks-first, coverage vs target, testy UI, flaky)
jest w definicji agenta `regent:qa-engineer` — **jedno źródło, nie duplikuj jej tutaj**.

---

## Etap 5: Database Review (deleguj → `regent:dba` — jeśli dotyczy)

```
Trigger: design.md zawiera NIEPUSTĄ sekcję "Database Changes"
(sekcje nieużywane są usuwane w /regent:propose — brak sekcji lub "brak zmian" → N/A)
```

Checklista (backward-compatibility, indeksy, klucze obce, rollback, wydajność zapytań)
jest w definicji agenta `regent:dba` — **jedno źródło, nie duplikuj jej tutaj**.

---

## Etap 6: Security Review (deleguj → `regent:security-auditor` — jeśli dotyczy)

```
Trigger: zmiana dotyka auth/uprawnień, przetwarza NOWY user input, dodaje publiczny
endpoint, dotyka danych wrażliwych, LUB (frontend) renderuje treści użytkownika w UI /
obsługuje tokeny w UI / dodaje zależności frontendowe, LUB design.md ma niepustą sekcję
"Security Considerations". Czysto wewnętrzna zmiana bez nowych wejść i czysty
styling/layout → N/A (nie odpalaj security-auditora „na wszelki wypadek" — to opus, kosztuje).
```

Checklista (OWASP Top 10 + warunkowa sekcja frontendowa) jest w definicji agenta
`regent:security-auditor` — **jedno źródło, nie duplikuj jej tutaj**.

---

## Etap 7: Observability Sync (warunkowy)

```
Trigger: istnieje ai/docs/observability/ ORAZ zmiana dodaje/zmienia nazwę/usuwa
logowaną `action` (lub zmienia `type`/`module`).

Źródło: ai/docs/observability/maintenance.md (checklista utrzymaniowa)

□ Czy zmiana dodaje / zmienia nazwę / usuwa logowaną `action`?
□ Jeśli tak — czy dashboard (kibana-dashboard.md) i alerty wymagają aktualizacji?
   (panele Filters mają listę `action` zaszytą na sztywno — nie zaktualizują się same)
□ Czy nowa krytyczna `action` błędu zasługuje na alert?
□ Czy zmiana `type`/`module` nie psuje filtrów bazowych paneli?

To refleksja, nie obowiązek pracy — jeśli żaden punkt nie dotyczy, N/A.
Brak ai/docs/observability/ → N/A.
```

---

## Etap 8: Smoke Check — czy to faktycznie działa? (warunkowy)

> **Dlaczego:** etapy 1-7 sprawdzają testy, spec, kod, DB, security i logi — ale nikt nie
> uruchamia aplikacji. Zmiana może mieć komplet zielonych testów i nie działać u użytkownika
> (zły wire-up DI, brak rejestracji route'u, zepsuty build, mock rozjechany z realnym API).
> To ostatni moment, żeby to wyłapać przed wydaniem.

```
Trigger: zmiana dotyka UI, endpointu HTTP lub uruchamialnego wejścia (CLI, worker, job).
Czysto wewnętrzny refactor bez zmiany wejść, zmiana samych testów lub dokumentacji → N/A.
```

**Zakres: happy path, nie regresja.** To NIE jest E2E — te są w Etapie 4. Tu chodzi
o jedno pytanie: czy główna ścieżka zmiany żyje w uruchomionej aplikacji.

```
□ Build przechodzi (make build — lub natywny odpowiednik)
□ Aplikacja startuje bez błędów w logach startowych
□ Scenariusz Smoke z design.md → Testing Strategy wykonany RĘCZNIE i potwierdzony
  (brak scenariusza → happy path pierwszego REQ z delty):
   → API: request (curl/httpie) → oczekiwany status + kształt odpowiedzi
   → UI:  ekran renderuje się, główna interakcja działa
   → CLI/worker: komenda/job kończy się sukcesem
□ Brak nowych ERROR/WARN w logach podczas przejścia happy path
```

**Wykonuje SESJA GŁÓWNA** — to uruchomienie i obserwacja, nie analiza kodu; delegacja nic
tu nie wnosi, a kosztuje.

**Czego NIE robić:** nie buduj infrastruktury testowej pod ten etap, nie stawiaj dockera
„na chwilę", jeśli projekt tego nie ma. Gdy uruchomienie jest niewykonalne w rozsądnym
czasie → **N/A z jednozdaniowym powodem** w `verification.md`. Etap ma łapać oczywiste
wywrotki, nie blokować weryfikacji.

**Wynik:** ✅ (happy path działa) / 🔴 (nie działa — blokuje PASS) / N/A (+ powód).

---

## Etap 9: Git & Release Readiness

```
□ Commits atomic?
□ Commit messages follow format?
□ tasks.md zaktualizowany?
□ Env vars udokumentowane (jeśli nowe)?
□ Dependencies locked?
```

**Opis MR (gdy zespół pracuje na MR/PR):** `ai/` nie trafia do repo, więc plan niesie opis MR.
Przy PASS dołącz do raportu gotowy do wklejenia opis: cel z `proposal.md` (1-2 zdania), wymagania
z delty z **treścią AC** (ADDED/MODIFIED/REMOVED — reviewer nie ma Twoich plików), pokrycie
w postaci „treść AC → test", kluczowe `DECYZJA`, „Odstępstwa od zasad" z design.md (zasady MUST
są zespołowe), tabela etapów z `verification.md`. Numery REQ/AC to Twoja lokalna numeracja —
w opisie MR podawaj treść, numer co najwyżej pomocniczo.

---

## Werdykt i zapis wyniku

**Kryteria werdyktu:**
- ✅ **PASS** — wszystkie etapy ✅ lub N/A; 🟡 warnings NIE blokują (ale trafiają do raportu i verification.md)
- ❌ **FAIL** — jakikolwiek etap z 🔴 CRITICAL, AC w ❌, `INV` w ❌ (refactory), Etap 1 failed
  lub **werdykt subagenta `WARN`/`BLOCK`** (wszyscy weryfikujący używają jednego słownika
  `PASS / WARN / BLOCK` — `WARN` przy AC/INV oznacza FAIL, `WARN` czysto jakościowy to 🟡)

**ZAPISZ wynik do `ai/changes/{nazwa}/verification.md`** — bez tego `/regent:archive` odmówi:

```markdown
# Verification: {nazwa}

Verdict: PASS / FAIL
Data: YYYY-MM-DD
Commit HEAD: {hash}

| # | Etap | Status |
|---|------|--------|
| 1 | Tests | ✅ |
| 2 | Spec Compliance | ✅ |
| 3 | Code Review | ⚠️ 2 warnings |
| 4 | Test Verification | ✅ |
| 5 | DB Review | ✅ / N/A |
| 6 | Security Review | ✅ / N/A |
| 7 | Observability Sync | ✅ / N/A |
| 8 | Smoke Check | ✅ / N/A |
| 9 | Git & Release | ✅ |

## Pokrycie AC (z Etapu 2)
| REQ/AC | Test | Status |
|--------|------|--------|
| REQ-001/AC-1 | tests/users.test.ts › rejects duplicate email | ✅ |

## Issues
- [Etap 3] 🟡 Missing error handling in file.ts:45
```

## Raport końcowy (ZWIĘZŁY!)

Pokaż użytkownikowi tę samą tabelę + issues + następny krok:

```
→ PASS: /regent:archive {nazwa}
→ FAIL: patrz „Ścieżka FAIL"
```

**Nie rozpisuj się.** Krótko, z plikami i liniami.

---

## Ścieżka FAIL

```
1. Wypisz issues (severity, plik:linia).
2. Napraw przez /regent:apply {nazwa} --tasks ... — taski naprawcze dopisz na końcu tasks.md
   w grupie `## Naprawy (runda N)`, każdy z odwołaniem i typem luki z raportu reviewera:
   `- [ ] T-09: [BE] {co} — REQ-001/AC-2 — gap: incomplete — weryfikacja: {test}`
   Albo deleguj punktowo do `regent:backend-dev`.
3. Re-run: Etap 1 (zawsze) + TYLKO oblane etapy (2-9).
4. Zaktualizuj verification.md nowym werdyktem.

🔴 CRITICAL — blokuje PASS. 🟡 WARNING — nie blokuje, ale zostaje w verification.md.
```

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Etap 1 w sesji głównej (make lint/type-check/test/test-coverage)
- PASS wymaga testu na każde AC — AC bez testu to maksymalnie ⚠️ PARTIAL
- verification.md zapisany (verdict + data + commit HEAD) — to warunek zakończenia komendy
- Raport: werdykt + file:line, bez cytowania kodu

❌ **Barierka:** subagenci weryfikujący pracują read-only (bez Edit/Write) — znaleziska
opisują w raporcie, naprawia je `/regent:bugfix` albo `/regent:apply`.
