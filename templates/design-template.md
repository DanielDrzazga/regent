# Design: {{NAZWA}}

<!--
  INSTRUKCJA: USUŃ sekcje, które nie dotyczą tej zmiany (np. Database Changes bez zmian
  w DB, Frontend bez UI). Obecność sekcji "Database Changes" / "Security Considerations"
  triggeruje Etap 5 / 6 w /regent:verify — nie zostawiaj pustych nagłówków.
-->

## Overview

[1-2 zdania opisujące podejście techniczne]

## Architektura

### Diagram systemu

```
[ASCII lub mermaid diagram]
```

### Affected Files

<!-- Ta sekcja to kontrakt czytania dla /regent:apply i /regent:verify — wymień KONKRETNE pliki. -->

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Domain | [co się zmienia] | [lista plików] |
| Application | [co się zmienia] | [lista plików] |
| Infrastructure | [co się zmienia] | [lista plików] |
| Interface | [co się zmienia] | [lista plików] |
| Frontend (jeśli dotyczy) | [co się zmienia] | [lista plików] |

### Component Breakdown

**Backend:**
- [Komponent 1] — [odpowiedzialność]

**Frontend:** <!-- usuń, jeśli zmiana nie dotyka UI; obecność = zmiana full-stack
     (taski [FE] w tasks.md, kontrakt API↔UI wiążący dla frontend-dev) -->
- Komponenty UI: [lista — wg `ai/docs/patterns/frontend-patterns.md` i biblioteki z technology.md]
- Custom feature components: [lista z opisem kompozycji]
- State / routing impact: [nowy stan globalny? nowe trasy? — wg frontend-patterns.md]

## API / Interface Contract

### [METHOD] /api/[resource]

**Request:**
```json
{
  "field": "type — opis"
}
```

**Response (200):**
```json
{
  "field": "type — opis"
}
```

**Errors:**
| Status | Kiedy | Response |
|--------|-------|----------|
| 400 | Invalid input | `{ "error": "..." }` |
| 401 | Unauthorized | `{ "error": "..." }` |

## Database Changes

<!-- USUŃ sekcję, jeśli brak zmian w DB — jej obecność triggeruje Etap 5 (dba) w /regent:verify. -->

```sql
-- Migration: [opis]
CREATE TABLE ... (
  ...
);
```

## Decyzje techniczne

| Decyzja | Wybór | Alternatywy | Uzasadnienie |
|---------|-------|-------------|--------------|
| [Co] | [Wybrane] | [Inne opcje] | [Dlaczego] |

## Odstępstwa od zasad

<!-- USUŃ sekcję, gdy zmiana mieści się w zasadach MUST z ai/docs/patterns/architecture.md.
     Odstępstwo bez wpisu tutaj code-reviewer traktuje jako 🔴. -->

| Zasada | Odstępstwo | Uzasadnienie | Dlaczego prostsza droga nie wystarczyła |
|--------|------------|--------------|-----------------------------------------|
| MUST-N | [co] | [dlaczego] | [odrzucona alternatywa] |

## Ryzyka

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitygacja |
|--------|-------------------|-------|-----------|
| [Opis] | Low/Medium/High | Low/Medium/High | [Plan] |

## Error Handling

| Scenariusz | Status | Response | Recovery |
|------------|--------|----------|----------|
| [Błąd] | [kod] | [odpowiedź] | [co dalej] |

## Performance Considerations

- [ ] N+1 query prevention
- [ ] Caching strategy
- [ ] Pagination for large datasets

## Observability / Logging

> Wzorzec: `ai/docs/patterns/logging-patterns.md`. Zaplanuj logi już w designie — nie doklejaj po fakcie.

| Punkt (operacja / błąd) | level | type (business/technical) | action |
|-------------------------|-------|---------------------------|--------|
| [np. use case OK] | info | business | [np. ORDER_CREATED] |
| [np. integracja w catch] | error | technical | [np. PAYMENT_API_ERROR] |

- [ ] Kluczowe operacje domenowe mają log `info`/`business`
- [ ] Bloki `catch` / integracje zewnętrzne mają log `error`/`technical`
- [ ] Brak PII/sekretów w `context` (tylko ID encji)

## Testing Strategy

- **Unit:** [co testować]
- **Component (UI):** [zmienione komponenty — usuń, jeśli zmiana nie dotyka frontendu]
- **Integration:** [jakie integracje]
- **E2E:** [krytyczne ścieżki — API i/lub przeglądarkowe]
- **Smoke (Etap 8 `/regent:verify`):** [kroki głównej ścieżki w uruchomionej aplikacji + oczekiwany
  wynik — np. `curl -X POST /api/users …` → 201 + `id`; usuń, gdy zmiana nie ma uruchamialnego wejścia]

## Security Considerations

<!-- USUŃ sekcję, jeśli zmiana nie dotyka auth/user input/danych wrażliwych —
     jej obecność triggeruje Etap 6 (security-auditor) w /regent:verify. -->

- [ ] Authentication required?
- [ ] Authorization (role-based)?
- [ ] Input validation
- [ ] GDPR/RODO impact

## Deployment Notes

- [ ] Database migrations needed?
- [ ] Feature flags?
- [ ] Rollback plan
- [ ] Environment variables
