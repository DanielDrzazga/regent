# Proposal: {{NAZWA}}

## Metadane

| Pole | Wartość |
|------|---------|
| Typ | feature / refactor / bugfix |
| Ticket | [KEY z trackera lub NONE] |
| Status | Draft / Approved / Rejected |
| Data utworzenia | YYYY-MM-DD |
| Autor | [kto zaproponował] |

## Problem

### Co jest problemem?
[Opis problemu — max 3 zdania]

### Dlaczego teraz?
[Dlaczego to jest ważne teraz]

### Kto jest dotknięty?
[Użytkownicy, zespół, system]

## Rozwiązanie

### Podsumowanie
[Opis rozwiązania — max 3 zdania]

### User Story
As [persona], I want [action], so that [benefit].

## Oczekiwany rezultat

- [1-3 punkty: co zyskuje użytkownik / biznes — język efektu, nie kryteriów testowych]

Kryteria akceptacji żyją w delcie: `specs/{domena}.md` → `REQ-NNN/AC-n` (jedno źródło AC).

## Zakres

### In Scope (MVP)
1. [Co robimy]
2. [Co robimy]

### Out of Scope
1. [Czego NIE robimy]

### Future (nice to have)
1. [Na później]

## Wpływ

| Obszar | Wpływ | Szczegóły |
|--------|-------|-----------|
| Moduły | [lista] | [co się zmienia] |
| API | TAK/NIE | [nowe/zmienione endpointy] |
| Database | TAK/NIE | [migracje] |
| UI | TAK/NIE | [nowe/zmienione ekrany] |
| Users | TAK/NIE | [wpływ na użytkowników] |

## Zależności

### Blokowane przez
- [Od czego zależy ta zmiana]

### Blokuje
- [Co zależy od tej zmiany]

## Decyzje i założenia

<!-- Log rozstrzygnięć, dopisywany na bieżąco (starszych wpisów nie przepisuj). Jedna linia na
     wpis; zapisuj tylko to, co zmienia AC, design albo zakres.
     DECYZJA   — rozstrzygnięcie użytkownika (rundy Challenge, OPEN QUESTIONS w /regent:apply)
     ZAŁOŻENIE — domyślny wybór agenta, którego nikt nie potwierdził (widoczny przy review Draft)
     AMEND     — zmiana zatwierdzonego planu w trakcie /regent:apply (co, dlaczego; zgoda usera) -->

| Data | Typ | Kwestia | Rozstrzygnięcie |
|------|-----|---------|-----------------|
| YYYY-MM-DD | DECYZJA | [pytanie z rundy Challenge] | [odpowiedź użytkownika] |
| YYYY-MM-DD | ZAŁOŻENIE | [czego nie ustalono] | [co przyjęto i dlaczego] |

---

*Sekcję poniżej dodaj TYLKO, gdy `/regent:propose` (Krok 1b′ Challenge) zgłosił zastrzeżenia.
Brak zastrzeżeń → pomiń całą sekcję, nie pisz „brak".*

## Zastrzeżenia

| # | Zastrzeżenie | Proponowana alternatywa | Decyzja |
|---|--------------|-------------------------|---------|
| Z-1 | [co budzi wątpliwość] | [tańsza/prostsza droga] | uwzględnione / świadomie odrzucone |

**Uzasadnienie decyzji:** [jedno zdanie od użytkownika — dlaczego tak, mimo zastrzeżeń]

---

*Dla refactorów dodaj sekcję:*

## Motywacja refactoru

### Obecny stan
[Co jest źle / nieoptymalne]

### Oczekiwany stan
[Jak powinno wyglądać po refactorze]

### Metryki
| Metryka | Przed | Po (cel) |
|---------|-------|----------|
| [np. complexity] | [wartość] | [cel] |
