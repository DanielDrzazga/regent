# User Story: {{ID}} — {{TYTUŁ}}

<!--
  INSTRUKCJA: Szablon OPCJONALNY, dla złożonych historii przy zmianie:
  ai/changes/{nazwa}/user-stories/US-XXX.md; w delta spec powiąż:
  "REQ-XXX (realizuje US-XXX)".
  USUŃ sekcje niedotyczące projektu (UI/UX, RODO, accessibility w projekcie backendowym).
-->

## Metadane

| Pole | Wartość |
|------|---------|
| ID | US-XXX |
| Priorytet | P0 (MVP) / P1 (soon) / P2 (later) |
| Status | Draft / Ready / In Progress / Done |
| Persona | [nazwa persony] |
| Moduł | [nazwa modułu] |
| Estymacja | XS / S / M / L / XL |

## User Story

**As** [persona],
**I want** [action/capability],
**so that** [benefit/value].

## Kontekst

[Motywacja biznesowa — dlaczego ta user story jest ważna]

## Realizowane przez

Kryteria akceptacji żyją w delcie (`specs/{domena}.md`) — jedno źródło AC:
- REQ-NNN: [nazwa wymagania] — AC: `REQ-NNN/AC-1`, `REQ-NNN/AC-2`

## Scenariusze (narracja dla ludzi — testowalną wersją są AC w delcie)

### S-1: [Nazwa]
**Given** [warunek wstępny]
**When** [akcja]
**Then** [oczekiwany rezultat]

### S-NEG-1: [Nazwa scenariusza negatywnego]
**Given** [warunek]
**When** [nieprawidłowa akcja]
**Then** [obsługa błędu]

## Wymagania UI/UX <!-- usuń, jeśli nie dotyczy -->

| Pole | Wartość |
|------|---------|
| Strona | [nazwa strony/ekranu] |
| Wireframe | [link lub opis] |
| Flow | [link do user flow] |
| Responsive | Mobile / Tablet / Desktop |

## Wymagania techniczne

### API Endpoints
| Method | Path | Opis |
|--------|------|------|
| POST | /api/... | [opis] |

### Business Rules
1. [Reguła biznesowa]
2. [Reguła biznesowa]

## Bezpieczeństwo i RODO <!-- usuń, jeśli nie dotyczy -->

| Pole | Wartość |
|------|---------|
| Autentykacja | Wymagana / Nie |
| Role | [wymagane role] |
| Dane osobowe | [kategorie] |
| Podstawa prawna | [Art. 6.1.X RODO] |

## Definition of Done

- [ ] AC spełnione i przetestowane
- [ ] Unit testy (target coverage wg testing-patterns.md)
- [ ] Integration testy (key flows)
- [ ] Code review passed
- [ ] UI zgodne ze specyfikacją <!-- usuń, jeśli nie dotyczy -->
- [ ] Accessibility (WCAG 2.1 AA) <!-- usuń, jeśli nie dotyczy -->
- [ ] Dokumentacja zaktualizowana

## Zależności

### Blokowane przez
- [zależność]

### Powiązane stories
- [US-YYY]

## Notatki

[Dodatkowy kontekst, otwarte pytania, założenia]
