---
description: Writing tests (unit, integration, E2E) and coverage verification by qa-engineer
disable-model-invocation: true
argument-hint: '[unit|integration|e2e|coverage] [target]'
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:testing — Writing and running tests

**Goal:** Write tests (unit, integration, E2E) and verify coverage.

```
/regent:testing [target]

Example:
/regent:testing src/modules/users/
/regent:testing unit src/services/auth.service.ts
/regent:testing integration api/users
/regent:testing e2e user-registration
/regent:testing coverage
```

---

## Agent (delegation — REQUIRED)

Delegate writing tests, choosing helpers and coverage analysis to the `regent:qa-engineer` subagent
(model: sonnet, launch it with the Task tool). Don't do it "in place" in the main session —
otherwise the model from `agents/qa-engineer.md` will not be used.

---

## Step 1: Read the test strategy

```
Read (as context):
- ai/docs/patterns/testing-patterns.md
- ai/docs/stack/technology.md (only the Testing section)
- ${CLAUDE_PLUGIN_ROOT}/templates/test-plan-template.md (for complex changes — formalize the test
  plan, write it to ai/changes/{name}/test-plan.md)
```

---

## Step 2: Write tests (`regent:qa-engineer` subagent)

The test pyramid, coverage targets, mocks-first, seams, anti-patterns, the `tests/helpers/` structure
and UI test rules live in the `regent:qa-engineer` agent definition — **one source**. Take UI tools
from `frontend-patterns.md`; that file missing on a UI task → `OPEN QUESTIONS`.

For the given target:
0. **List the seams under test** (definition and criteria: `regent:qa-engineer`) — an uncertain seam goes
   to `OPEN QUESTIONS` before the first test is written
1. Identify what to test (AC, edge cases, error paths)
2. Check existing helpers BEFORE writing a new mock/factory
3. Write tests of the right type (unit / integration / component / E2E)
4. Create missing helpers in `tests/helpers/` — not inline

---

## Step 3: Run tests (`regent:qa-engineer` subagent)

```
The subagent runs them itself:
→ make test-unit / make test-integration   # narrowly — what it wrote/changed
→ make test-coverage                       # when verifying coverage

The full make check is the /regent:verify gate — not after every iteration.
```

---

## Step 4: Verify coverage

```
## Coverage Report

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Statements | ≥80% | 85% | ✅ |
| Branches | ≥75% | 72% | ⚠️ |
| Functions | ≥80% | 88% | ✅ |
| Lines | ≥80% | 84% | ✅ |

Uncovered:
- src/users/service.ts:45-52 (error handling path)
```

---

Timeline: 1-3 hours
