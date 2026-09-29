---
description: Zamknięcie zmiany — merge delta specs do main specs, retrospektywa, przeniesienie do archiwum
disable-model-invocation: true
argument-hint: <nazwa-zmiany> [--force | --abandon]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, SendMessage, Bash
---

# /regent:archive — Archiwizuj ukończoną zmianę

**Cel:** Zamknij zmianę: zmerguj delta specs do głównych specyfikacji, wyciągnij wnioski, przenieś do archiwum.

```
/regent:archive <nazwa-zmiany> [--force | --abandon]

--force    Archiwizuj mimo braku verification.md z PASS (wymaga jawnej decyzji użytkownika;
           wpis w History dostaje oznaczenie UNVERIFIED)
--abandon  Zamknij zmianę PORZUCONĄ — rezygnujemy z niej, nie została ukończona.
           Pomija bramkę tasków i PASS. Nie merguje delty do main specs.

Przykład:
/regent:archive user-registration
/regent:archive sso-integration --abandon
```

`--force` i `--abandon` wykluczają się: `--force` zamyka zmianę **zrobioną** bez weryfikacji,
`--abandon` zamyka zmianę **niezrobioną**. Podane razem → zapytaj, o którą sytuację chodzi.

---

## Agent (delegacja — WYMAGANE dla merge)

Krok 2 (scalanie delta specs → main specs, **tylko 2a i 2b**) deleguj do subagenta `regent:spec-writer`
(model: sonnet, uruchom narzędziem Task) — to on jest właścicielem specyfikacji i formatu
ADDED/MODIFIED/REMOVED/INVARIANTS. Zły merge korumpuje źródło prawdy.

Pozostałe kroki (walidacja, tabela History w Kroku 3.7, `mv` do archiwum, podsumowanie) są
mechaniczne — wykonuje je główna sesja. **Budżet: 1 uruchomienie** (`--abandon` albo delta bez REQ → 0, bez merge).

---

## Krok 0: Walidacja

```
Sprawdź:
□ ai/changes/{nazwa}/ istnieje
□ ai/changes/{nazwa}/verification.md istnieje i ma "Verdict: PASS"
□ (miękko) bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh drift {nazwa} — pliki z Affected Files zmienione od `Commit HEAD`?
  WARN → ostrzeż: "kod zmiany ruszył się po weryfikacji, rozważ re-run /regent:verify"
  (porównanie plików, nie hasha — merge i squash cudzych zmian nie dają fałszywego alarmu)
□ bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh preflight {nazwa} — ERROR (kolizja numeru REQ, MODIFIED bez REQ, utrata AC) →
  STOP i pokaż użytkownikowi; merge z takiej delty uszkodziłby main spec

Jeśli brak verification.md lub Verdict: FAIL:
  → "⚠️ Zmiana nie została zweryfikowana (PASS). Uruchom /regent:verify {nazwa} najpierw."
  → STOP

--force: kontynuuj mimo braku PASS, ale wpis w History table dostaje "(UNVERIFIED)"
i poinformuj o tym w podsumowaniu.

--abandon: pomiń tę bramkę i Krok 1 (porzucona zmiana z definicji nie ma PASS ani
wszystkich tasków). Zamiast tego POTWIERDŹ decyzję u użytkownika:
  "Porzucam {nazwa}: {N/M} tasków zrobione, delta spec NIE zostanie zmergowana
   do ai/specs/. Kod z wykonanych tasków zostaje w historii gita. Powód porzucenia?"
  → czekaj na powód (trafia do History) i jawne potwierdzenie. Brak → STOP.
```

---

## Krok 1: Sprawdź kompletność

```
Artefakty:
□ proposal.md — status: Approved ✅
□ specs/*.md — delta specs istnieją ✅
□ design.md — istnieje ✅
□ tasks.md — WSZYSTKIE taski [x] ✅ (licznik: bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {nazwa} → „x/y zrobione")

Jeśli nie wszystkie taski done:
  → "⚠️ Tasks incomplete: T-03, T-05 still pending"
  → STOP (chyba że --abandon — wtedy niedokończone taski są właśnie powodem zamknięcia)
```

---

## Krok 2: Merge delta specs → main specs (deleguj → `regent:spec-writer` — TYLKO 2a i 2b)

`--abandon` → **POMIŃ cały Krok 2** (bez delegacji, zero uruchomień subagenta): zmiany, która
nie powstała, nie wolno wmergować do źródła prawdy. Idź prosto do Kroku 3.

**Przed merge (SESJA GŁÓWNA):** zrób migawkę źródła prawdy —
`cp -R ai/specs "${TMPDIR:-/tmp}/specs-before-{nazwa}"` (brak `ai/specs/` → pomiń). `ai/` jest
globalnie ignorowany, więc `git diff` nie pokaże zmian w main specs — pokaże je porównanie z migawką (2c).

