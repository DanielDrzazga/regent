---
description: Refactoring without behavior change — full propose → apply → verify → archive cycle with INVARIANTS
disable-model-invocation: true
argument-hint: <description>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:refactor — Refactoring and technical debt reduction

**Goal:** Code refactoring WITHOUT behavior change. INVARIANTS are mandatory.

```
/regent:refactor <description>

Example:
/regent:refactor "extract auth service from user module"
/regent:refactor "replace raw SQL with repository pattern"
/regent:refactor "simplify order validation logic"
```

---

## Agents (delegation — REQUIRED)

- Step 2 (`/regent:propose --type refactor`) delegates `regent:spec-writer` + `regent:architect` on its own.
- Delegate Step 4 (implementing the refactor steps) to a dev agent by area:
  backend → `regent:backend-dev`, frontend → `regent:frontend-dev` (sonnet, Task).
- Step 6 (`/regent:verify`) delegates `regent:code-reviewer`/`regent:qa-engineer`/… on its own.

Don't refactor "in place" in the main session — otherwise the agents' models will not be used.

---

## Step 1: Define the scope

```
## Refactor Scope

### Target
[What we refactor — file, module, pattern]

### Current Problem
[Why the current code is problematic]
- [e.g. Code duplication, high complexity, tight coupling]

### Proposed Solution
[What it should look like after the refactor]

### Behavior Change: NONE ❗
[A refactor does NOT change behavior — this is the fundamental rule]
```

---

## Step 2: Create /regent:propose --type refactor

```
/regent:propose {name} --type refactor
```

**KEY:** The delta spec (`specs/{domain}.md`) MUST contain an INVARIANTS section —
that's where `/regent:verify` Stage 2 checks it (per `spec-template.md`):

```markdown
## INVARIANTS (mandatory!)

- INV-1: All existing API endpoints return same responses
- INV-2: All existing tests pass without modification
- INV-3: Database schema unchanged
- INV-4: [specific behavior that must not change]
```

---

## Step 3: Implementation strategy

**Target pattern from the docs, not from scanning src/:** take the shape you refactor towards (Repository,
Service Layer, Factory etc.) from `ai/docs/patterns/architecture.md` + the Reference
Implementations section (the referenced, exemplary files — `Read`). Reach into `src/` via `Grep`/`Glob`
**only to LOCATE** the refactor target and its callsites — NOT to learn the target pattern
by broad scanning. No pattern in Reference Implementations → a candidate to
add via `/regent:revise`.

```
Rules:
1. Small steps — each step = working code + passing tests
2. Atomic commits — each commit = complete refactor step
3. Tests ALWAYS pass after each step
4. If tests fail = revert the step, don't fix the test

Typical sequence:
Step 1: Add the new structure (next to the old one)
Step 2: Move the logic to the new structure
Step 3: Update callsites to the new structure
Step 4: Remove the old structure
Step 5: Cleanup (imports, exports)
```

---

## Step 4: Implementation

```bash
# Branch
git checkout -b refactor/{JIRA-KEY}-{short-description}

# For each step (implementation: backend-dev — runs the tests itself;
# commit: main session after a report with confirmed PASS):
# 1. Change the code
# 2. make test → PASS ✅
# 3. git add [specific files]
# 4. git commit -m "refactor: (KEY) step X - description"
# 5. trace on the task as in /regent:apply 4c: ✅ (commit: <hash> · tests: INV-1 → <test>)
```

---

## Step 5: Verification

```
Checklist:
□ ALL existing tests pass (not modified!)
□ Behavior unchanged (INVARIANTS)
□ Coverage the same or better
□ Performance the same or better
□ No new dependencies introduced (unless justified)
```

```bash
# Compare coverage before and after
make test-coverage

# Compare behavior
make test  # All tests MUST pass WITHOUT modification
```

---

## Step 6: Review & merge

```
/regent:verify {refactor-name}

Additional check:
□ INVARIANTS preserved?
□ Tests NOT modified (unless the test was on the implementation, not the behavior)?
□ Code more readable after the refactor?
```

---

## Step 7: Closing

```
/regent:archive {refactor-name}
```

A refactor goes through the FULL cycle — without archiving the delta spec (with INVARIANTS in the archive)
the change formally does not exist. The History entry goes into the domain's main spec, when it exists;
a refactor with only INVARIANTS in a domain without a main spec leaves a trace in the archive and in git.

Refactor tasks refer to the INVARIANTS they protect: `T-02: [BE] extract service — INV-1, INV-2 — …`.

---

## Red Flags 🚩

```
🚩 Behavior change → This is NOT a refactor → use /regent:propose --type feature
🚩 Without tests → Risky → write tests FIRST, then refactor
🚩 Code less clear after → Reject the refactor
🚩 Tests modified to pass → You probably changed behavior
🚩 Too many files → Split into smaller refactors
```

---

## IMPORTANT

- **INVARIANTS** — mandatory, verified in /regent:verify
- **Tests first** — if there are no tests, write them BEFORE the refactor
- **Small steps** — tests pass after EVERY step
- **No behavior change** — the only rule that is absolute

Timeline: 1-4 hours
