# Test Plan: {{NAME}}

## Metadata

| Field | Value |
|-------|-------|
| Feature | [feature name] |
| Date | YYYY-MM-DD |
| Scope | [what we test] |
| Out of Scope | [what we do not test] |

## Testing goals

- [ ] Verification of Acceptance Criteria
- [ ] Regression of existing functionality
- [ ] Edge cases and error handling
- [ ] Performance (if applicable)
- [ ] Security (if applicable)

## Test strategy

| Type | Framework | Target Coverage | Focus |
|------|-----------|----------------|-------|
| Unit | [Jest/Vitest/...] | ≥80% | Business logic |
| Integration | [Supertest/...] | Key flows | API, DB |
| E2E | [Playwright/Cypress/...] | Critical paths | User flows |

## Test Cases

### Unit Tests

| ID | Description | AC | Type | Status |
|----|-------------|----|------|--------|
| UT-01 | [description] | REQ-001/AC-1 | Happy path | ⬜ |
| UT-02 | [description] | REQ-001/AC-1 | Edge case | ⬜ |
| UT-03 | [description] | REQ-001/AC-2 | Error | ⬜ |

### Integration Tests

| ID | Endpoint | Method | Scenario | Expected | Status |
|----|----------|--------|----------|----------|--------|
| IT-01 | /api/... | POST | Valid input | 201 | ⬜ |
| IT-02 | /api/... | POST | Invalid input | 400 | ⬜ |

### E2E Tests

| ID | User Flow | Steps | Priority | Status |
|----|-----------|-------|----------|--------|
| E2E-01 | [flow] | [steps] | High | ⬜ |

## Success criteria

| Criterion | Target |
|-----------|--------|
| Unit coverage | ≥80% |
| Integration tests passing | 100% |
| E2E critical paths | 100% |
| No P1/P2 bugs | 0 |