**Dla każdego pliku w `ai/changes/{nazwa}/specs/`:**

### 2a. Sprawdź czy main spec istnieje

```
Szukaj: ai/specs/{domena}.md

Delta bez REQ (refactor z samymi INVARIANTS) → merge tego pliku pomijasz; main spec nie
  powstaje (INVARIANTS zostają w archiwum). Cała zmiana taka → Krok 2 bez delegacji.
Jeśli NIE istnieje → utwórz nowy main spec wg ${CLAUDE_PLUGIN_ROOT}/templates/main-spec-template.md
  (pełny stan: REQ z AC — nagłówki ADDED/MODIFIED/REMOVED zostają w delcie)
Jeśli istnieje → merge delta into main
```

**Zanim zmergujesz — sprawdź równoległą zmianę:** czy inna aktywna zmiana w `ai/changes/`
ma deltę na tę samą domenę (albo `proposal.md` tej zmiany ma sekcję `## Zależności`)?
Jeśli tak, przekaż to `regent:spec-writer` w prompcie: `REQ` z MODIFIED mógł zostać przepisany
przez tamtą zmianę, więc „stare zachowanie" z delty może już nie istnieć w main spec.
Nie każ mu zgadywać — niedopasowany `REQ` to `OPEN QUESTIONS`, nie cichy append.

### 2b. Apply deltas

```
ADDED sections:
  → Numer REQ jest wolny we wszystkich main specs — zajęty → OPEN QUESTIONS (kolizja numeru)
  → Dodaj blok REQ do main spec, format Given-When-Then i AC bez zmian

MODIFIED sections (blok w delcie = pełny, nowy stan wymagania):
  → Znajdź REQ-YYY w main spec i podmień CAŁY blok na blok z delty
  → Każde AC z main spec obecne w bloku z delty albo w „Usunięte AC" —
    brakujące AC → OPEN QUESTIONS (delta niepełna; decyzję o AC podejmuje użytkownik)
  → Z bloku w main spec usuń linie „Usunięte AC", „Było", „Powód" i znaczniki „(bez zmian)" —
    zostaje aktualne zachowanie
  → REQ-YYY nieobecne w main spec → OPEN QUESTIONS (zachowanie bez specyfikacji opisuje
    się w delcie jako ADDED — patrz spec-writer, brownfield)

REMOVED sections:
  → Usuń REQ-ZZZ z main spec (nieobecne → OPEN QUESTIONS)

INVARIANTS:
  → Zostają w delcie (dotyczą tylko zmiany) — main spec ich nie zawiera
```

