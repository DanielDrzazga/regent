---
description: Aktualizacja ai/docs/ gdy podejście się zmienia (architektura, stack, konwencje)
disable-model-invocation: true
argument-hint: <plik-lub-temat>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:revise — Zaktualizuj ai/docs/

**Cel:** Zaktualizuj dokumentację techniczną gdy implementacja ujawni zmiany w podejściu.

```
/regent:revise <plik-lub-temat>

Przykład:
/regent:revise architecture    (aktualizuj ai/docs/patterns/architecture.md)
/regent:revise technology      (aktualizuj ai/docs/stack/technology.md)
/regent:revise naming          (aktualizuj ai/docs/conventions/naming.md)
/regent:revise glossary        (aktualizuj ai/docs/domain/glossary.md)
```

---

## Agent (delegacja — WYMAGANE)

Przygotowanie aktualizacji `ai/docs/` deleguj do subagenta `regent:architect` (model: opus,
narzędzie Task) — to on generuje i utrzymuje dokumentację (jak w `/regent:init`), także
`logging-patterns.md`. **Nie deleguj tu `regent:logging-engineer`:** ten agent traktuje
`logging-patterns.md` jako zewnętrzne źródło prawdy i przy jego braku PRZERYWA pracę —
czyli dokładnie w sytuacji, w której `/regent:revise` ma ten plik utworzyć. Gdy potrzebne są
realia loggera (ścieżka importu, API), rozpoznaj je sam (Grep/Glob) i przekaż architektowi
w prompcie.

**Kontrakt:** `regent:architect` jest read-only — zwraca proponowaną treść (diff BYŁO/JEST)
w raporcie; sesja główna pokazuje diff użytkownikowi i po zatwierdzeniu zapisuje pliki.
Wywiad (Krok 1) prowadzi sesja główna.

---

## Krok 1: Wywiad

```
1. Co się zmieniło w stosunku do dokumentacji?
   [Opis oryginalnego vs nowego podejścia]

2. Dlaczego zmiana?
   [Powód — odkrycie techniczne, zmiana wymagań, lepsze rozwiązanie]

3. Które pliki ai/docs/ wymagają aktualizacji?
   [Lista plików]
```

**Czekaj na odpowiedzi.**

---

## Krok 2: Identyfikacja plików

```
Na podstawie wywiadu, pliki do aktualizacji:

□ ai/docs/stack/technology.md — zmiana stacku
□ ai/docs/patterns/architecture.md — zmiana wzorców
□ ai/docs/patterns/di-patterns.md — zmiana DI
□ ai/docs/patterns/testing-patterns.md — zmiana testów
□ ai/docs/patterns/exception-patterns.md — zmiana error handling
□ ai/docs/patterns/logging-patterns.md — zmiana wzorca logowania (ścieżka/API loggera)
□ ai/docs/conventions/naming.md — zmiana konwencji
□ ai/docs/domain/glossary.md — nowy termin domenowy, zmiana znaczenia istniejącego
  albo rozstrzygnięcie niejednoznaczności (wtedy wpis w sekcji „Rozstrzygnięte
  niejednoznaczności" z datą — zapis sporu jest tak samo wartościowy jak sama definicja)
□ ai/docs/conventions/code-style.md — zmiana stylu
□ ai/docs/conventions/git-workflow.md — zmiana git workflow
```

---

## Krok 3: Przygotuj i zatwierdź zmiany

Subagent zwraca proponowane zmiany; sesja główna pokazuje diff:
```
## Zmiany w ai/docs/patterns/architecture.md:

BYŁO:
  Architecture Type: Modular Monolith

JEST:
  Architecture Type: Microservices (2 services: API + Worker)

Powód: Worker wymaga osobnego skalowania
```

**Czekaj na zatwierdzenie.** Po `tak` → sesja główna zapisuje pliki.

---

## Krok 4: Potwierdź

```
## Revise Complete ✅

### Zaktualizowane pliki:
- ai/docs/patterns/architecture.md
```

---

## WAŻNE

- **Nie zmieniaj ai/docs/ "po cichu"** — zawsze /regent:revise
- **Inne agenci czytają ai/docs/** — aktualizacja wpływa na cały workflow

Timeline: 10-20 minut
