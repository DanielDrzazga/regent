# Spec: {{DOMENA}} — Delta dla {{NAZWA_ZMIANY}}

<!--
  INSTRUKCJA: Ten plik opisuje TYLKO zmiany (delta), nie pełny stan specyfikacji.
  Sekcje: ADDED (nowe), MODIFIED (zmienione), REMOVED (usunięte), INVARIANTS (niezmienne).
  Format AC: Given-When-Then.
  ID: REQ-NNN — numeracja globalna w projekcie (kolejny wolny numer z ai/specs/, aktywnych
  ai/changes/ i archiwum — sdd-check next-req); AC numerowane w obrębie REQ (AC-1, AC-2…),
  nowe AC dostaje numer po najwyższym w bloku. Odwołanie w taskach, raportach i verification.md:
  REQ-012/AC-2 (lista: REQ-012/AC-1, AC-3; zakres: REQ-012/AC-1..3).
  Numery są lokalne (ai/ jest osobisty, globalnie ignorowany), więc nie trafiają do kodu:
  test nazywa się wg konwencji projektu, a powiązanie AC → test zapisuje się przy tasku
  w tasks.md („testy: plik › nazwa testu") i w verification.md → Pokrycie AC.
  Delta to jedyne miejsce AC w zmianie — proposal.md do nich odsyła.
  USUŃ sekcje, które nie dotyczą tej zmiany (np. REMOVED bez usunięć) — nie zostawiaj
  nagłówków z placeholderami. INVARIANTS są OBOWIĄZKOWE dla refactorów.
-->

## ADDED

### REQ-XXX: [Nazwa nowego wymagania]

**Given** [warunek wstępny]
**When** [akcja użytkownika lub systemu]
**Then** [oczekiwany rezultat]

**Acceptance Criteria:**
- [ ] AC-1: [kryterium testowalne]
- [ ] AC-2: [kryterium testowalne]

**Notes:** [kontekst, edge cases]

---

## MODIFIED

<!-- Skopiuj z ai/specs/{domena}.md CAŁY blok REQ (nagłówek, Given-When-Then, WSZYSTKIE AC)
     i przeredaguj go do nowego zachowania. /regent:archive podmienia blok w main spec w całości:
     AC nieobecne w bloku zniknęłoby, więc AC usuwane celowo wypisz w „Usunięte AC".
     AC przepisane bez zmian oznacz „(bez zmian)" na końcu linii — nie potrzebują nowego taska
     ani testu z ID (verify sprawdza je regresyjnie); /regent:archive usuwa znacznik przy merge.
     Nowe zachowanie obok niezmienionego istniejącego → to ADDED, nie MODIFIED.
     Zmiana samej nazwy wymagania → MODIFIED z nową nazwą: numer REQ zostaje, więc
     odwołania w taskach i raportach się nie psują (sdd-check preflight pokaże INFO o zmianie). -->

### REQ-YYY: [Nazwa wymagania — jak w main spec]

**Given** [warunek wstępny — po zmianie]
**When** [akcja użytkownika lub systemu]
**Then** [oczekiwany rezultat — po zmianie]

**Acceptance Criteria:**
- [ ] AC-1: [kryterium przepisane z main spec] (bez zmian)
- [ ] AC-2: [kryterium zmienione]
- [ ] AC-4: [kryterium nowe — kolejny numer w tym REQ]

**Usunięte AC:** AC-3 — [powód] <!-- tylko gdy usuwasz AC; inaczej usuń linię -->
**Było:** [1-2 zdania o starym zachowaniu — dla recenzenta, nie trafia do main spec]
**Powód:** [dlaczego zmiana jest konieczna]

---

## REMOVED

### REQ-ZZZ: [Nazwa usuniętego wymagania]

**Powód:** [dlaczego usunięte]
**Wpływ:** [co się zmienia po usunięciu]

---

## INVARIANTS

<!-- Obowiązkowe dla refactorów. Opisz co MUSI pozostać niezmienione. -->

- **INV-1:** [Co nie może się zmienić i jak to zweryfikować]
- **INV-2:** [Co nie może się zmienić i jak to zweryfikować]

---

## Notes

- [Kontekst, założenia, edge cases, otwarte pytania]

<!-- Tabela History żyje w MAIN spec (ai/specs/{domena}.md — patrz main-spec-template.md),
     nie w delcie. /regent:archive aktualizuje History podczas merge. -->