### 2c. Kontrola merge (SESJA GŁÓWNA, przed Krokiem 3)

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh postmerge {nazwa}
```
ERROR (nagłówek delty w main spec, REQ z delty nie trafił do main, zbiór AC różny od delty) →
**resume `regent:spec-writer`** z wynikiem skryptu i popraw merge, zanim przeniesiesz zmianę do archiwum.
Pokaż użytkownikowi `diff -ru "${TMPDIR:-/tmp}/specs-before-{nazwa}" ai/specs` — to diff źródła prawdy.

---

## Krok 3: Przenieś do archiwum

`--abandon` → **przed** `mv` ustaw w `proposal.md` `Status: Abandoned`. Katalog porzuconej
zmiany w `archive/` wygląda tak samo jak zakończonej; po tym polu zadania Regenta zamykają ją
jako porzuconą.

```bash
mv ai/changes/{nazwa}/ ai/changes/archive/{YYYY-MM-DD}-{nazwa}/
```

Struktura po archiwizacji:
```
ai/changes/archive/2025-03-20-user-registration/
├── proposal.md
├── specs/
│   └── users.md (delta)
├── design.md
├── tasks.md
└── verification.md
```

---

## Krok 3.5: Retrospektywa (jedno pytanie, nie ceremonia)

> **Dlaczego:** bez tego framework nie uczy się na własnych błędach. Jeśli `/regent:verify` obleje
> trzy razy z tego samego powodu, albo `regent:architect` trzeci raz zgłosi brak Reference
> Implementation — nikt tego nie zauważy, bo każda zmiana jest zamykana osobno.

**Zbierz sygnały z artefaktów zamykanej zmiany (nie z pamięci):**

```
□ verification.md — czy były FAIL-e? Ile rund? Jaki etap oblał?
□ verification.md → Issues — czy warnings powtarzają się z poprzednich zmian?
□ proposal.md → sekcja Zastrzeżenia — czy zastrzeżenia się potwierdziły?
□ proposal.md → Decyzje i założenia — czy był AMEND? Które ZAŁOŻENIE okazało się błędne?
□ tasks.md — czy doszły taski naprawcze spoza pierwotnego planu?
□ Czy któryś subagent zgłaszał brak wzorca / Reference Implementation?
```

**Werdykt — jeden z dwóch, powiedziany zwięźle:**

- **`BEZ WNIOSKÓW`** — zmiana przeszła gładko. Jedna linia i idź dalej. To normalny,
  najczęstszy wynik — **nie wymyślaj wniosków na siłę**.

- **`WNIOSEK: [1-2 zdania]`** — coś się powtórzyło lub zabolało. Zakwalifikuj do jednej
  z trzech szuflad i **zaproponuj konkretne działanie**:

| Rodzaj wniosku | Działanie |
|---|---|
| Brakujący/niejasny wzorzec w `ai/docs/` | → `/regent:revise {plik}` — z konkretną propozycją treści |
| Brakująca Reference Implementation | → `/regent:revise architecture` — wskaż plik-wzorzec z tej zmiany |
| Powtarzalny błąd procesu (nie kodu) | → zgłoś użytkownikowi; poprawka frameworka, nie projektu |

Wniosek dopisz **jednym zdaniem** do wpisu w tabeli History (Krok 3.7), kolumna `Opis` —
zostaje przy specyfikacji, nie w osobnym pliku.

**Nie twórz `retrospective.md`.** Retro bez działania to koszt bez wartości: albo kończy się
konkretnym `/regent:revise`, albo werdyktem `BEZ WNIOSKÓW`.

`--abandon` → retrospektywa jest tu **najcenniejsza**: powód porzucenia (z Kroku 0) to
gotowy wniosek. Zakwalifikuj go do szuflady i zaproponuj działanie.

---

## Krok 3.7: Aktualizuj History table (SESJA GŁÓWNA — praca mechaniczna)

Jednym zapisem, po retrospektywie (żeby wniosek trafił do wiersza od razu — nie edytuj
tabeli dwa razy). W main spec `ai/specs/{domena}.md`:

```markdown
## History

| Data | Zmiana | Typ | Opis |
|------|--------|-----|------|
| YYYY-MM-DD | {nazwa-zmiany} | feature | [krótki opis z proposal.md] + [wniosek retro, jeśli był] |
```

`--abandon` → wiersz oznacz **ABANDONED** z powodem, w main spec domeny, której zmiana
dotyczyła (`| … | ABANDONED: {powód} |`).

Domena bez main spec (nowa domena, która nie powstała; refactor z samymi INVARIANTS) →
pomiń tabelę; ślad zostaje w archiwum i w gicie.

---

## Krok 4: Podsumowanie

```markdown
## Archive: {nazwa-zmiany} ✅

### Merged specs:
- ai/specs/users.md — 3 ADDED, 1 MODIFIED

### Archived to:
- ai/changes/archive/{YYYY-MM-DD}-{nazwa}/

### Commits included:   (hashe `(commit: …)` z tasks.md)
- abc1234 feat: (KEY) create user entity
- def5678 feat: (KEY) create user repository

### Retrospektywa:
BEZ WNIOSKÓW
(lub: WNIOSEK: [1-2 zdania] → /regent:revise {plik})

### Następne kroki:
→ /regent:status — przegląd projektu
→ /regent:propose — nowa zmiana
```

Przy `--abandon` zamiast „Merged specs" napisz `Delta NIE zmergowana (zmiana porzucona)`
i podaj powód oraz stan tasków (`{N/M} zrobione`).

---

## WAŻNE Rules

✅ **ZAWSZE:**
- verification.md z PASS przed archiwizacją
  (wyjątki: `--force` → oznacz UNVERIFIED; `--abandon` → zmiana porzucona)
- Merge delta → main specs: ADDED dopisane, MODIFIED podmienione całym blokiem, REMOVED usunięte;
  każde AC z main spec kończy w bloku albo w „Usunięte AC" (main specs opisują kod, który istnieje)
- Przy `--abandon`: katalog trafia do `archive/` z zapisem decyzji (`Status: Abandoned`
  w `proposal.md`), delta zostaje niezmergowana —
  ślad porzucenia jest tak samo wartościowy jak ślad wdrożenia
- Retrospektywa (Krok 3.5) — werdykt `BEZ WNIOSKÓW` albo wniosek z konkretnym działaniem;
  `BEZ WNIOSKÓW` to poprawny i najczęstszy wynik
- Wniosek z retrospektywy → History table (jedno miejsce)
- History table zaktualizowany, folder przeniesiony do `archive/`

Timeline: 5-10 minut (retrospektywa: +1 minuta — to jedno pytanie, nie spotkanie)
