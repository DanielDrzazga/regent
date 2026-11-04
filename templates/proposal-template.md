# Proposal: {{NAME}}

## Metadata

| Field | Value |
|-------|-------|
| Type | feature / refactor / bugfix |
| Ticket | [KEY from the tracker or NONE] |
| Status | Draft / Approved / Rejected |
| Created | YYYY-MM-DD |
| Author | [who proposed it] |

## Problem

### What is the problem?
[Problem description — max 3 sentences]

### Why now?
[Why this matters now]

### Who is affected?
[Users, team, system]

## Solution

### Summary
[Solution description — max 3 sentences]

### User Story
As [persona], I want [action], so that [benefit].

## Expected outcome

- [1-3 points: what the user / business gains — outcome language, not test criteria]

Acceptance criteria live in the delta: `specs/{domain}.md` → `REQ-NNN/AC-n` (single source of AC).

## Scope

### In Scope (MVP)
1. [What we do]
2. [What we do]

### Out of Scope
1. [What we do NOT do]

### Future (nice to have)
1. [For later]

## Impact

| Area | Impact | Details |
|------|--------|---------|
| Modules | [list] | [what changes] |
| API | YES/NO | [new/changed endpoints] |
| Database | YES/NO | [migrations] |
| UI | YES/NO | [new/changed screens] |
| Users | YES/NO | [impact on users] |

## Dependencies

### Blocked by
- [What this change depends on]

### Blocks
- [What depends on this change]

## Decisions and assumptions

<!-- Log of resolutions, appended as you go (do not rewrite older entries). One line per
     entry; record only what changes AC, design or scope.
     DECISION   — user's resolution (Challenge rounds, OPEN QUESTIONS in /regent:apply)
     ASSUMPTION — agent's default choice that nobody confirmed (visible at Draft review)
     AMEND      — change to the approved plan during /regent:apply (what, why; user consent) -->

| Date | Type | Issue | Resolution |
|------|------|-------|------------|
| YYYY-MM-DD | DECISION | [question from a Challenge round] | [user's answer] |
| YYYY-MM-DD | ASSUMPTION | [what was not settled] | [what was assumed and why] |

---

*Add the section below ONLY when `/regent:propose` (Step 1b′ Challenge) raised objections.
No objections → skip the whole section, do not write "none".*

## Objections

| # | Objection | Proposed alternative | Decision |
|---|-----------|----------------------|----------|
| O-1 | [what raises doubt] | [cheaper/simpler path] | addressed / consciously rejected |

**Decision rationale:** [one sentence from the user — why this way, despite the objections]

---

*For refactors, add the section:*

## Refactor motivation

### Current state
[What is wrong / suboptimal]

### Target state
[How it should look after the refactor]

### Metrics
| Metric | Before | After (target) |
|--------|--------|----------------|
| [e.g. complexity] | [value] | [target] |
