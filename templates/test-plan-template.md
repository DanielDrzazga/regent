# Test Plan: {{NAZWA}}

## Metadane

| Pole | Wartość |
|------|---------|
| Feature | [nazwa feature] |
| Data | YYYY-MM-DD |
| Scope | [co testujemy] |
| Out of Scope | [czego nie testujemy] |

## Cele testowania

- [ ] Weryfikacja Acceptance Criteria
- [ ] Regresja istniejącej funkcjonalności
- [ ] Edge cases i error handling
- [ ] Performance (jeśli dotyczy)
- [ ] Security (jeśli dotyczy)

## Strategia testowa

| Typ | Framework | Target Coverage | Fokus |
|-----|-----------|----------------|-------|
| Unit | [Jest/Vitest/...] | ≥80% | Logika biznesowa |
| Integration | [Supertest/...] | Key flows | API, DB |
| E2E | [Playwright/Cypress/...] | Critical paths | User flows |

## Test Cases

### Unit Tests

| ID | Opis | AC | Typ | Status |
|----|------|----|-----|--------|
| UT-01 | [opis] | REQ-001/AC-1 | Happy path | ⬜ |
| UT-02 | [opis] | REQ-001/AC-1 | Edge case | ⬜ |
| UT-03 | [opis] | REQ-001/AC-2 | Error | ⬜ |

### Integration Tests

| ID | Endpoint | Method | Scenariusz | Expected | Status |
|----|----------|--------|-----------|----------|--------|
| IT-01 | /api/... | POST | Valid input | 201 | ⬜ |
| IT-02 | /api/... | POST | Invalid input | 400 | ⬜ |

### E2E Tests

| ID | User Flow | Kroki | Priorytet | Status |
|----|-----------|-------|-----------|--------|
| E2E-01 | [flow] | [kroki] | High | ⬜ |

## Kryteria sukcesu

| Kryterium | Target |
|-----------|--------|
| Unit coverage | ≥80% |
| Integration tests passing | 100% |
| E2E critical paths | 100% |
| No P1/P2 bugs | 0 |
