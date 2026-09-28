---
description: Formalna propozycja zmiany — proposal, delta specs, design, tasks (spec przed kodem)
argument-hint: <nazwa-zmiany> [--type feature|refactor|bugfix]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:propose — Zaproponuj zmianę

**Cel:** Stwórz formalną propozycję zmiany z pełną specyfikacją (proposal, delta specs, design, tasks).

```
/regent:propose <nazwa-zmiany> [--type feature|refactor|bugfix]

Przykład:
/regent:propose user-registration
/regent:propose extract-auth-service --type refactor
```

---

## Agenci (delegacja — WYMAGANE)

Ta komenda MUSI działać przez subagentów (uruchom je narzędziem Task), aby użyć ich modeli:

| Subagent (`name`) | Model | Rola w komendzie |
|-------------------|-------|------------------|
| `regent:spec-writer` | sonnet | proposal, delta specs, tasks |
| `regent:architect` | opus | design.md — podejście, warstwy, ryzyka |

❗ Nie realizuj kroków „w miejscu" w głównej sesji — **deleguj do subagenta po dokładnym `name`**.
Inaczej modele z `agents/*.md` nie zostaną użyte.

**Budżet:** S: 1-2 uruchomienia subagentów, M: 2-3, L: 3-5 (tabela w CLAUDE.md).
Przekroczenie → jedno zdanie uzasadnienia dla użytkownika.

**Podział ról sesja główna ↔ subagent:** wywiad z użytkownikiem i bramki akceptacji prowadzi
SESJA GŁÓWNA (subagent nie może rozmawiać z użytkownikiem). Subagenci dostają odpowiedzi
w prompcie i **zwracają treść artefaktów w raporcie** — pliki zapisuje sesja główna po
akceptacji.

---

## Krok 0: Walidacja konfiguracji

```
WYMAGANE pliki (nie puste):
□ ai/docs/stack/technology.md
□ ai/docs/patterns/architecture.md
□ ai/docs/conventions/naming.md
□ ai/docs/conventions/code-style.md
□ ai/docs/conventions/git-workflow.md

Jeśli brakuje → "Uruchom /regent:init przed /regent:propose"
```

**Konflikt z inną aktywną zmianą (twardy punkt, nie ostrzeżenie ogólne)** — widzisz tylko własne
zmiany (`ai/` jest osobisty; pracę kolegów ujawni merge MR). Dla każdej zmiany
w `ai/changes/` (bez `archive/`) porównaj z zakresem tej propozycji:
```
□ ta sama domena w specs/{domena}.md?   (obie delty wejdą do tego samego main spec)
□ wspólne pliki w design.md → „Affected Files"?
```
Pokrycie → wypisz kolidującą zmianę i zapytaj (`AskUserQuestion`): kontynuować równolegle /
poczekać na jej zamknięcie / poszerzyć zakres tamtej zmiany. **Decyzję zapisz w `proposal.md`**
(sekcja `## Zależności`) — `/regent:archive` mergujący drugą deltę do tego samego main spec musi
wiedzieć, że pierwsza już go zmieniła.

---

## Krok 1: Zrozum zmianę (wywiad 1 runda, Challenge w rundach)

### 1a. Detekcja typu

```
Na podstawie nazwy / opisu (PL i EN):
- "add", "create", "implement", "dodaj", "utwórz" → feature
- "extract", "refactor", "reorganize", "wydziel", "uporządkuj" → refactor
- "fix", "repair", "correct", "napraw", "popraw" → bugfix

Jeśli nie jasne → zapytaj użytkownika
```

### 1b. Wywiad (SESJA GŁÓWNA — jedna runda, oszczędność tokenów!)

Sesja główna zadaje użytkownikowi wszystko w jednym pytaniu:

```
Opisz zmianę:
1. Problem i cel — co i dlaczego?
2. Zachowanie — happy path + error scenarios?
3. Zakres — co IN scope, co OUT of scope?
4. Ograniczenia — techniczne, czasowe?
```

