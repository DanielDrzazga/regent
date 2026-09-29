---
description: Implementacja tasków z aktywnej zmiany (TDD Red → Green → Refactor)
disable-model-invocation: true
argument-hint: <nazwa-zmiany> [--tasks 1,3,5] [--group Setup]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:apply — Implementuj zmianę

**Cel:** Zaimplementuj taski z aktywnej zmiany, stosując TDD i konwencje projektu.

```
/regent:apply <nazwa-zmiany> [opcje]

Opcje:
  --tasks 1,3,5        Konkretne taski (T-01, T-03, T-05)
  --group Setup         Grupa tasków

Przykład:
/regent:apply user-registration
/regent:apply user-registration --tasks 1,2,3
```

---

## Agenci (delegacja — WYMAGANE)

Ta komenda MUSI działać przez subagentów (uruchom je narzędziem Task), aby użyć ich modeli:

| Subagent (`name`) | Model | Rola w komendzie |
|-------------------|-------|------------------|
| `regent:backend-dev` | sonnet | taski `[BE]` / bez tagu (TDD: Red → Green → Refactor) |
| `regent:frontend-dev` | sonnet | taski `[FE]` (TDD komponentowe; wymaga `frontend-patterns.md`) |
| `regent:dba` | sonnet | taski `[DB]` — migracje/schema |

**Routing tasków po tagach z tasks.md:** `[FE]` → `regent:frontend-dev`, `[DB]` → `regent:dba`,
`[BE]` lub brak tagu → `regent:backend-dev`. Zmiana full-stack: kontrakt API↔UI jest w design.md,
więc BE i FE mogą iść niezależnie (FE mockuje HTTP wg kontraktu) — domyślnie BE najpierw,
respektuj zależności `(po T-XX)`.

❗ Nie implementuj „w miejscu" w głównej sesji — **deleguj do subagenta po dokładnym `name`**.
Inaczej modele z `agents/*.md` nie zostaną użyte.

**Budżet:** S: 1 uruchomienie, M: 1-3, L: 3-6 (tabela w CLAUDE.md). Kilka tasków tej samej
warstwy → **jedno uruchomienie agenta z listą tasków**, nie jedno na task.

**Podział ról:** agent implementujący SAM uruchamia testy w pętli TDD (wąsko — tylko testy
zmienianego modułu/komponentu). Commituje SESJA GŁÓWNA po każdym tasku, na podstawie
raportu subagenta. Jeśli raport zawiera `OPEN QUESTIONS` → zapytaj użytkownika i
kontynuuj tego samego subagenta (resume po agentId) z odpowiedziami. Odpowiedź dopisz jako
`DECYZJA` w `proposal.md` → `## Decyzje i założenia`.

---

## Krok 0: Walidacja

```
Sprawdź:
□ ai/changes/{nazwa}/ istnieje
□ proposal.md ma status: Approved
□ specs/*.md istnieją
□ design.md istnieje
□ tasks.md istnieje
□ bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {nazwa} → bez ERROR (format tasków i delty)

Jeśli brakuje → "Uruchom /regent:propose {nazwa} najpierw"
```

ERROR z `sdd-check change` to błąd formatu artefaktu, nie brak propozycji: pokaż wynik i popraw
artefakt (drobny błąd — sam, koncepcyjny — resume `regent:spec-writer`), bez ponownego `/regent:propose`.

---

## Krok 1: Przeczytaj kontekst (TYLKO potrzebne pliki!)

**Ścieżka — sprawdź raz, na starcie (SESJA GŁÓWNA):**
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/regent.sh task next {nazwa} --json` (dalej skrót `regent.sh` =
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/regent.sh`). Kod 0 → **ścieżka z CLI**: w Krokach 1, 3, 4a i 4c obowiązują bloki „Z CLI”, wynik
zachowaj do Kroku 3. Kod 3 (brak zbudowanego CLI) albo inny błąd → **ścieżka bez CLI**: bloki „Z CLI”
pomijasz, reszta bez zmian; przy innym błędzie pokaż użytkownikowi jedną linię stderr.

