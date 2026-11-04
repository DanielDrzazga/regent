# User Story: {{ID}} — {{TITLE}}

<!--
  INSTRUCTION: OPTIONAL template, for complex stories in a change:
  ai/changes/{name}/user-stories/US-XXX.md; link it in the delta spec:
  "REQ-XXX (implements US-XXX)".
  REMOVE sections that do not apply to the project (UI/UX, GDPR, accessibility in a backend project).
-->

## Metadata

| Field | Value |
|-------|-------|
| ID | US-XXX |
| Priority | P0 (MVP) / P1 (soon) / P2 (later) |
| Status | Draft / Ready / In Progress / Done |
| Persona | [persona name] |
| Module | [module name] |
| Estimate | XS / S / M / L / XL |

## User Story

**As** [persona],
**I want** [action/capability],
**so that** [benefit/value].

## Context

[Business motivation — why this user story matters]

## Implemented by

Acceptance criteria live in the delta (`specs/{domain}.md`) — single source of AC:
- REQ-NNN: [requirement name] — AC: `REQ-NNN/AC-1`, `REQ-NNN/AC-2`

## Scenarios (narrative for people — the testable version is the AC in the delta)

### S-1: [Name]
**Given** [precondition]
**When** [action]
**Then** [expected result]

### S-NEG-1: [Name of the negative scenario]
**Given** [condition]
**When** [invalid action]
**Then** [error handling]

## UI/UX requirements <!-- remove if not applicable -->

| Field | Value |
|-------|-------|
| Page | [page/screen name] |
| Wireframe | [link or description] |
| Flow | [link to user flow] |
| Responsive | Mobile / Tablet / Desktop |

## Technical requirements

### API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/... | [description] |

### Business Rules
1. [Business rule]
2. [Business rule]

## Security and GDPR <!-- remove if not applicable -->

| Field | Value |
|-------|-------|
| Authentication | Required / No |
| Roles | [required roles] |
| Personal data | [categories] |
| Legal basis | [Art. 6(1)(X) GDPR] |

## Definition of Done

- [ ] AC met and tested
- [ ] Unit tests (target coverage per testing-patterns.md)
- [ ] Integration tests (key flows)
- [ ] Code review passed
- [ ] UI matches the specification <!-- remove if not applicable -->
- [ ] Accessibility (WCAG 2.1 AA) <!-- remove if not applicable -->
- [ ] Documentation updated

## Dependencies

### Blocked by
- [dependency]

### Related stories
- [US-YYY]

## Notes

[Additional context, open questions, assumptions]