Wejście z `/regent:explore` (blok „Wejście do /regent:propose") zastępuje pytania, na które już
odpowiada — rozstrzygnięcia z eksploracji to gotowe wpisy `DECYZJA`, a „Otwarte" to pierwszy
frontier Challenge.

**Czekaj na odpowiedzi.** Jeśli odpowiedzi wystarczające → Krok 1b′. Jeśli nie → dopytaj
KONKRETNIE o brakujące elementy (nie powtarzaj całego wywiadu).

### 1b′. Challenge — drzewo decyzyjne w rundach (BRAMKA JAKOŚCI)

> **Dlaczego:** CLAUDE.md stawia Cię w roli **współodpowiedzialnego partnera**, nie wykonawcy.
> Bez tego kroku ta rola zależy od tego, czy akurat coś Ci się nasunie. Tu jest egzekwowana.
> To jedyne miejsce w cyklu, gdzie zły pomysł kosztuje jeszcze zero linii kodu — i jedyne,
> w którym wszystkie pytania do użytkownika padają, ZANIM ruszy pierwszy subagent.

Zmiana to **drzewo decyzji**: każde rozstrzygnięcie odsłania kolejne, które od niego zależały.
Nie da się sensownie zapytać o kształt API, zanim wiadomo, czy w ogóle budujemy nowy moduł.
Dlatego pracujesz **rundami**, nie jedną listą pytań i nie pytaniem po pytaniu.

**Frontier** = wszystkie decyzje, których przesłanki są już rozstrzygnięte — czyli pytania,
które możesz zadać TERAZ, nie zgadując odpowiedzi, których jeszcze nie usłyszałeś.

#### Zasada podziału pracy (nie do negocjacji)

```
FAKTY znajdujesz SAM — nigdy nie pytasz o nie użytkownika.
  Czy ten helper już istnieje? Jaki wzorzec jest w kodzie? Co mówi ADR?
  → Grep/Glob/Read, a przy szerokim zakresie JEDEN subagent Explore.

DECYZJE oddajesz UŻYTKOWNIKOWI — nigdy nie rozstrzygasz ich za niego.
  Czy budujemy to? Który wariant? Co jest OUT of scope?
  → AskUserQuestion, z Twoją rekomendacją jako pierwszą opcją.
```

Pytanie o fakt, który mogłeś sprawdzić sam, to błąd — marnuje turę użytkownika.
Decyzja podjęta za użytkownika to złamanie roli partnera.

#### Runda 0: zbierz fakty i otwórz drzewo

Rozpoznaj kod **read-only** (Grep/Glob/Read; JEDEN `Explore`, gdy zakres niejasny) i sprawdź
korzenie drzewa — to są zawsze pierwszy frontier, bo nic od nich nie zależy w drugą stronę:

```
□ PROBLEM — czy problem jest realny i nazwany?
  Czerwona flaga: uzasadnienie to „bo tak będzie lepiej" / „przyda się" / „inni tak mają",
  bez konkretnego bólu użytkownika lub kosztu, który znika.

□ PROPORCJA — czy rozwiązanie jest proporcjonalne do problemu?
  Czerwona flaga: nowa warstwa abstrakcji / nowa zależność / nowy moduł dla problemu,
  który rozwiązuje się w istniejącym kodzie.

□ ZAKRES — czy zakres nie jest przerostem względem problemu?
  Czerwona flaga: AC opisujące przypadki, których nikt nie zgłosił; „skoro już to robimy, to…".

□ PROSTSZA DROGA — czy istnieje wyraźnie tańsze rozwiązanie o tym samym efekcie?
  Czerwona flaga: nie rozważyłeś ani jednej alternatywy.

□ JĘZYK — (gdy istnieje `ai/docs/domain/glossary.md`) czy opis zmiany używa terminów
  ze słownika w ich ustalonym znaczeniu?
  Czerwona flaga: termin użyty w innym znaczeniu niż w słowniku, albo synonim z `_Unikaj_`.
  Rozbieżność jest pytaniem do frontiera („czy X znaczy tu A czy B?"), a po rozstrzygnięciu —
  wpisem do sekcji „Rozstrzygnięte niejednoznaczności" w glosariuszu.

□ ZASADY — (gdy architecture.md ma „Zasady nienegocjowalne") czy kierunek mieści się w MUST?
  Czerwona flaga: rozwiązanie wymaga odstępstwa — to pytanie do frontiera, a po decyzji
  wpis w design.md → „Odstępstwa od zasad".

□ LUKI — czy opis zachowania odpowiada na to, o co i tak zapyta tester?
  Przejdź kategorie: stany błędu / pusty / ładowanie · mierzalne NFR (czas, limity, wolumen) ·
  uprawnienia (kto może, kto nie) · współbieżność i idempotencja (dwa razy, naraz) · cykl życia
  danych (edycja, usunięcie, archiwizacja) · awaria integracji zewnętrznej.
  Czerwona flaga: kategoria dotyczy zmiany, opis milczy, a odpowiedź zmieniłaby AC albo test.
  Luka o małym wpływie to nie pytanie — spec-writer przyjmie rozsądną wartość jako ZAŁOŻENIE.
```

**Zero czerwonych flag i zero rozwidleń technicznych** → powiedz `AKCEPTUJĘ` jednym zdaniem
i idź do Kroku 2. Nie szukaj problemów na siłę — większość zmian ma tu po prostu przejść,
a runda pytań bez pytań to strata tury.

#### Rundy 1..N: pytaj cały frontier naraz

Każda runda to **jedna tura `AskUserQuestion`** (do 4 pytań), zadana przez SESJĘ GŁÓWNĄ.
Format pytania: tytuł, treść, **Twoja rekomendacja jako pierwsza opcja** z dopiskiem
`(Recommended)`.

Do frontiera tej rundy trafiają zarówno zastrzeżenia z Rundy 0 (czy budować), jak i
rozwidlenia techniczne, które zmieniłyby treść artefaktów, gdyby subagent zgadł źle:
- **Podejście:** rozszerzyć istniejący komponent vs stworzyć nowy; wzorzec X vs Y.
- **Zakres:** co dokładnie IN/OUT, gdy opis jest szeroki lub wieloznaczny.
- **Kształt kontraktu/API:** sygnatury, typy, format danych — gdy jest więcej niż jedna
  rozsądna opcja.
- **Rozbieżność z dokumentem źródłowym:** ticket/standard zakłada inny stack niż projekt.

❗ **Pytanie, którego odpowiedź zależy od innego pytania otwartego w TEJ rundzie, należy do
rundy PÓŹNIEJSZEJ.** To jest cała mechanika — łamiąc ją, wracasz do zgadywania.

Po odpowiedziach: rozstrzygnięte decyzje przesuwają frontier na zewnątrz i odblokowują
pytania, które od nich zależały. Przelicz frontier i zadaj następną rundę.

**Gdy frontier wymaga faktu ze środowiska** — odpal rozpoznanie, ale **nie blokuj na nim
całej rundy**: czeka tylko ta gałąź, resztę frontiera pytasz teraz.

#### Koniec: frontier pusty

Sesja kończy się, gdy **żadna gałąź nie została z cichym założeniem**. Wtedy werdykt:

- **`AKCEPTUJĘ`** — drzewo przeszło bez zastrzeżeń (lub zastrzeżenia zostały rozwiane
  w rundach). Jedno zdanie i Krok 2.
- **`MAM ZASTRZEŻENIA`** — użytkownik podtrzymał kierunek mimo czerwonych flag.
  Wypisz je **zwięźle** (1-3 punkty, każdy: zastrzeżenie + konkretna alternatywa).

**Każde rozstrzygnięcie z rund trafia do `proposal.md`** — sekcja `## Decyzje i założenia`,
wpis `DECYZJA` (kwestia → odpowiedź, jedna linia). Zbieraj je po każdej rundzie i przekaż
kompletną listę `regent:spec-writer` w Kroku 2. Po kompaktowaniu kontekstu, przerwanej sesji albo
za pół roku to jedyny ślad, dlaczego plan wygląda tak, a nie inaczej.

**Zastrzeżenia zawsze trafiają do `proposal.md`** — sekcja `## Zastrzeżenia` z werdyktem
użytkownika (`uwzględnione` / `świadomie odrzucone`). Powód: decyzja ma zostać udokumentowana
także wtedy, gdy ją odrzucisz — za pół roku nikt nie pamięta, że temat był podnoszony.

❗ **Jeśli użytkownik podtrzymuje decyzję po Twoich zastrzeżeniach — to jego decyzja.
Zapisz ją i buduj pełny zakres bez wracania do tematu.** Zgłaszasz raz, nie marudzisz.

#### Budżet rund (sufit, nie cel)

| Rozmiar | Rund `AskUserQuestion` | Uwaga |
|---|---|---|
| **S** | 0-1 | zwykle `AKCEPTUJĘ` po Rundzie 0 |
| **M** | 1-2 | |
| **L** | 2-3 | 4. runda → powiedz, dlaczego drzewo jest aż tak głębokie |

Rozpoznanie read-only liczy się do budżetu subagentów (`Explore`), rundy pytań — nie.

❗ **Nie deleguj, dopóki frontier nie jest pusty.** Każda re-delegacja po fakcie (bo „wyszła"
decyzja o loggerze, scope albo kształcie API) to pełny re-run kontekstu. Pomiar realnego
`/regent:propose` pokazał 6 subagentów zamiast 2, bo 3 decyzje padły SEKWENCYJNIE po raportach.
Lepiej jedna dodatkowa runda tutaj niż jedna re-delegacja później.

---

## Krok 2: Generuj artefakty (subagenci zwracają TREŚĆ, nie zapisują plików)

Deleguj (Task) z odpowiedziami z wywiadu w prompcie — w tej kolejności, każdy krok bierze
wynik poprzedniego:

1. `regent:spec-writer` → treść **proposal.md** i **specs/{domena}.md**
2. `regent:architect` → treść **design.md** (przekaż mu proposal + specs z raportu spec-writera)
3. **resume tego samego `regent:spec-writer`** (SendMessage po agentId) z treścią `design.md` →
   treść **tasks.md**. Taski wynikają z „Affected Files" i decyzji architekta, nie z samego
   speca. Resume to nie nowe uruchomienie (budżet), a spec-writer ma już kontekst speca.

W prompcie do `regent:spec-writer` przekaż listę `DECYZJA` z Kroku 1b′ oraz zastrzeżenia (jeśli były),
a także dwa fakty policzone skryptem (sesja główna, przed delegacją):
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh next-req` → następny wolny numer REQ,
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh index` → spis wymagań z `ai/specs/` — spec-writer czyta w całości tylko main specs
  domen, których dotyczy zmiana.

W promptach zaznacz jawnie: **„NIE zapisuj plików — zwróć pełną treść artefaktów w raporcie"**.

W prompcie do `regent:architect` przypomnij: **wzorce bierz z `ai/docs/patterns/` + sekcji
Reference Implementations w `architecture.md`; `src/` skanuj tylko do ZLOKALIZOWANIA plików
do "Affected Files", nie do nauki wzorca od zera.** Jeśli potrzebny wzorzec nie ma Reference
Implementation → niech zgłosi to w raporcie (kandydat do dopisania przez `/regent:revise`).

**Zawężaj kontekst przekazywany subagentom (oszczędność tokenów):**
> Które pliki `ai/docs/` czytać wiedzą już same definicje `regent:spec-writer`/`regent:architect` — NIE powtarzaj
> tego w prompcie. Poniżej tylko logika orkiestracji, której agenci nie mają:
- Duże dokumenty źródłowe (specyfikacje, standardy, `.docx.md`): niech przeczyta je JEDEN
  subagent RAZ i zwróci wnioski w raporcie. W kolejnych promptach/iteracjach przekazuj
  **streszczenie z raportu**, nie każ czytać dokumentu ponownie.
- Przekazuj subagentowi tylko te wyniki rozpoznania kodu (z Kroku 1b′), które są mu potrzebne —
  nie cały dump eksploracji.

### 2a. proposal.md
Szablon: `${CLAUDE_PLUGIN_ROOT}/templates/proposal-template.md`
- Metadane, problem, rozwiązanie, oczekiwany rezultat, zakres, wpływ, Decyzje i założenia
  (AC żyją w delcie — proposal do nich odsyła)

### 2b. specs/{domena}.md
Szablon: `${CLAUDE_PLUGIN_ROOT}/templates/spec-template.md`
- ADDED / MODIFIED / REMOVED / INVARIANTS
- Jeden plik per domena

### 2c. design.md
Szablon: `${CLAUDE_PLUGIN_ROOT}/templates/design-template.md`
- Podejście, Affected Files, API, DB changes, ryzyka
- Sekcje nieużywane (np. Database Changes, gdy brak zmian w DB) USUŃ — ich obecność
  triggeruje etapy w /regent:verify

### 2d. tasks.md

Tagi warstw (`[BE]`/`[FE]`/`[DB]`, brak tagu = `[BE]`) nadaje `regent:spec-writer` wg swojej
definicji. Twoja rola orkiestracyjna: **przy zmianie BE+FE dopilnuj, by `design.md` zawierał
kontrakt API↔UI** (kontrakt-first — FE mockuje HTTP wg kontraktu, domyślnie BE najpierw).

Format taska (REQ/AC, pliki, weryfikacja) definiuje `regent:spec-writer` — przykład:

```markdown
# Tasks: [nazwa]

## Setup
- [ ] T-01: [task] — pliki: [...] — weryfikacja: [komenda / obserwowalny efekt]

## Implementation
- [ ] T-02: [DB] Migration: users table — REQ-001 — pliki: [...] — weryfikacja: migracja up/down/up
- [ ] T-03: [BE] Create user endpoint — REQ-001/AC-1, AC-2 — pliki: [...] — weryfikacja: testy REQ-001/AC-1, AC-2 zielone (po T-02)
- [ ] T-04: [FE] Registration form component — REQ-001/AC-3 — pliki: [...] — weryfikacja: test komponentu REQ-001/AC-3 (po T-03)

## Integracja / E2E
- [ ] T-05: [BE] E2E rejestracji — REQ-001, REQ-002 — pliki: [...] — weryfikacja: test E2E zielony

---
Total: X tasks | Size: [S/M/L]
```

Testy jednego taska powstają w tym tasku (cykl TDD). Grupa `## Integracja / E2E` jest tylko
na testy przekrojowe — sprawdzające kilka tasków naraz.

Jeśli raport subagenta zawiera `OPEN QUESTIONS` → zadaj je użytkownikowi (jedną turą
`AskUserQuestion`) i **kontynuuj TEGO SAMEGO subagenta** (SendMessage / resume po agentId)
z odpowiedziami. **Resume jest ścieżką DOMYŚLNĄ** — subagent zachowuje kontekst, nie płacisz
ponownie za jego system-prompt ani za wczytane dokumenty. Re-delegacja od zera (nowy Task) TYLKO
gdy resume jest niedostępne.

---

## Krok 2.5: Kontrola spójności artefaktów (SESJA GŁÓWNA)

Zanim pokażesz Draft, porównaj raporty, które już masz w kontekście — bez nowego subagenta.
Rozjazd między artefaktami wychodzi dziś dopiero w kodzie; tu kosztuje jedną poprawkę tekstu.
Pokrycie AC↔task i poprawność odwołań policzy skrypt w 3a — tu sprawdzasz to, czego skrypt
nie oceni:

| Kontrola | Rozjazd → działanie |
|---|---|
| Pliki z tasków mieszczą się w „Affected Files" z design.md | popraw tasks albo design (resume) |
| Decyzje techniczne i kontrakt API z design.md zgodne z AC | sprzeczność → pytanie do użytkownika |
| Każda `DECYZJA` z Challenge odbita w artefaktach | uzupełnij artefakt |
| Terminy zgodne z `glossary.md` (gdy istnieje) | synonim z `_Unikaj_` → popraw |

Rozjazd drobny poprawiasz sam w treści przed zapisem; koncepcyjny → resume właściwego
subagenta. Wynik (liczba rozjazdów i co z nimi zrobiono) pokazujesz w 3b jedną linią.

---

## Krok 3: Zapisz jako Draft + prezentacja do review

> **Filozofia:** user ocenia PEŁNE pliki, nie skrócony obraz w czacie — poprawki (błędne AC,
> zły scope, nietrafiony design) często widać dopiero po przeczytaniu artefaktów. Dlatego
> zapisujemy je NAJPIERW jako `Draft`, a `Approved` ustawiamy dopiero po akceptacji.

### 3a. Zapis Draft (SESJA GŁÓWNA)

Sesja główna zapisuje pełną treść z raportów subagentów do `ai/changes/{nazwa}/`:
```
ai/changes/{nazwa}/
├── proposal.md      ← Status: Draft
├── specs/{domena}.md
├── design.md
└── tasks.md
```
- W `proposal.md` ustaw **`Status: Draft`**.

Po zapisie sprawdź artefakty skryptem (fakty liczy skrypt, nie model):
```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {nazwa}      # format delty, tasks, pokrycie AC przez taski
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh preflight {nazwa}   # delta vs ai/specs/: kolizje numerów, MODIFIED bez REQ, utrata AC
```
ERROR → popraw przed prezentacją (drobne — sam, koncepcyjne — resume subagenta). WARN
pokrycia (AC bez taska, task bez AC) → popraw albo uzasadnij wpisem w Decyzjach.

### 3b. Prezentacja (ścieżki + zwięzłe podsumowanie)

```markdown
## Proposal: [nazwa] ([type]) — zapisano jako Draft

Pliki do przeglądu (w tej kolejności — od „czy to właściwy problem" do „jak"):
- ai/changes/[nazwa]/proposal.md
- ai/changes/[nazwa]/specs/[domena].md
- ai/changes/[nazwa]/tasks.md
- ai/changes/[nazwa]/design.md

AC: X | Tasks: Y | Size: S/M/L | Modules: [lista] | Specs: [X ADDED, Y MODIFIED]
Założenia do potwierdzenia: N (proposal.md → Decyzje i założenia, wpisy ZAŁOŻENIE)
Spójność (Krok 2.5): [N rozjazdów — poprawione / do decyzji: …] | sdd-check: [RESULT]
Kluczowe ryzyka / OPEN QUESTIONS: [1-2 zdania, jeśli są]

Checklista recenzenta (2 minuty):
□ Problem i zakres to to, o co prosiłem — nic ponad to nie dopełzło
□ Każde AC da się sprawdzić testem; przypadek, na którym mi najbardziej zależy, ma swoje AC
□ Założenia (ZAŁOŻENIE) są do przyjęcia
□ Każdy task wskazuje swoje AC i weryfikację — żaden nie jest zagadką
□ Byłbym spokojny, gdyby AI zbudowało dokładnie to i nic więcej

Przeczytaj pliki, potem: `zatwierdzam` / `popraw: [opis]` / `odrzuć`
```

**CZEKAJ NA DECYZJĘ.**

### 3c. Obsługa odpowiedzi:

**`zatwierdzam` / `tak`** → Krok 4 (flip statusu).

**`odrzuć` / `nie`** → ustaw w proposal.md `Status: Rejected` (zostaw pliki jako ślad decyzji;
user może ręcznie usunąć katalog). Nie kontynuuj.

**`popraw: [opis]`** → nanieś poprawki, pliki pozostają `Draft`; uruchom ponownie `sdd-check change`
i `preflight` (3a), potem pokaż sekcję 3b z aktualnym wynikiem.
Wybór ścieżki **zależnie od skali poprawki**:
- **Drobne / mechaniczne** (literówki, formatowanie, pojedyncze AC, nazwa `action`, korekta
  ścieżki/typu) → **sesja główna edytuje pliki Draft wprost** (Edit). NIE budź subagenta — to
  najtańsze i najszybsze dla iteracji na tekście. Napisz krótko co zmieniłeś.
- **Koncepcyjne** (zmiana podejścia technicznego, scope, wielu AC/tasków naraz, przeprojektowanie
  design) → **kontynuuj TEGO SAMEGO subagenta** (SendMessage / resume po agentId), on aktualizuje
  treść, sesja nadpisuje pliki. Chroni spójność proposal↔specs↔design↔tasks. Re-delegacja od zera
  TYLKO gdy resume niedostępne. Zbieraj powiązane poprawki w jedną turę.

Jeśli nie masz pewności do której kategorii należy poprawka → potraktuj jako koncepcyjną (subagent).

**Iteruj do `zatwierdzam`.** Pliki są już na dysku jako Draft przez cały czas iteracji.

---

## Krok 4: Zatwierdzenie (SESJA GŁÓWNA)

Po `zatwierdzam` — pliki już istnieją (zapisane w Kroku 3). Wykonaj TYLKO:
1. Zmień w `proposal.md` **`Status: Draft` → `Status: Approved`** (bez tego `/regent:apply` odmówi startu).
2. (opcjonalnie) Eksport tasków do trackera — tylko gdy sesja ma podłączony tracker (np. MCP
   Jira/GitLab); bez niego pomiń punkt bez pytania. To akcja poza repo, więc:
   - pytasz o zgodę (`AskUserQuestion`: eksportuj / pomiń) i pokazujesz listę tasków do utworzenia,
     jako zadania podrzędne ticketu z pola `Ticket` w proposal.md;
   - task, który ma już `(issue: KEY-123)` w tasks.md, pomijasz (deduplikacja po `T-NN`);
   - klucz utworzonego zadania dopisujesz przy tasku: `(issue: KEY-123)`.
3. Wskaż następny krok:
```
ai/changes/{nazwa}/proposal.md → Status: Approved

→ /regent:apply {nazwa}
```

---

## WAŻNE Rules

✅ **ZAWSZE:**
- 1 runda wywiadu (sesja główna), dopytuj tylko o braki
- Challenge (Krok 1b′) przed decyzjami architektonicznymi — werdykt `AKCEPTUJĘ` /
  `MAM ZASTRZEŻENIA` powiedziany jawnie
- Większość zmian przechodzi z `AKCEPTUJĘ` — zastrzeżenie zgłaszasz, gdy masz konkretną
  alternatywę; zgłoszone raz, potem budujesz pełny zakres wg decyzji użytkownika
- Zastrzeżenia (jeśli były) zapisane w `proposal.md` → sekcja `## Zastrzeżenia` z decyzją usera
- Frontier pusty (Krok 1b′) PRZED pierwszą delegacją — żadna gałąź bez rozstrzygnięcia,
  bo każda re-delegacja to pełny re-run kontekstu
- Kontrola spójności przed review: semantyczna w Kroku 2.5, pokrycie AC↔task skryptem w 3a
- Subagent zwraca TREŚĆ artefaktów w raporcie; pliki zapisuje sesja główna
- Pliki zapisane jako `Draft` PRZED review; `Approved` dopiero po `zatwierdzam`
  (`/regent:apply` blokuje Draft)
- Poprawki wg skali: drobne → sesja edytuje wprost na plikach Draft; koncepcyjne → resume
  subagenta (resume zamiast re-delegacji — kontekst płatny raz)
- Kontekst do subagentów zawężony (streszczenie dużych dokumentów zamiast ponownego czytania)
- AC w Given-When-Then; delta specs (nie full)
- INVARIANTS w delta spec dla refactorów
- Zwięzła prezentacja (ścieżki + podsumowanie), zachęta do przeczytania plików Draft
