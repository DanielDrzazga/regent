# Design: {{NAME}}

<!--
  INSTRUCTION: REMOVE sections that do not apply to this change (e.g. Database Changes with no
  DB changes, Frontend with no UI). The presence of the "Database Changes" / "Security Considerations"
  section triggers Stage 5 / 6 in /regent:verify — do not leave empty headings.
-->

## Overview

[1-2 sentences describing the technical approach]

## Architecture

### System diagram

```
[ASCII or mermaid diagram]
```

### Affected Files

<!-- This section is the read contract for /regent:apply and /regent:verify — list SPECIFIC files. -->

| Layer | Changes | Files |
|-------|---------|-------|
| Domain | [what changes] | [file list] |
| Application | [what changes] | [file list] |
| Infrastructure | [what changes] | [file list] |
| Interface | [what changes] | [file list] |
| Frontend (if applicable) | [what changes] | [file list] |

### Component Breakdown

**Backend:**
- [Component 1] — [responsibility]

**Frontend:** <!-- remove if the change does not touch the UI; presence = full-stack change
     ([FE] tasks in tasks.md, API↔UI contract binding for frontend-dev) -->
- UI components: [list — per `ai/docs/patterns/frontend-patterns.md` and the library from technology.md]
- Custom feature components: [list with a description of the composition]
- State / routing impact: [new global state? new routes? — per frontend-patterns.md]

## API / Interface Contract

### [METHOD] /api/[resource]

**Request:**
```json
{
  "field": "type — description"
}
```

**Response (200):**
```json
{
  "field": "type — description"
}
```

**Errors:**
| Status | When | Response |
|--------|------|----------|
| 400 | Invalid input | `{ "error": "..." }` |
| 401 | Unauthorized | `{ "error": "..." }` |

## Database Changes

<!-- REMOVE the section if there are no DB changes — its presence triggers Stage 5 (dba) in /regent:verify. -->

```sql
-- Migration: [description]
CREATE TABLE ... (
  ...
);
```

## Technical decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| [What] | [Chosen] | [Other options] | [Why] |

## Deviations from principles

<!-- REMOVE the section when the change fits within the MUST principles from ai/docs/patterns/architecture.md.
     code-reviewer treats a deviation without an entry here as 🔴. -->

| Principle | Deviation | Rationale | Why the simpler path was not enough |
|-----------|-----------|-----------|-------------------------------------|
| MUST-N | [what] | [why] | [rejected alternative] |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| [Description] | Low/Medium/High | Low/Medium/High | [Plan] |

## Error Handling

| Scenario | Status | Response | Recovery |
|----------|--------|----------|----------|
| [Error] | [code] | [response] | [what next] |

## Performance Considerations

- [ ] N+1 query prevention
- [ ] Caching strategy
- [ ] Pagination for large datasets

## Observability / Logging

> Pattern: `ai/docs/patterns/logging-patterns.md`. Plan logs already in the design — do not bolt them on after the fact.

| Point (operation / error) | level | type (business/technical) | action |
|---------------------------|-------|---------------------------|--------|
| [e.g. use case OK] | info | business | [e.g. ORDER_CREATED] |
| [e.g. integration in catch] | error | technical | [e.g. PAYMENT_API_ERROR] |

- [ ] Key domain operations have an `info`/`business` log
- [ ] `catch` blocks / external integrations have an `error`/`technical` log
- [ ] No PII/secrets in `context` (entity IDs only)

## Testing Strategy

- **Unit:** [what to test]
- **Component (UI):** [changed components — remove if the change does not touch the frontend]
- **Integration:** [which integrations]
- **E2E:** [critical paths — API and/or browser]
- **Smoke (Stage 8 `/regent:verify`):** [main path steps in the running application + expected
  result — e.g. `curl -X POST /api/users …` → 201 + `id`; remove when the change has no runnable entry point]

## Security Considerations

<!-- REMOVE the section if the change does not touch auth/user input/sensitive data —
     its presence triggers Stage 6 (security-auditor) in /regent:verify. -->

- [ ] Authentication required?
- [ ] Authorization (role-based)?
- [ ] Input validation
- [ ] GDPR impact

## Deployment Notes

- [ ] Database migrations needed?
- [ ] Feature flags?
- [ ] Rollback plan
- [ ] Environment variables
