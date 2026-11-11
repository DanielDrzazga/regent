---
description: Structured bug fix in dev/staging — reproduction, root cause, regression test
disable-model-invocation: true
argument-hint: <bug-description>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:bugfix — Regular bug fix

**Goal:** Structured bug fix with reproduction, root cause analysis, and a regression test.

```
/regent:bugfix <bug-description>

Example:
/regent:bugfix "users can register with duplicate email"
/regent:bugfix "login redirect loop on expired session"
```

---

## Agent (delegation — REQUIRED)

Delegate the root cause analysis, regression test and minimal fix to a dev agent **by bug area**:
backend code → `regent:backend-dev`, frontend code → `regent:frontend-dev` (requires `frontend-patterns.md`);
bug at the boundary → first establish which side the root cause is on and fix on ONE side;
when it really is both → two delegations, BE first. The subagent runs the tests itself (narrowly)
and returns a report — **the main session commits**. The optional `/regent:verify` delegates its own subagents.

---

## Step 1: Bug analysis

```
## Bug Analysis

### Description
[What happens vs what should happen]

### Severity
- 🔴 CRITICAL — system down, data loss, security breach
- 🟡 HIGH — feature broken, workaround exists
- 🟢 MEDIUM — minor issue, edge case
- 🔵 LOW — cosmetic, minor inconvenience

### Impact
- Users affected: [all/some/few]
- Frequency: [always/sometimes/rare]
- Workaround: [exists/none]

### Root Cause Hypothesis
[Initial hypothesis — what may be the cause]
```

---

## Step 2: Locate the buggy file (targeted, not by scanning)

Use precise tools instead of a broad scan:

```bash
# Search by a keyword from the bug description (file extensions per stack from technology.md)
grep -r "registerUser\|duplicate.*email" src/ -l

# Or through git history
git log --oneline --all -20
git log --oneline -- src/modules/users/

# Then: Read only the file you found — do NOT scan the whole src/
```

**Reproduction:**
```
Steps:
1. [Step 1]
2. [Step 2]

Expected: [what should happen]
Actual: [what happens]
```

> **Coming from `/regent:debugging`:** when the diagnosis went that way, you already have a loop
> command that is red on this bug — use it instead of building the reproduction from scratch.

**Write a failing test that reproduces the bug:**
```bash
# The test MUST fail — it confirms the bug
make test-unit
```

**Minimize it before moving on.** Cut one element at a time (payload field, setup step,
dependency); done when **every remaining element is load-bearing** — removing any of them
makes the test pass. A minimal test targets the cause rather than the scenario in which the
bug was noticed, and it stays in the repo as the regression test.

---

## Step 3: Minimal artifacts

Create a lightweight proposal (simplified versions of the templates from `${CLAUDE_PLUGIN_ROOT}/templates/`):

```
ai/changes/fix-{name}/
├── proposal.md (simplified — only: problem, root cause, fix; Status: Approved after user consent)
├── specs/{domain}.md (delta — MODIFIED with a full REQ block with AC for the correct behavior;
│                      behavior without a spec in ai/specs/ → ADDED)
├── design.md (simplified — root cause, Affected Files, approach; required by /regent:verify)
└── tasks.md (2-5 tasks max)
```

---

## Step 4: Implementation

```bash
# Branch
git checkout -b fix/{KEY}-{short-description}

# Fix (delegate → backend-dev OR frontend-dev — by the root cause area from Step 2):
# 1. Write the failing test (reproduction) and run it — it must fail
# 2. Fix the bug (minimally!)
# 3. Verify: the test passes
# 4. Verify: the module tests still pass

# Commit (MAIN SESSION, after a report with confirmed GREEN) — code and tests only;
# after the commit, the trace on the task as in /regent:apply 4c: (commit: <hash> · tests: <regression test>)
git add [specific files]
git commit -m "fix: (KEY) prevent duplicate email registration"

# ai/ is tracked → after editing tasks.md a second, short commit:
# git add ai/changes/fix-{name}/tasks.md && git commit -m "docs: check off T-01 in tasks.md"
```

---

## Step 5: Verification

```bash
make check   # no Makefile → native equivalent from the stack (the `make` contract in `context/sdd.md`)
```

**Reproduce the original symptom** — the reproduction steps from Step 2 executed on the code after the fix.
The regression test checks the cause; the reproduction checks that the user no longer sees the error.

| Result | When | Verdict in verification.md |
|---|---|---|
| **verified** | the symptom does not occur, the regression test and `make check` are green | PASS |
| **partial** | the symptom is gone, but the reproduction could not be fully executed or unrelated regressions showed up | FAIL + what was not confirmed |
| **failed** | the symptom still occurs or the fix breaks tests | FAIL → back to Step 2 with new observations |

Green tests without an executed reproduction are at most **partial**. Archiving at partial
is the user's decision (`/regent:archive --force`, UNVERIFIED entry).

Write `ai/changes/fix-{name}/verification.md` (required by /regent:archive):
- simplified: verdict + reproduction result (verified/partial/failed) + regression test (file:line)
  + date + commit HEAD
- for more important bugs (HIGH/CRITICAL): full `/regent:verify fix-{name}`

---

## Step 6: Archive

After the merge — **via `/regent:archive fix-{name}`** (NOT a bare `mv`!):
the delta spec from Step 3 must be merged into `ai/specs/{domain}.md`,
otherwise the main specs drift from the code with every bug.

---

## IMPORTANT

- **Reproduce first** — failing test BEFORE the fix
- **Minimal fix** — fix the bug, don't refactor
- **Root cause** — don't patch symptoms
- **Regression test** — the test must stay forever
- **Closing via /regent:archive** — merging the delta into the main specs is the point of SDD

Timeline: 30-60 minutes