**Z CLI:** subagent nie czyta `tasks.md`, `design.md` ani `specs/*.md` — dostaje w prompcie paczkę
(Krok 4a): linie swoich tasków, ich bloki REQ z AC z delty, INVARIANTS i sekcje `design.md` dobrane do
tagu, w tym „Affected Files”. Punkty 4–5 i czytanie KONTEKSTOWO z listy poniżej zostają bez zmian. Czego
w paczce brakuje, subagent doczytuje z pliku i zgłasza w raporcie: `BRAK W PACZCE: <plik> › <sekcja> — <po co>`.

**Bez CLI:**

Subagent implementujący czyta **bezpośrednio narzędziem Read** — zakres per agent:

```
ZAWSZE (każdy agent implementujący: backend-dev / frontend-dev / dba):
1. ai/changes/{nazwa}/tasks.md
2. ai/changes/{nazwa}/design.md
3. ai/changes/{nazwa}/specs/*.md
4. ai/docs/stack/technology.md
5. ai/docs/conventions/code-style.md

backend-dev — KONTEKSTOWO (Read tylko gdy faktycznie potrzebne):
- ai/docs/patterns/architecture.md — tylko gdy tworzysz nowy moduł/warstwę
- ai/docs/conventions/naming.md — tylko gdy tworzysz nowe pliki/klasy
- ai/docs/patterns/di-patterns.md — tylko gdy nowe klasy z DI
- ai/docs/patterns/testing-patterns.md — tylko gdy piszesz testy
- ai/docs/patterns/exception-patterns.md — tylko gdy error handling

frontend-dev — ZAWSZE dodatkowo:
- ai/docs/patterns/frontend-patterns.md   ← źródło prawdy o stacku UI (brak → STOP, patrz agent)
KONTEKSTOWO:
- ai/docs/conventions/naming.md — nowe pliki/komponenty
- ai/docs/patterns/testing-patterns.md (sekcja Testy UI) — gdy piszesz testy
```

