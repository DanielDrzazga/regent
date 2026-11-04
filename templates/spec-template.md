# Spec: {{DOMAIN}} — Delta for {{CHANGE_NAME}}

<!--
  INSTRUCTION: This file describes ONLY the changes (delta), not the full state of the specification.
  Sections: ADDED (new), MODIFIED (changed), REMOVED (deleted), INVARIANTS (unchanged).
  AC format: Given-When-Then.
  ID: REQ-NNN — global numbering in the project (next free number from ai/specs/, active
  ai/changes/, the archive and deltas on other branches — sdd-check next-req). An ADDED number is provisional until
  /regent:archive: sdd-check renumber fixes a collision with a parallel branch. AC numbered within the REQ (AC-1, AC-2…),
  a new AC gets the number after the highest in the block. Reference in tasks, reports and verification.md:
  REQ-012/AC-2 (list: REQ-012/AC-1, AC-3; range: REQ-012/AC-1..3).
  The numbers are the project's local numbering, so they do not go into the code:
  a test is named per the project convention, and the AC → test link is recorded at the task
  in tasks.md ("tests: file › test name") and in verification.md → AC coverage.
  The delta is the only place for AC in a change — proposal.md refers to them.
  REMOVE sections that do not apply to this change (e.g. REMOVED with no removals) — do not leave
  headings with placeholders. INVARIANTS are MANDATORY for refactors.
-->

## ADDED

### REQ-XXX: [Name of the new requirement]

**Given** [precondition]
**When** [user or system action]
**Then** [expected result]

**Acceptance Criteria:**
- [ ] AC-1: [testable criterion]
- [ ] AC-2: [testable criterion]

**Notes:** [context, edge cases]

---

## MODIFIED

<!-- Copy the WHOLE REQ block from ai/specs/{domain}.md (heading, Given-When-Then, ALL AC)
     and rewrite it to the new behavior. /regent:archive replaces the block in the main spec in full:
     an AC missing from the block would disappear, so list AC removed on purpose in "Removed AC".
     Mark AC copied without changes with "(unchanged)" at the end of the line — they need no new task
     or test with an ID (verify checks them as regression); /regent:archive removes the marker on merge.
     New behavior next to unchanged existing behavior → that is ADDED, not MODIFIED.
     Renaming only the requirement → MODIFIED with the new name: the REQ number stays, so
     references in tasks and reports do not break (sdd-check preflight shows an INFO about the change). -->

### REQ-YYY: [Requirement name — as in the main spec]

**Given** [precondition — after the change]
**When** [user or system action]
**Then** [expected result — after the change]

**Acceptance Criteria:**
- [ ] AC-1: [criterion copied from the main spec] (unchanged)
- [ ] AC-2: [changed criterion]
- [ ] AC-4: [new criterion — next number in this REQ]

**Removed AC:** AC-3 — [reason] <!-- only when you remove an AC; otherwise delete the line -->
**Was:** [1-2 sentences about the old behavior — for the reviewer, does not go into the main spec]
**Reason:** [why the change is necessary]

---

## REMOVED

### REQ-ZZZ: [Name of the removed requirement]

**Reason:** [why it was removed]
**Impact:** [what changes after the removal]

---

## INVARIANTS

<!-- Mandatory for refactors. Describe what MUST stay unchanged. -->

- **INV-1:** [What must not change and how to verify it]
- **INV-2:** [What must not change and how to verify it]

---

## Notes

- [Context, assumptions, edge cases, open questions]

<!-- The History table lives in the MAIN spec (ai/specs/{domain}.md — see main-spec-template.md),
     not in the delta. /regent:archive updates History during the merge. -->
