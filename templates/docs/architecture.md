# Architecture Patterns

> Wypełnij na podstawie struktury katalogów i importów wykrytych przez `/regent:init`.

## Typ architektury

[Modular Monolith / Microservices / Monolith] — [1-2 zdania uzasadnienia]

## Warstwy

| Warstwa | Odpowiedzialność | Może zależeć od |
|---------|------------------|-----------------|
| Domain | Encje, value objects, reguły biznesowe | (nic) |
| Application | Use cases, serwisy aplikacyjne | Domain |
| Infrastructure | Repozytoria, integracje zewnętrzne | Domain, Application |
| Interface | Kontrolery, API, CLI | Application |

**Kierunek zależności:** Domain ← Application ← Infrastructure/Interface (Domain nie zależy od nikogo).

## Struktura modułów

```
src/
└── modules/
    └── {moduł}/
        ├── domain/
        ├── application/
        ├── infrastructure/
        └── interface/
```

## Granice modułów

- [Zasada komunikacji między modułami — np. tylko przez porty/API, nie bezpośrednio przez repo]
- [Współdzielony kod → gdzie, np. `src/core/` / `src/shared/`]

## Wzorce przekrojowe

| Wzorzec | Zastosowanie |
|---------|--------------|
| DI | [np. NestJS built-in] |
| Error handling | [→ exception-patterns.md] |
| Logging | [→ logging-patterns.md] |

## Reference Implementations

> Dla każdego kluczowego wzorca wskaż 1-2 REALNE, wzorcowe implementacje w kodzie.
> To źródło prawdy „naśladuj to", które pozwala `regent:architect`/`regent:backend-dev` czytać
> JEDEN wskazany plik zamiast skanować `src/` w poszukiwaniu wzorca (`/regent:propose`, `/regent:apply`).
> Wypełnia `/regent:init`; aktualizuj przez `/regent:revise`, gdy pojawi się czystszy egzemplarz.

| Wzorzec | Wzorcowa implementacja (ścieżki od `src/`) | Co pokazuje |
|---------|--------------------------------------------|-------------|
| [np. AMQP consumer] | [pełna ścieżka pliku] | [1 zdanie: walidacja, delegacja, error handling] |
| [np. Domain event + handler] | [ścieżka eventu + ścieżka handlera] | [1 zdanie] |
| [np. Repository] | [interfejs + implementacja] | [1 zdanie] |

## Zasady nienegocjowalne (MUST)

> 3-7 reguł, które w projekcie JUŻ obowiązują i da się je sprawdzić (reguła lintera, bramka CI,
> ADR, ustalenie zespołu). Reguła „na wyrost" to szum, który każdy agent czyta przy każdej
> zmianie — brak takich reguł → usuń sekcję. Odstępstwo w konkretnej zmianie idzie do
> design.md → „Odstępstwa od zasad", z uzasadnieniem; bez tego wpisu `regent:code-reviewer` daje 🔴.

| ID | Zasada (MUST) | Jak sprawdzić |
|----|---------------|---------------|
| MUST-1 | [np. Domain nie importuje z Infrastructure] | [np. reguła lint / review] |
| MUST-2 | [np. każdy publiczny endpoint waliduje wejście] | [np. test integracyjny → 400] |

## Wskazówki projektowe

- Najprostsze rozwiązanie spełniające wymagania (YAGNI).
- Ważne decyzje → ADR w `ai/docs/adr/` (tworzy `regent:architect`).