**NIE skanuj src/** przed implementacją — czytaj tylko pliki wskazane w design.md → "Affected Files".
**NIE czytaj** plików, które nie są potrzebne do danego zadania.

---

## Krok 2: Sprawdź środowisko (SESJA GŁÓWNA)

```
Uruchom: make check
Jeśli coś nie przechodzi → napraw PRZED implementacją (baseline musi być zielony).
```

Brak `Makefile` / celu `check` → natywny odpowiednik ze stacku (kontrakt `make` w CLAUDE.md);
powiedz jawnie, czego użyłeś. Baseline musi być zielony niezależnie od narzędzia.

---

## Krok 3: Wybierz taski

**Z CLI:** taski bierzesz z wyniku `next` (Krok 1) — gotowe to niezrobione z zamkniętymi zależnościami
`(po T-XX)`, w kolejności z `tasks.md`:
- `--tasks` → wskazane spośród gotowych; wskazany, a niegotowy → pokaż, na co czeka (`blocked[].after`)
- `--group` → gotowe z tej grupy (`refs.group`)
- inaczej → wszystkie gotowe; po zamknięciu rundy wołasz `next` ponownie — odblokowane taski dochodzą
  w kolejnej rundzie
- stan `in_progress` to task przerwany w poprzedniej sesji: wznów go bez `take`, najpierw `git status`

Komunikat dla użytkownika jak niżej, z dopiskiem `(z regent task next)`.

**Bez CLI:**

```
Jeśli --tasks podane:
  → Filtruj tylko wskazane taski
Jeśli --group podane:
  → Filtruj taski z danej grupy
Inaczej:
  → Wszystkie taski po kolei
```

Pokaż użytkownikowi zwięźle:
```
Taski: T-01, T-02, T-03 (z tasks.md)
Po każdym tasku robię atomic commit. Rozpoczynam? (tak/nie)
```

Zgoda tutaj obejmuje per-taskowe commity (jawny wyjątek od bramki `/regent:commit`).

---

## Krok 4: Implementacja (per task)

### 4a. TDD Workflow (subagent wg tagu taska: `regent:backend-dev` / `regent:frontend-dev`)

**Z CLI — przed delegacją (SESJA GŁÓWNA):**
1. `regent.sh task take <id>` dla każdego taska uruchomienia (id z `next`; task w toku — bez `take`).
   Kod 1 → task ma innego właściciela albo stan: pokaż komunikat i pomiń go w tej rundzie.
2. `regent.sh task packet {nazwa} T-02 T-05` — jedna paczka na uruchomienie agenta, z taskami tej
   warstwy (`next --layer BE|FE|DB` filtruje po tagu, brak tagu = `BE`).
3. Prompt subagenta: paczka w całości i polecenie: „Paczka zastępuje tasks.md, design.md i specs/*.md —
   nie czytaj ich. Czego brakuje, doczytaj z pliku i zgłoś w raporcie: `BRAK W PACZCE: <plik> › <sekcja> — <po co>`.”

Każde `BRAK W PACZCE` z raportu przepisz do raportu końcowego (Krok 5), jedna linia na brak — to
sygnał do poprawy reguły paczki. Pętla TDD poniżej jest wspólna dla obu ścieżek.

```
1. 🔴 RED — Napisz failing test dla `weryfikacji` z taska i URUCHOM (musi failować z oczekiwanego powodu)
   → Task bez AC (Setup, konfiguracja): weryfikacją jest komenda z taska, bez fazy RED
   → BE: shared mocks/factories wg testing-patterns.md
   → FE: test komponentu (render + interakcja + widoczne zachowanie), mock HTTP wg
     frontend-patterns.md — kontrakt z design.md
   → Jeśli brak potrzebnego helpera — utwórz go

2. 🟢 GREEN — Napisz minimalny kod, uruchom test (musi przejść)

3. 🔵 REFACTOR — Popraw jakość kodu (OBOWIĄZKOWY!), testy dalej zielone
   → Nazwy, struktura, duplikacja, czytelność
   → To jest moment na quality!

Testy uruchamiaj WĄSKO (moduł/plik/komponent) — pełny make check jest w /regent:verify.
```

**Jeden pionowy plaster na cykl: jeden seam, jeden test, minimalna implementacja.** Kolejny test
pisz dopiero po zielonym poprzednim — każdy jest pociskiem smugowym, który reaguje na to,
czego nauczył poprzedni cykl. Testy pisane hurtem przed implementacją opisują wyobrażone
zachowanie (anty-wzorce: `regent:qa-engineer`).

**REFACTOR należy do tego cyklu, nie do review** — po zielonym teście, przed kolejnym.

### 4b. Atomic commit (SESJA GŁÓWNA, po raporcie subagenta)

Warunek: raport agenta implementującego potwierdza GREEN (wyniki uruchomienia testów).
Dla tasków `[DB]` odpowiednikiem GREEN jest sekcja „Wyniki testów" z raportu `regent:dba`
(migracja up/down/up + testy modułu) — patrz `agents/dba.md`.

```bash
# Dodaj KONKRETNE pliki wymienione w raporcie subagenta
git add src/modules/users/domain/user.entity.ts
git add tests/modules/users/domain/user.entity.test.ts

git commit -m "feat: (KEY) create user entity with validation"
```

### 4c. Aktualizuj tasks.md (SESJA GŁÓWNA, po commicie taska)

**Z CLI:** zamiast ręcznej edycji — `regent.sh task done <id> --commit <hash> --tests "<AC-1 → plik › test; …>"`
(task bez AC: bez `--tests`). Skrypt przepisuje wyłącznie linię taska: `[x]` i ślad w formacie poniżej.
Komunikat „nie ma w … tasks.md” → dopisz ślad ręcznie jak niżej; kod 1 (przejście niedozwolone) →
pokaż komunikat, pliku nie edytuj.

**Bez CLI** — ślad dopisujesz ręcznie (format i uwaga o `git add` poniżej dotyczą obu ścieżek):

`ai/` to osobisty warsztat — globalnie ignorowany, poza repo produktu. `tasks.md` zostaje więc
lokalnie, a ślad taska dopisujesz po commicie: hash i test, który sprawdza jego AC (z raportu deva):

```markdown
- [x] T-01: [BE] Create user entity — REQ-001/AC-1, AC-2 — … ✅ (commit: abc1234 · testy: AC-1 → tests/users/user.entity.test.ts › rejects empty email; AC-2 → … › trims name)
- [ ] T-02: [BE] Create user repository — REQ-001/AC-2 — …
```

`git add` wymienia wyłącznie pliki kodu i testów — ścieżka w `ai/` jest ignorowana, więc git
skończyłby się kodem 1 i przerwał `git add … && git commit`. Po hashu `sdd-check diff/stale`
odróżnia commity cyklu od zmian spoza SDD; po mapowaniu `testy:` reviewer w `/regent:verify`
znajduje test każdego AC.

---

## Krok 4.5: Zmiana kursu — gdy implementacja podważa plan

Sygnał: `OPEN QUESTIONS` z prefiksem `ZAKRES:` w raporcie deva albo Twoje odkrycie, że
zatwierdzony plan nie pasuje do kodu. Zaklasyfikuj odkrycie, zanim cokolwiek zmienisz:

| Odkrycie | Działanie |
|---|---|
| Dotyczy tylko kodu (inna struktura, ten sam efekt) | kontynuuj — artefakty bez zmian |
| Zmienia taski (kolejność, podział, nowy task techniczny) | edytuj tasks.md + wpis `DECYZJA` |
| Zmienia zachowanie (AC/REQ) albo decyzję z design.md | **AMEND** (poniżej) |
| Zmienia cel zmiany | zatrzymaj: `/regent:archive {nazwa} --abandon` + nowe `/regent:propose`, albo zawęź zmianę do tego, co zrobione, a resztę wydziel do nowej |

**AMEND:**
1. Pokaż użytkownikowi (`AskUserQuestion`): co w planie się nie sprawdza, proponowana zmiana
   AC/design z rekomendacją, wariant alternatywny. Decyzja należy do użytkownika.
2. Po zgodzie: poprawka drobna → edytujesz deltę / design.md wprost; koncepcyjna → resume
   `regent:spec-writer` / `regent:architect`.
3. Wpis `AMEND` w `proposal.md` → `## Decyzje i założenia` (co, dlaczego). Status zostaje
   `Approved` — zgoda z punktu 1 jest akceptacją poprawki.
4. Uruchom `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {nazwa}` i `preflight {nazwa}` — poprawiona
   delta musi dalej dać się zmergować.

Spec na końcu `/regent:apply` mówi prawdę o kodzie — to on trafi przez `/regent:archive` do źródła prawdy.

---

## Krok 5: Status report (zwięzły!)

```markdown
## Apply: {nazwa} — Done

Tasks: 3/3 ✅
Commits: abc1234, def5678, ghi9012

→ /regent:verify {nazwa}
```

**Nie powtarzaj treści artefaktów.** Developer ma je w plikach.

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Czytaj `ai/docs/` KONTEKSTOWO — tylko pliki potrzebne do tego taska
- TDD: Red → Green → **Refactor** (jakość!) — z realnym uruchamianiem testów
- Mocks-first: shared helpers wg `testing-patterns.md`
- Testy wąsko w pętli TDD (moduł/pattern); pełny `make check` zostaw dla `/regent:verify`
- Commit po potwierdzonym GREEN w raporcie subagenta
- Atomic commits per task (sesja główna, po zgodzie z Kroku 3)
- Raport: zwięzły, file:line

❌ **Barierka:** `git add` wyłącznie z listą plików — `git add .` i `git add -A` wciągają cudze
zmiany do commitu zmiany.
